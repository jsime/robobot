package RoboBot::Plugin::Math;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

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

    return unless $self->has_two_numbers($message, @args);
    return $args[0] + $args[1];
}

sub subtract {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_two_numbers($message, @args);
    return $args[0] - $args[1];
}

sub multiply {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_two_numbers($message, @args);
    return $args[0] * $args[1];
}

sub divide {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_two_numbers($message, @args);
    return unless $self->denominator_not_zero($message, @args);
    return $args[0] / $args[1];
}

sub modulo {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_two_numbers($message, @args);
    return unless $self->denominator_not_zero($message, @args);
    return $args[0] % $args[1];
}

sub power {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_two_numbers($message, @args);
    return $args[0] ** $args[1];
}

sub has_two_numbers {
    my ($self, $message, @args) = @_;

    unless (@args && @args == 2) {
        $message->response->raise('Must supply exactly two values for the given mathematical function.');
        return 0;
    }

    unless ($args[0] =~ m{^\-?(\d+(\.\d+)?|\d*\.\d+)$}o && $args[1] =~ m{^\-?(\d+(\.\d+)?|\d*\.\d+)$}o) {
        $message->response->raise('Both values must be numeric.');
        return 0;
    }

    return 1;
}

sub denominator_not_zero {
    my ($self, $message, @args) = @_;

    if ($args[1] == 0) {
        $message->response->raise('Cannot divide by zero.');
        return 0;
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
