package RoboBot::Plugin::Output;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

use Number::Format;

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

        'format' => { method      => 'format_str',
                      description => 'Provides a printf-like string formatter. Placeholders follow the same rules as printf(1).',
                      usage       => '"<format>" [<value 1> ... <value N>]',
                      example     => '"%d / %d = %.2f" 5 3 (/ 5 3)',
                      result      => '5 / 3 = 1.67' },

        'format-number' => { method      => 'format_num',
                             description => 'Provides numeric formatting for thousands separators, fixed precisions, and trailing zeroes.',
                             usage       => '<number> [<precision> [<trailing zeroes>]]',
                             example     => '1830472.2 4 1',
                             result      => '1,830,472.2000' },
    }},
);

has 'nf' => (
    is      => 'ro',
    isa     => 'Number::Format',
    default => sub { Number::Format->new() },
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

sub format_str {
    my ($self, $message, $command, $format, @args) = @_;

    my $str;

    eval { $str = sprintf($format, @args) };

    if ($@) {
        $message->response->raise(sprintf('Error: %s', $@));
        return;
    }

    return $str;
}

sub format_num {
    my ($self, $message, $command, @args) = @_;

    return $self->nf->format_number(@args);
}

__PACKAGE__->meta->make_immutable;

1;
