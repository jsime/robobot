package RoboBot::Message;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

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
            if (@exps > 1 || exists $self->bot->commands->{lc("$exps[0][0]")}) {
                $self->expression(\@exps);
            }
        }
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
