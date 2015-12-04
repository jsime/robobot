package RoboBot::Parser;

use strict;
use warnings;

use Data::Dumper;

sub new {
    my ($class) = @_;

    my $self = {
        _err  => undef,
    };

    return bless $self, $class;
}

sub parse {
    my ($self, $text) = @_;

    return unless defined $text && !ref($text);
    return unless $text =~ m{^\s*\(.+\)\s*$}s;

    $self->{'_err'}  = undef;
    $self->{'_text'} = $text;
    $self->{'_pos'}  = [0];
    $self->{'_line'} = [1];
    $self->{'_col'}  = [1];
    $self->{'_chr'}  = [];

    my $expr = [];

    while (my $l = $self->_read_list) {
        push(@{$expr}, $l);
    }

    return unless @{$expr} > 0;

    # Remove unnecessary layers of nesting at the top level of the structure.
    while (ref($expr) eq 'ARRAY' && @{$expr} == 1 && ref($expr->[0]) eq 'ARRAY') {
        $expr = $expr->[0];
    }

    # Caller(s) expect a list of expressions, so we shouldn't be returning an
    # expression at the very top level of the structure.
    return [$expr];
}

sub error {
    my ($self) = @_;

    return unless exists $self->{'_err'} && defined $self->{'_err'};
    return sprintf('%s at %d (line %d, col %d)',
        $self->{'_err'}, $self->{'_pos'}[-1], $self->{'_line'}[-1], $self->{'_col'}[-1]
    );
}

sub _read_list {
    my ($self) = @_;

    my $l = [];

    while (defined (my $c = $self->_read_char)) {
        if ($c =~ m{[\s,]}) {
            next;
        } elsif ($c eq '(') {
            push(@{$l}, $self->_read_list);
        } elsif ($c eq ')') {
            return $l;
        } elsif ($c =~ m{\S}) {
            $self->_step_back;
            push(@{$l}, $self->_read_element);
        } else {
            $self->{'_err'} = 'Unexpected character "' . $c . '"';
            warn $self->error;
#            return;
        }
    }

    return $l if @{$l} > 0;
    return;
}

sub _read_element {
    my ($self) = @_;

    my $el = '';

    my $in_str  = 0;
    my $chr_esc = 0;

    while (defined (my $c = $self->_read_char)) {
        if ($c eq '"') {
            if ($in_str && !$chr_esc) {
                $in_str = 0;
            } elsif ($chr_esc) {
                $el .= '"';
                $chr_esc = 0;
            } else {
                $in_str = 1;
            }
        } elsif ($c eq ')' && !$in_str) {
            $self->_step_back;
            return $el;
        } elsif ($c =~ m{[\s,]}) {
            if ($in_str) {
                $el .= $c;
            } else {
                last;
            }
        } elsif ($c eq '\\') {
            if ($chr_esc) {
                $el .= $c;
                $chr_esc = 0;
            } else {
                $chr_esc = 1;
            }
        } elsif ($c eq "'" && length($el) == 0) {
            if ($self->_peek_char eq '(') {
                $self->_read_char;
                $el = ['backquote', $self->_read_list];
            } else {
                $el = ['backquote', $self->_read_element];
            }
        } else {
            $el .= $c;
        }
    }

    if ($in_str) {
        $self->{'_err'} = 'Unexpected end of string';
        warn $self->error;
        return;
    }

    return $el;
}

sub _read_char {
    my ($self) = @_;

    return unless length($self->{'_text'}) >= $self->{'_pos'}[-1];
    my $c = substr($self->{'_text'}, $self->{'_pos'}[-1], 1);
    return unless defined $c;

    push(@{$self->{'_pos'}}, $self->{'_pos'}[-1] + 1);

    if (scalar(@{$self->{'_chr'}}) > 0 && $self->{'_chr'}[-1] eq "\n") {
        push(@{$self->{'_line'}}, $self->{'_line'}[-1] + 1);
        push(@{$self->{'_col'}}, 1);
    } else {
        push(@{$self->{'_line'}}, $self->{'_line'}[-1]);
        push(@{$self->{'_col'}},  $self->{'_col'}[-1] + 1);
    }

    push(@{$self->{'_chr'}}, $c);

    return $c;
}

sub _peek_char {
    my ($self) = @_;

    my $c = $self->_read_char;
    return unless defined $c;

    $self->_step_back;
    return $c;
}

sub _step_back {
    my ($self) = @_;

    pop(@{$self->{'_pos'}});
    pop(@{$self->{'_line'}});
    pop(@{$self->{'_col'}});
    pop(@{$self->{'_chr'}});
}

1;
