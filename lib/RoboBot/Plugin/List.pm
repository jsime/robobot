package RoboBot::Plugin::List;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use List::Util qw( shuffle );
use Scalar::Util qw( blessed );

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'List',
);

has '+description' => (
    default => 'Provides functions which generate and operate on lists.',
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

        'sort' => { method      => 'list_sort',
                    description => 'Returns the list elements in sorted order.',
                    usage       => '<... list ...>',
                    example     => '"James" "Alice" "Frank" "Janet"',
                    result      => '"Alice" "Frank" "James" "Janet"' },

        'seq' => { method      => 'list_seq',
                   description => 'Returns a sequence of numbers.',
                   usage       => '<first> <last> [<step>]',
                   example     => '1 10 3',
                   result      => '1 4 7 10' },

        'any' => { method      => 'list_any',
                   description => 'Returns true if any list element is matched by the first function parameter.',
                   usage       => '<string> < ... list to search ... >',
                   example     => 'foo bar baz foo xyzzy',
                   result      => '1', },

        'count' => { method      => 'list_count',
                     description => 'Returns the number of items in the provided list. If no arguments are provided, the return value will be 0, same as for an empty list.',
                     usage       => '[<list>]' },

        'filter' => { method      => 'list_filter',
                      preprocess_args => 0,
                      description => 'Returns a list of elements from the input list which, when aliased to % and applied to <function>, result in a true evaluation.',
                      usage       => '<function> <list>',
                      example     => '(match "a" %) "Jon" "Jane" "Frank" "Zoe"',
                      result      => '"Jane" "Frank"' },

        'reduce' => { method      => 'list_reduce',
                      preprocess_args => 0,
                      description => 'Returns the result of repeatedly applying <function> to the <accumulator>, aliased as $, and each element of the input list, aliased as %.',
                      usage       => '<function> <accumulator> <list>',
                      example     => '(* $ %) 1 (seq 1 10)',
                      result      => '3628800' },

        'map' => { method      => 'list_map',
                   preprocess_args => 0,
                   description => 'Applies <function> to every element of the input list and returns a list of the results, preserving order. Each element of the input list is aliased to % within the function being applied.',
                   usage       => '<function> <list>',
                   example     => '(upper %) "Jon" "Jane" "frank"',
                   result      => '"JON" "JANE" "FRANK"' },
    }},
);

sub list_filter {
    my ($self, $message, $command, $rpl, $filter_func, @list) = @_;

    my @ret_list = ();
    my $p_masked = exists $message->vars->{'%'} ? $message->vars->{'%'} : undef;

    foreach my $el (@list) {
        my @vals = ref($el) eq 'ARRAY' ? $message->process_list($el) : ($el);

        foreach my $val (@vals) {
            $message->vars->{'%'} = $val;

            push(@ret_list, $val) if $message->process_list($filter_func);
        }
    }

    if (defined $p_masked) {
        $message->vars->{'%'} = $p_masked;
    } else {
        delete $message->vars->{'%'};
    }

    return @ret_list;
}

sub list_reduce {
    my ($self, $message, $command, $rpl, $reduce_func, $accumulator, @list) = @_;

    my $p_masked = exists $message->vars->{'%'} ? $message->vars->{'%'} : undef;
    my $d_masked = exists $message->vars->{'$'} ? $message->vars->{'$'} : undef;

    foreach my $el (@list) {
        my @vals = ref($el) eq 'ARRAY' ? $message->process_list($el) : ($el);

        foreach my $val (@vals) {
            $message->vars->{'$'} = $accumulator;
            $message->vars->{'%'} = $val;

            $accumulator = $message->process_list($reduce_func);
        }
    }

    if (defined $p_masked) {
        $message->vars->{'%'} = $p_masked;
    } else {
        delete $message->vars->{'%'};
    }

    if (defined $d_masked) {
        $message->vars->{'$'} = $d_masked;
    } else {
        delete $message->vars->{'$'};
    }

    return $accumulator;
}

sub list_map {
    my ($self, $message, $command, $rpl, $map_func, @list) = @_;

    my @ret_list = ();
    my $p_masked = exists $message->vars->{'%'} ? $message->vars->{'%'} : undef;

    foreach my $el (@list) {
        my @vals = ref($el) eq 'ARRAY' ? $message->process_list($el) : ($el);

        foreach my $val (@vals) {
            $message->vars->{'%'} = $val;

            push(@ret_list, $message->process_list($map_func));
        }
    }

    if (defined $p_masked) {
        $message->vars->{'%'} = $p_masked;
    } else {
        delete $message->vars->{'%'};
    }

    return @ret_list;
}

sub list_count {
    my ($self, $message, $command, $rpl, @list) = @_;

    return 0 unless @list;
    return scalar(@list) || 0;
}

sub list_any {
    my ($self, $message, $command, $rpl, $str, @list) = @_;

    return unless defined $str && @list && scalar(@list) > 0;

    foreach my $el (@list) {
        return 1 if $str eq $el;
    }
    return;
}

sub list_nth {
    my ($self, $message, $command, $rpl, $nth, @args) = @_;

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
    my ($self, $message, $command, $rpl, @args) = @_;

    return $self->list_nth($message, $command, $rpl, 1, @args);
}

sub list_last {
    my ($self, $message, $command, $rpl, @args) = @_;

    return $self->list_nth($message, $command, $rpl, scalar(@args), @args);
}

sub list_shuffle {
    my ($self, $message, $command, $rpl, @args) = @_;

    return shuffle @args;
}

sub list_sort {
    my ($self, $message, $command, $rpl, @args) = @_;

    return sort @args;
}

sub list_seq {
    my ($self, $message, $command, $rpl, $first, $last, $step) = @_;

    $step //= 1;

    unless (defined $first && defined $last && $first =~ m{^\d+$} && $last =~ m{^\d+$}) {
        $message->response->raise('You must supply a starting number and ending number for the sequence.');
        return;
    }

    unless ($first <= $last) {
        $message->response->raise('Sequence starting number cannot be greater than the ending number.');
        return;
    }

    my @seq;

    do {
        push(@seq, $first);
        $first += $step;
    } while ($first <= $last);

    return @seq;
}

__PACKAGE__->meta->make_immutable;

1;
