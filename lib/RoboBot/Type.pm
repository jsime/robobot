package RoboBot::Type;

use v5.20;

use namespace::autoclean;

use Moose;

use Scalar::Util qw( blessed );

has 'bot' => (
    is       => 'ro',
    isa      => 'RoboBot',
    required => 1,
);

has 'type' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'nil',
);

has 'value' => (
    is        => 'rw',
    predicate => 'has_value',
);

has 'quoted' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub ast {
    my ($self) = @_;

    return $self->type;
}

sub build_from_val {
    my ($class, $bot, $val, $quoted) = @_;

    $quoted //= 0;

    return unless defined $bot && defined $val;

    # If we're building a List or Expression, we need to downgrade to Strings
    # any operands that follow which are marked as Macros, since a macro must
    # always be the operator.
    if (ref($val) eq 'ARRAY') {
        foreach my $el (@{$val}[1..$#$val]) {
            next unless blessed($el) && $el->type eq 'Macro';
            $el = RoboBot::Type::String->new(
                bot    => $bot,
                value  => $el->value,
                quoted => $el->quoted,
            );
        }
    }

    return $class->new(
        bot    => $bot,
        value  => $val,
        quoted => $quoted,
    );
}

# TODO: Need better name, since we don't follow the return value conventions of
#       C/Perl style cmp functions.
sub cmp {
    shift if $_[0] eq __PACKAGE__;
    my ($obj_a, $obj_b) = @_;

    return 0 unless defined $obj_a && defined $obj_b;

    # Basic checks that these are actually Type objects and not something else.
    return 0 unless ref($obj_a) =~ m{^RoboBot::Type} && ref($obj_b) =~ m{^RoboBot::Type};

    # Objects of different types cannot be the same as each other. We aren't
    # testing whether two things evaluate to the same state, but whether they
    # are *currently* the same.
    return 0 if $obj_a->type ne $obj_b->type;

    # If they don't both have values, there's no comparison that will succeed.
    return 0 if $obj_a->is_nil || $obj_b->is_nil;

    # Delegate to Type's _cmp method to handle the specifics, if supported.
    return $obj_a->_cmp($obj_b) if $obj_a->can('_cmp');

    # Otherwise just do a naive stringy comparison of ->value returns;
    return 1 if $obj_a->value eq $obj_b->value;
    return 0;
}

sub evaluate {
    my ($self, $message, $rpl) = @_;

    return unless $self->has_value;

    if (defined $rpl && ref($rpl) eq 'HASH' && exists $rpl->{$self->value}) {
        return $rpl->{$self->value};
    } else {
        return $self->value;
    }
}

sub flatten {
    my ($self, $rpl) = @_;

    return 'nil' unless $self->has_value;
    return $self->evaluate(undef, $rpl);
}

sub is_nil {
    my ($self) = @_;

    return ! $self->has_value;
}

sub pprint {
    my ($self) = @_;

    # TODO: Replace flattening with actual pretty-printing.
    return $self->flatten;
}

__PACKAGE__->meta->make_immutable;

1;
