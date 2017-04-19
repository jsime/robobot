package App::RoboBot::Plugin::Types::String;

use v5.20;

use namespace::autoclean;

use Moose;

use Number::Format;

extends 'App::RoboBot::Plugin';

=head1 types.string

Provides functions for creating and manipulating string-like values.

=cut

has '+name' => (
    default => 'Types::String',
);

has '+description' => (
    default => 'Provides functions for creating and manipulating string-like values.',
);

=head2 str

=head3 Description

Returns a single string, either a simple concatenation of all arguments, or an
empty string when no argument are given.

=head3 Usage

[<list>]

=head3 Examples

    :emphasize-lines: 2,5,8

    (str)
    ""

    (str "foo")
    "foo"

    (str foo 123 "bar" 456)
    "foo123bar456"

=head2 substring

=head3 Description

Returns ``n`` characters from ``str`` beginning at ``position`` (first
character in a string is ``0``).

Without ``n`` will return from ``position`` to the end of the original string.

A negative value for ``n`` will return from ``position`` until ``|n| - 1``
characters prior to the end of the string (``n = -1`` would have the same
effect as omitting ``n``).

=head3 Usage

<str> <position> [<n>]

=head3 Examples

    :emphasize-lines: 2

    (substring "The quick brown fox ..." 4 5)
    "quick"

=head2 index

=head3 Description

Returns the starting position(s) in a list of all occurrences of the substring
``match`` in ``str``. If ``match`` does not exist anywhere in ``str`` then an
empty list is returned.

=head3 Usage

<str> <match>

=head3 Examples

    :emphasize-lines: 2,5

    (index "The quick brown fox ..." "fox")
    (16)

    (index "The quick brown fox ..." "o")
    (12 17)

=head2 index-n

=head3 Description

Returns the nth (from 1) starting position of the substring ``match`` in
``str``.

If there are no occurrences of ``match`` in ``str``, or there are less than
``n``, nothing is returned.

=head3 Usage

=head3 Examples

    :emphasize-lines: 2

    (index-n "This string has three occurrences of the substring \"str\" in it." "str" 2)
    44

=head2 lower

=head3 Description

Converts the given string to lower-case.

=head3 Usage

<string>

=head3 Examples

    :emphasize-lines: 2

    (lower "Foo Bar Baz")
    "foo bar baz"

=head2 upper

=head3 Description

Converts the given string to upper-case.

=head3 Usage

<string>

=head3 Examples

    :emphasize-lines: 2

    (lower "Foo Bar Baz")
    "FOO BAR BAZ"

=head2 format

=head3 Description

Provides a printf-like string formatter. Placeholders follow the same rules as
printf(1).

=head3 Usage

<format string> [<list>]

=head3 Examples

    :emphasize-lines: 2

    (format "Random number: %d" (random 100))
    "Random number: 42"

=head2 format-number

=head3 Description

Provides numeric formatting for thousands separators, fixed precisions, and
trailing zeroes.

By default, numbers are formatted only with thousands separators added. Any
decimal places in the original number are preserved without any change in
precision.

By specifying a precision only, any decimal places will be truncated to that
as a maximum precision. The decimal places will not, however, be padded out
with zeroes unless a positive integer (anything > 0) is passed as the third
operand.

=head3 Usage

<number> [<precision> [<trailing zeroes>]]

=head3 Examples

    :emphasize-lines: 2,5,8

    (format-number 12398123)
    "12,398,123"

    (format-number 3.1459 2)
    "3.14"

    (format-number 5 4 1)
    "5.0000"

=head2 join

=head3 Description

Joins together arguments into a single string, using the first argument as the
delimiter.

=head3 Usage

<delimiter string> <list>

=head3 Examples

    :emphasize-lines: 2

    (join ", " (seq 1 10))
    "1, 2, 3, 4, 5, 6, 7, 8, 9, 10"

=cut

has '+commands' => (
    default => sub {{
        'substring'     => { method => 'str_substring' },
        'index'         => { method => 'str_index' },
        'index-n'       => { method => 'str_index_n' },
        'upper'         => { method => 'str_upper' },
        'lower'         => { method => 'str_lower' },
        'str'           => { method => 'str_str' },
        'format'        => { method => 'str_format' },
        'format-number' => { method => 'str_format_num' },
        'join'          => { method => 'str_join' },
    }},
);

has 'nf' => (
    is      => 'ro',
    isa     => 'Number::Format',
    default => sub { Number::Format->new() },
);

sub str_format {
    my ($self, $message, $command, $rpl, $format, @args) = @_;

    my $str;

    eval { $str = sprintf($format, @args) };

    if ($@) {
        $message->response->raise(sprintf('Error: %s', $@));
        return;
    }

    return $str;
}

sub str_format_num {
    my ($self, $message, $command, $rpl, @args) = @_;

    return $self->nf->format_number(@args);
}

sub str_join {
    my ($self, $message, $command, $rpl, @args) = @_;

    return unless @args && scalar(@args) >= 2;
    return join($args[0], @args[1..$#args]);
}

sub str_str {
    my ($self, $message, $command, $rpl, @list) = @_;

    return "" unless @list;
    return join('', @list);
}

sub str_upper {
    my ($self, $message, $command, $rpl, $str) = @_;

    return uc($str // '');
}

sub str_lower {
    my ($self, $message, $command, $rpl, $str) = @_;

    return lc($str // '');
}

sub str_index {
    my ($self, $message, $command, $rpl, $str, $match) = @_;

    unless (defined $str && defined $match) {
        $message->response->raise('Must provide a string and substring.');
        return;
    }

    # Short circuit if a match is going to be impossible. This is not an error.
    return [] if length($match) > length($str);

    my @positions;

    for (my $i = 0; $i <= length($str) - length($match); $i++) {
        push(@positions, $i) if substr($str, $i, length($match)) eq $match;
    }

    return \@positions;
}

sub str_index_n {
    my ($self, $message, $command, $rpl, $str, $match, $n) = @_;

    unless (defined $n && $n =~ m{^\d+$}) {
        $message->response->raise('Must supply <n> as a positive integer.');
        return;
    }

    my $matches = $self->str_index($message, $command, $rpl, $str, $match);

    return unless defined $matches && ref($matches) eq 'ARRAY' && scalar(@{$matches}) >= $n;
    return $matches->[$n - 1];
}

sub str_substring {
    my ($self, $message, $command, $rpl, $str, $pos, $n) = @_;

    unless (defined $str && defined $pos) {
        $message->response->raise('Must provide a string and starting position.');
        return;
    }

    unless ($pos =~ m{^-?\d+$}) {
        $message->response->raise('Starting position must be an integer.');
        return;
    }

    return "" if $pos >= length($str);

    if (defined $n) {
        if ($n =~ m{^-?\d+$}) {
            return substr($str, $pos, $n);
        } else {
            $message->response->raise('Character count <n> must be an integer.');
            return;
        }
    } else {
        return substr($str, $pos);
    }
}

__PACKAGE__->meta->make_immutable;

1;
