package RoboBot::Plugin::Roll;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

use Number::Format;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Roll',
);

has '+description' => (
    default => 'Random number generator in the style of arbitrary-sided dice-rolling.',
);

has '+commands' => (
    default => sub {{
        'roll' => { method          => 'roll',
                    preprocess_args => 1,
                    usage           => '<die size> <die count>',
                    example         => '2 10',
                    result          => '17' },
    }},
);

sub roll {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    if (@args && @args == 2 && $args[0] =~ m{^\d+$}o && $args[1] =~ m{^\d+$}o) {
        my $result = 0;
        for (1..$args[1]) {
            $result += int(rand($args[0])) + 1;
        }
        $message->response->push(sprintf('You rolled a %s-sided die %s times for a total of %s.',
            $nf->format_number($args[0]),
            $nf->format_number($args[1]),
            $nf->format_number($result)));
        return $result;
    }

    # invalid arguments, short-circuit respose with standard usage message
    return $self->usage($message, 'roll');
}

__PACKAGE__->meta->make_immutable;

1;
