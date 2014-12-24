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
    default => 'Provides a set of functions for mathematical operations.',
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

        'sqrt' => { method  => 'sqrt',
                    usage   => '<num>',
                    example => '4',
                    result  => '2' },
    }},
);

sub add {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_n_numbers($message, 2, @args);
    return $args[0] + $args[1];
}

sub subtract {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_n_numbers($message, 2, @args);
    return $args[0] - $args[1];
}

sub multiply {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_n_numbers($message, 2, @args);
    return $args[0] * $args[1];
}

sub divide {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_n_numbers($message, 2, @args);
    return unless $self->denominator_not_zero($message, @args);
    return $args[0] / $args[1];
}

sub modulo {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_n_numbers($message, 2, @args);
    return unless $self->denominator_not_zero($message, @args);
    return $args[0] % $args[1];
}

sub power {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_n_numbers($message, 2, @args);
    return $args[0] ** $args[1];
}

sub sqrt {
    my ($self, $message, $command, @args) = @_;

    return unless $self->has_n_numbers($message, 1, @args);
    return unless $self->has_all_positive_numbers($message, @args);
    return sqrt($args[0]);
}

sub has_n_numbers {
    my ($self, $message, $n, @args) = @_;

    unless (@args && @args == $n) {
        $message->response->raise(sprintf('Must supply exactly %d %s for the given mathematical function.', $n, ($n == 1 ? 'number' : 'numbers')));
        return 0;
    }

    return $self->has_only_numbers($message, @args);
}

sub has_only_numbers {
    my ($self, $message, @args) = @_;

    my $non_number = 0;

    foreach my $arg (@args) {
        unless ($arg =~ m{^\-?(\d+(\.\d+)?|\d*\.\d+)$}o) {
            $non_number++;
            last;
        }
    }

    if ($non_number) {
        $message->response->raise('All values must be numeric.');
        return 0;
    }

    return 1;
}

sub has_all_positive_numbers {
    my ($self, $message, @args) = @_;

    my $neg_number = 0;

    foreach my $arg (@args) {
        unless ($arg >= 0) {
            $neg_number++;
            last;
        }
    }

    if ($neg_number) {
        $message->response->raise('All values must be positive.');
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
