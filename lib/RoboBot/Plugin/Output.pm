package RoboBot::Plugin::Output;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Output',
);

has '+description' => (
    default => 'Provides string formatting and output/display functions.',
);

has '+commands' => (
    default => sub {{
        'clear' => { method      => 'clear_output',
                     description => 'Clears current contents of the output buffer without displaying them.',
                     usage       => '',
                     example     => '',
                     result      => '' },

        'join' => { method      => 'join_str',
                    description => 'Joins together arguments into a single string, using the first argument as the delimiter.',
                    usage       => '<delimiter> <value> [<value 2> ... <value N>]',
                    example     => '", " 1 2 3 4 5',
                    result      => '1, 2, 3, 4, 5' },

        'print' => { method      => 'print_str',
                     description => 'Echoes input arguments, concatenated into a single string with no separators.',
                     usage       => '<value> [<value 2> ... <value N>]',
                     example     => '"Hello, " "my name is" "RoboBot."',
                     result      => 'Hello, my name isRoboBot.' },
    }},
);

sub clear_output {
    my ($self, $message) = @_;

    $message->response->clear_content;
}

sub join_str {
    my ($self, $message, $command, @args) = @_;

    return unless @args && scalar(@args) >= 2;
    return join($args[0], @args[1..$#args]);
}

sub print_str {
    my ($self, $message, $command, @args) = @_;

    $message->response->push(join('', @args));
}

__PACKAGE__->meta->make_immutable;

1;
