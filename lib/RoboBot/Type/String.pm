package RoboBot::Type::String;

use v5.20;

use namespace::autoclean;

use Moose;

extends 'RoboBot::Type';

has '+type' => (
    default => 'String',
);

has '+value' => (
    is        => 'rw',
    isa       => 'Str',
);

sub flatten {
    my ($self) = @_;

    return "nil" unless $self->has_value;

    my $v = $self->value;
    $v =~ s{"}{\\"}g;
    $v =~ s{\n}{\\n}g;
    $v =~ s{\r}{\\r}g;
    $v =~ s{\t}{\\t}g;

    return '"' . $v . '"';
}

__PACKAGE__->meta->make_immutable;

1;
