package RoboBot::Plugin::Math;

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
    default => 'Math',
);

has '+description' => (
    default => 'Provides a set of functions for basic mathematical operations.',
);

has '+commands' => (
    default => sub {{
        '+' => { method  => 'add',
                 usage   => '<num> <num>',
                 example => '3 5',
                 result  => '8' },

        '-' => { method  => 'subtract',
                 usage   => '<num> <num>',
                 example => '9 2',
                 result  => '7' },

        '*' => { method  => 'multiply',
                 usage   => '<num> <num>',
                 example => '4 5',
                 result  => '20' },

        '/' => { method  => 'divide',
                 usage   => '<num> <num>',
                 example => '9 3',
                 result  => '3' },

        'modulo' => { method  => 'modulo',
                      usage   => '<num> <num>',
                      example => '6 4',
                      result  => '2' },

        'pow' => { method  => 'power',
                   usage   => '<num> <num>',
                   example => '3 2',
                   result  => '8' },
    }},
);

sub add {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    if (@args && @args == 2 && $args[0] =~ m{^\d*(\.\d+)?$}o && $args[1] =~ m{^\d*(\.\d+)?$}o) {
        my $result = $args[0] + $args[1];
        $message->response->content([$nf->format_number($result)]);
        return $result;
    }

    return $self->usage($message, 'add');
}

sub subtract {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    if (@args && @args == 2 && $args[0] =~ m{^\d*(\.\d+)?$}o && $args[1] =~ m{^\d*(\.\d+)?$}o) {
        my $result = $args[0] - $args[1];
        $message->response->content([$nf->format_number($result)]);
        return $result;
    }

    return $self->usage($message, 'subtract');
}

sub multiply {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    if (@args && @args == 2 && $args[0] =~ m{^\d*(\.\d+)?$}o && $args[1] =~ m{^\d*(\.\d+)?$}o) {
        my $result = $args[0] * $args[1];
        $message->response->content([$nf->format_number($result)]);
        return $result;
    }

    return $self->usage($message, 'multiply');
}

sub divide {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    if (@args && @args == 2 && $args[0] =~ m{^\d*(\.\d+)?$}o && $args[1] =~ m{^\d*(\.\d+)?$}o) {
        if ($args[1] == 0) {
            return $message->response->raise('Cannot divide by zero.');
        } else {
            my $result = $args[0] / $args[1];
            $message->response->content([$nf->format_number($result)]);
            return $result;
        }
    }

    return $self->usage($message, 'divide');
}

sub modulo {
    my ($self, $message, $command, @args) = @_;

    my $nf = Number::Format->new();

    if (@args && @args == 2 && $args[0] =~ m{^\d*(\.\d+)?$}o && $args[1] =~ m{^\d*(\.\d+)?$}o) {
        if ($args[1] == 0) {
            return $message->response->raise('Cannot divide by zero.');
        } else {
            my $result = $args[0] % $args[1];
            $message->response->content([$nf->format_number($result)]);
            return $result;
        }
    }

    return $self->usage($message, 'modulo');
}

sub power {
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
