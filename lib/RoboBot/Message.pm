package RoboBot::Message;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
use Data::Dump qw( dumpf );
use DateTime;

use RoboBot::Parser;
use RoboBot::Response;

has 'raw' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'expression' => (
    is        => 'rw',
    isa       => 'Object',
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
            my ($no_excl, $maybe_cmd) = ($1, $2);

            # If there is at least one pipe character followed by what looks to
            # be possibly another command, treat the incoming message as if it
            # is the old-style piped command chain, and convert to nested
            # expressions.
            if ($no_excl =~ m{\|\s+\!\S+}) {
                my @chained = split(/\|/, $no_excl);

                $no_excl = '';
                foreach my $command (@chained) {
                    $command =~ s{(^\s*\!?|\s*$)}{}gs;
                    $no_excl = sprintf('(%s%s)', $command, (length($no_excl) > 0 ? ' ' . $no_excl : ''));
                }
            } else {
                $no_excl = '(' . $no_excl . ')';
            }

            $self->raw($no_excl)
                if exists $self->bot->commands->{lc($maybe_cmd)}
                || exists $self->bot->macros->{lc($maybe_cmd)};
        }
    } elsif ($self->raw =~ m{ ^ $self->bot->nick->name : \s* (.+) }ixs) {
        # It looks like someone said something to us directly, so strip off our
        # nick from the front, and treat the reast as if it were a command.
        $self->raw('('.$1.')');
    }

    if ($self->raw =~ m{^\s*\(\S+}o) {
        my $parser = RoboBot::Parser->new( bot => $self->bot );
        my $expr;

        eval {
            $expr = $parser->parse($self->raw);
        };

        return if $@;

        if (defined $expr && ref($expr) =~ m{^RoboBot::Type::}) {
            # To prevent unnecessary echoing of parenthetical remarks, make sure
            # that the top-level form is either an Expression or a List with its
            # own first member being an Expression.
            if ($expr->type eq 'Expression') {
                $self->expression($expr);
            } elsif ($expr->type eq 'List' && defined $expr->value->[0] && $expr->value->[0]->type eq 'Expression') {
                $self->expression($expr);
            }
        }
    }
}

sub process {
    my ($self) = @_;

    # Process any before-hooks first
    if ($self->bot->run_before_hooks) {
        foreach my $plugin (@{$self->bot->before_hooks}) {
            # Skip hook if plugin is disabled for the current network.
            next if exists $self->network->disabled_plugins->{lc($plugin->name)};

            $plugin->hook_before($self);
        }
    }

    # Process the message itself (unless the network on which it was received is
    # marked as "passive" - only hooks will run, not functions or macros).
    if ($self->has_expression && ! $self->network->passive) {
        my @r = $self->expression->evaluate($self);

        # TODO: Restore pre-type functionality of only adding the implicit
        #       (print ...) call if the last function evaluated wasn't already
        #       an explicit print call.
        if (@r && @r > 0) {
            $self->bot->commands->{'print'}->process($self, 'print', {}, @r);
        }
    }

    # Process any after-hooks before sending response
    if ($self->bot->run_after_hooks) {
        foreach my $plugin (@{$self->bot->after_hooks}) {
            # Skip hook if plugin is disabled for the current network.
            next if exists $self->network->disabled_plugins->{lc($plugin->name)};

            $plugin->hook_after($self);
        }
    }

    # Deliver the response
    $self->response->send;
}

sub update_response_channel {
    my ($self, $new_channel, $old_channel) = @_;

    if ($self->has_response && $self->has_channel) {
        $self->response->channel($new_channel);
    }
}

__PACKAGE__->meta->make_immutable;

1;
