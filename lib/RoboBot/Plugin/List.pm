package RoboBot::Plugin::List;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

use List::Util qw( shuffle );

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'List',
);

has '+description' => (
    default => 'Provides functions which operates on lists.',
);

has '+commands' => (
    default => sub {{
        'nth' => { method      => 'list_nth',
                   description => 'Returns the nth entry of a list, discarding all others. One-indexed. Negative numbers count backwards from the end of the list.',
                   usage       => '<n> <... list ...>',
                   example     => '3 "James" "Alice" "Frank" "Janet"',
                   result      => 'Frank' },

        'first' => { method      => 'list_first',
                     description => 'Returns the first entry of a list, discarding all others.',
                     usage       => '<... list ...>',
                     example     => '"James" "Alice" "Frank" "Janet"',
                     result      => 'James' },

        'last' => { method      => 'list_last',
                    description => 'Returns the last entry of a list, discarding all others.',
                    usage       => '<... list ...>',
                    example     => '"James" "Alice" "Frank" "Janet"',
                    result      => 'Janet' },

        'shuffle' => { method      => 'list_shuffle',
                       description => 'Returns the list elements in a randomized order.',
                       usage       => '<... list ...>',
                       example     => '"James" "Alice" "Frank" "Janet"',
                       result      => '"Alice" "Janet" "James" "Frank"' },
    }},
);

sub list_nth {
    my ($self, $message, $command, $nth, @args) = @_;

    if (defined $nth && $nth =~ m{^\d+$}o) {
        if ($nth < 0) {
            if (($nth * -1) > scalar(@args)) {
                $message->response->raise(sprintf('List out-of-bounds error. Attempted to access entry %d of %d member list.', $nth, scalar(@args)));
            } else {
                return $args[$nth];
            }
        } elsif ($nth > 0) {
            if ($nth > scalar(@args)) {
                $message->response->raise(sprintf('List out-of-bounds error. Attempted to access entry %d of %d member list.', $nth, scalar(@args)));
            } else {
                return $args[$nth - 1];
            }
        }
    } else {
        $message->response->raise('Position nth must be provided as an integer.');
    }
}

sub list_first {
    my ($self, $message, $command, @args) = @_;

    return $self->list_nth($message, $command, 1, @args);
}

sub list_last {
    my ($self, $message, $command, @args) = @_;

    return $self->list_nth($message, $command, scalar(@args), @args);
}

sub list_shuffle {
    my ($self, $message, $command, @args) = @_;

    return shuffle @args;
}

__PACKAGE__->meta->make_immutable;

1;
