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
    is  => 'rw',
    isa => 'Str',
);

has 'expression' => (
    is        => 'rw',
    isa       => 'ArrayRef',
    predicate => 'has_expression',
);

has 'sender' => (
    is     => 'rw',
    isa    => 'RoboBot::Nick',
    traits => [qw( SetOnce )],
);

has 'channel' => (
    is     => 'rw',
    isa    => 'RoboBot::Channel',
    traits => [qw( SetOnce )],
);

has 'network' => (
    is     => 'rw',
    isa    => 'RoboBot::Network',
    traits => [qw( SetOnce )],
);

has 'timestamp' => (
    is      => 'ro',
    isa     => 'DateTime',
    default => sub { DateTime->now },
);

has 'response' => (
    is  => 'rw',
    isa => 'RoboBot::Response',
);

has 'vars' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'bot' => (
    is  => 'ro',
    isa => 'RoboBot',
);

sub BUILD {
    my ($self) = @_;

    $self->response(RoboBot::Response->new(
        bot     => $self->bot,
        channel => $self->channel,
        nick    => $self->sender,
    ));

    if ($self->raw =~ m{^\s*\(\S+}o) {
        unless ($self->expressions_balanced) {
            return $self->response->raise('Unbalanced S-Expression provided.');
        }

        my $ds = Data::SExpression->new({
            fold_lists       => 1,
            symbol_case      => 'down',
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
            $self->expression(\@exps);
        }
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
