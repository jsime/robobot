package RoboBot::Message;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
use Data::SExpression;
use DateTime;

use RoboBot::Response;

has 'raw' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'expression' => (
    is        => 'rw',
    isa       => 'ArrayRef',
    predicate => 'has_expression',
);

has 'sender' => (
    is       => 'rw',
    isa      => 'RoboBot::Nick',
    traits   => [qw( SetOnce )],
    required => 1,
);

has 'channel' => (
    is        => 'rw',
    isa       => 'RoboBot::Channel',
    traits    => [qw( SetOnce )],
    predicate => 'has_channel',
    trigger   => \&update_response_channel,
);

has 'network' => (
    is       => 'rw',
    isa      => 'RoboBot::Network',
    traits   => [qw( SetOnce )],
    required => 1,
);

has 'timestamp' => (
    is       => 'ro',
    isa      => 'DateTime',
    default  => sub { DateTime->now },
    required => 1,
);

has 'response' => (
    is        => 'rw',
    isa       => 'RoboBot::Response',
    predicate => 'has_response',
);

has 'vars' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'bot' => (
    is       => 'ro',
    isa      => 'RoboBot',
    required => 1,
);

sub BUILD {
    my ($self) = @_;

    $self->response(RoboBot::Response->new(
        bot     => $self->bot,
        network => $self->network,
        nick    => $self->sender,
    ));

    $self->response->channel($self->channel) if $self->has_channel;

    # If the message is nothing but "help" or "!help" then convert it to "(help)"
    if ($self->raw =~ m{^\s*\!?help\s*$}oi) {
        $self->raw("(help)");
    }

    # If the very first character is an exclamation point, check the following
    # non-whitespace characters to see if they match a known command. If they
    # do, convert the incoming message to a simple expression to allow people
    # to interact with the bot using the older "!command arg arg arg" syntax.
    if (substr($self->raw, 0, 1) eq '!') {
        if ($self->raw =~ m{^\!+((\S+).*)}) {
            # TODO: Consider feasbility of also converting old-style piped command
            #       sequences into properly nested expressions.

            my ($no_excl, $maybe_cmd) = ($1, $2);

            $self->raw('('.$no_excl.')')
                if exists $self->bot->commands->{lc($maybe_cmd)}
                || exists $self->bot->macros->{lc($maybe_cmd)};
        }
    }

    if ($self->raw =~ m{^\s*\(\S+}o) {
        unless ($self->expressions_balanced) {
            return $self->response->raise('Unbalanced S-Expression provided.');
        }

        my $ds = Data::SExpression->new({
            fold_lists       => 1,
            use_symbol_class => 1,
        });

        my ($exp, $rtext, @exps);
        $rtext = $self->raw;

        while (1) {
            eval {
                ($exp, $rtext) = $ds->read($rtext);
            };
            last if $@;
            push(@exps, $exp);
        }

        if (@exps > 0) {
            # Special-case a check to see if there was only one parenthetical
            # expression and if the first member of the list is not a known
            # function name. This prevents the bot from parsing a simple aside
            # comment made in parentheses as if it were an expression containing
            # only bareword strings.
            # TODO ensure macros work as the first member of the top-level list
            #      once that feature is implemented
            if (@exps > 1 || exists $self->bot->commands->{lc("$exps[0][0]")} || exists $self->bot->macros->{lc("$exps[0][0]")}) {
                $self->expression(\@exps);
            }
        }
    }
}

sub process {
    my ($self) = @_;

    # Process any before-hooks first
    if ($self->bot->run_before_hooks) {
        foreach my $plugin (@{$self->bot->before_hooks}) {
            $plugin->hook_before($self);
        }
    }

    # Process the message itself
    if ($self->has_expression) {
        my (@r);

        foreach my $expr (@{$self->expression}) {
            @r = $self->process_list($expr);
        }

        if (@r && scalar(@r) > 0) {
            # Special-case a check for the last top-level function called being
            # (print ...) and do not run the auto-printer if that was the case.
            # Otherwise, assume that the return values of the final expression
            # should be printed back to the channel/sender.
            unless (lc($self->expression->[-1][0]) eq 'print') {
                $self->bot->commands->{'print'}->process($self, 'print', @r);
            }
        }
    }

    # Process any after-hooks before sending response
    if ($self->bot->run_after_hooks) {
        foreach my $plugin (@{$self->bot->after_hooks}) {
            $plugin->hook_after($self);
        }
    }

    # Deliver the response
    $self->response->send;
}

sub process_list {
    my ($self, $list) = @_;

    return $list unless ref($list) eq 'ARRAY';

    my $command = lc(scalar($list->[0]));

    if (exists $self->bot->commands->{$command}) {
        # If first element is a recognized command, pass list to appropriate plugin
        return $self->bot->commands->{$command}->process(
            $self,
            $command,
            @{$list}[1..$#$list]
        );
    } elsif (exists $self->bot->macros->{$command}) {
        # And if it's a macro name (which cannot override built-in/plugin commands)
        # expand the macro and process the results of that expansion.
        return $self->process_list(
            $self->bot->macros->{$command}->expand(
               $self, @{$list}[1..$#$list]
            )
        );
    } else {
        # Otherwise, just process any sub expressions in the order they appear,
        # then return the processed list
        my @r;
        foreach my $el (@{$list}) {
            if (ref($el) eq 'ARRAY') {
                push(@r, $self->process_list($el));
            } else {
                if (exists $self->vars->{$el}) {
                    if (ref($self->vars->{$el}) eq 'ARRAY') {
                        push(@r, $self->process_list($self->vars->{$el}));
                    } else {
                        push(@r, $self->vars->{$el});
                    }
                } else {
                    push(@r, $el);
                }
            }
        }
        return @r;
    }
}

sub update_response_channel {
    my ($self, $new_channel, $old_channel) = @_;

    if ($self->has_response && $self->has_channel) {
        $self->response->channel($new_channel);
    }
}

sub expressions_balanced {
    my ($self) = @_;

    # TODO: make this smarter (quote-enclosed parens and such)
    # for now we just count left and right parens and make sure the numbers match

    my @lp = ($self->raw =~ m{\(}g);
    my @rp = ($self->raw =~ m{\)}g);

    return scalar(@lp) == scalar(@rp);
}

__PACKAGE__->meta->make_immutable;

1;
