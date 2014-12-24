package RoboBot::Plugin::MathExtras;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

use Math::BigInt;
use Math::BigFloat;
use Number::Format;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Math Extras',
);

has '+description' => (
    default => 'Provides additional mathematical functions.',
);

has '+commands' => (
    default => sub {{
        'sqrt' => { method  => 'sqrt',
                    usage   => '<num>',
                    example => '4',
                    result  => '2' },
    }},
);

sub sqrt {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    if (@args && @args == 2 && $args[0] =~ m{^\d*(\.\d+)?$}o && $args[1] =~ m{^\d*(\.\d+)?$}o) {
        my $result = $args[0] ** $args[1];
        $message->response->content([$nf->format_number($result)]);
        return $result;
    }

    return $self->usage($message, 'power');
}

__PACKAGE__->meta->make_immutable;

1;
