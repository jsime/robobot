package RoboBot::Plugin::Output;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
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

        'split' => { method      => 'split_str',
                     description => 'Splits a string into a list based on the delimiter provided. Delimiters may be a regular expression or fixed string.',
                     usage       => '<delimiter> <string>',
                     example     => '"[,\s]+" "1, 2, 3,4,    5"',
                     result      => '(1 2 3 4 5)' },

        'print' => { method      => 'print_str',
                     description => 'Prints input arguments. If one argument is given, it is simply echoed unaltered. If multiple arguments are given they are printed in array notation.',
                     usage       => '<value> [<value 2> ... <value N>]',
                     example     => 'foo 123 bar 456',
                     result      => '[foo, 123, bar, 456]' },

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

sub split_str {
    my ($self, $message, $command, $pattern, $string) = @_;

    return unless defined $pattern && defined $string;

    my @list;

    eval {
        @list = split(m{$pattern}, $string);
    };

    if ($@) {
        $message->response->raise('Invalid pattern provided for splitting.');
        return;
    }

    return @list;
}

sub print_str {
    my ($self, $message, $command, @args) = @_;

    if (@args) {
        if (@args > 1) {
            local $Data::Dumper::Indent = 0;
            local $Data::Dumper::Terse  = 1;

            $message->response->push(Dumper(\@args));
        } else {
            $message->response->push($args[0]);
        }

        return @args;
    }
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
