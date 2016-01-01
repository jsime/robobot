package RoboBot::Plugin::Types::Vector;

use v5.20;

use namespace::autoclean;

use Moose;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Types::Vector',
);

has '+description' => (
    default => 'Provides functions for creating and manipulating vectors of values.',
);

has '+commands' => (
    default => sub {{
        'vec' => { method      => 'vec_vec',
                   description => 'Converts a list of values into a vector, returning the vector. If no values are provided, an empty vector is returned.',
                   usage       => '[<list>]',
                   example     => '1 (seq 5 7) 10',
                   result      => '[1 5 6 7 10]', },
    }},
);

sub vec_vec {
    my ($self, $message, $command, $rpl, @list) = @_;

    return [] unless @list && @list > 0;
    return [@list];
}

__PACKAGE__->meta->make_immutable;

1;
