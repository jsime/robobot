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
                    usage           => '<die size> [<die count>]',
                    example         => '2 10',
                    result          => '17' },
    }},
);

sub roll {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    unless (@args && @args > 0) {
        return $message->response->raise('Invalid die size and roll count arguments.');
    }

    unless ($args[0] =~ m{^\d+$}o) {
        return $message->response->raise('Die size must always be expressed as an integer.');
    }

    my $size = $args[0];
    my $rolls = 1;

    if (defined $args[1]) {
        unless ($args[1] =~ m{^\d+$}o) {
            return $message->response->raise('Number of rolls must be expressed as an integer. Omitting the roll count will default to 1.');
        }

        $rolls = $args[1];
    }

    if ($size > 2**16 || $rolls > 2**16) {
        return $message->response->raise('My arms cannot handle that much dice rolling. Please try smaller numbers');
    }

    my $result = 0;
    for (1..$rolls) {
        $result += int(rand($size)) + 1;
    }
    $message->response->push(sprintf('You rolled a %s-sided die %s time%s for a total of %s.',
        $nf->format_number($size),
        $nf->format_number($rolls),
        $rolls != 1 ? 's' : '',
        $nf->format_number($result)));
    return $result;
}

__PACKAGE__->meta->make_immutable;

1;
