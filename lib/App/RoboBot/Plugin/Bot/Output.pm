package App::RoboBot::Plugin::Bot::Output;

use v5.20;

use namespace::autoclean;

use Moose;

use Scalar::Util qw( looks_like_number );

extends 'App::RoboBot::Plugin';

=head1 bot.output

Provides string formatting and output/display functions.

=cut

has '+name' => (
    default => 'Bot::Output',
);

has '+description' => (
    default => 'Provides string formatting and output/display functions.',
);

=head2 clear

=head3 Description

Clears current contents of the output buffer without displaying them.

This applies only to normal output - error messages will still be displayed to
the user should occur.

=head2 print

=head3 Description

Prints input arguments. If one argument is given, it is echoed unaltered. If
multiple arguments are given they are printed in array notation.

=head3 Usage

<value> [<value> ...]

=head3 Examples

    :emphasize-lines: 2,5

    (print "foo")
    "foo"

    (print foo 123 "bar" 456)
    ("foo" 123 "bar" 456)

=cut

has '+commands' => (
    default => sub {{
        'clear'         => { method => 'clear_output' },
        'print'         => { method => 'print_str' },
    }},
);

sub clear_output {
    my ($self, $message) = @_;

    $message->response->clear_content;
}

sub print_str {
    my ($self, $message, $command, $rpl, @args) = @_;

    # Do nothing if we received nothing.
    return unless @args && @args > 0;

    # If we received only a single scalar value, send that unaltered as the message,
    # and return it to any outer expression.
    if (@args == 1 && !ref($args[0])) {
        $message->response->push($args[0]);
        return @args;
    }

    # For everything else, traverse the input and pretty-print it on a single
    # line with appropriate expression/type markup.
    my $output = '';
    _print_el($self->bot, \$output, $_) for @args;

    $output =~ s{(^\s+|\s+$)}{}ogs;

    $output = "($output)" if @args > 1;

    $message->response->push($output);
    return @args;
}

sub _print_el {
    my ($bot, $output, $el) = @_;

    if (!defined $el) {
        $$output .= " undef";
    } elsif (ref($el) eq 'HASH') {
        _print_map($bot, $output, $el);
    } elsif (ref($el) eq 'ARRAY') {
        _print_list($bot, $output, $el);
    } elsif (looks_like_number($el)) {
        $$output .= " $el";
    } else {
        $el =~ s{"}{\\"}g;
        $el =~ s{\n}{\\n}gs;
        $el =~ s{\r}{\\r}gs;
        $el =~ s{\t}{\\t}gs;
        $$output .= sprintf(' "%s"', $el);
    }

    return;
}

sub _print_list {
    my ($bot, $output, $list) = @_;

    $$output .= ' (';

    if (!ref($list->[0]) && (exists $bot->commands->{lc($list->[0])} || exists $bot->macros->{lc($list->[0])})) {
        $$output .= shift @{$list};
    }

    _print_el($bot, $output, $_) for @{$list};

    $$output .= ')';
}

sub _print_map {
    my ($bot, $output, $map) = @_;

    $$output .= ' {';

    foreach my $k (keys %{$map}) {
        $$output .= " $k";
        _print_el($bot, $output, $map->{$k});
    }

    $$output .= ' }';
}

__PACKAGE__->meta->make_immutable;

1;
