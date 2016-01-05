package RoboBot::Type::Macro;

use v5.20;

use namespace::autoclean;

use Moose;

use Scalar::Util qw( blessed );

extends 'RoboBot::Type';

has '+type' => (
    default => 'Macro',
);

has '+value' => (
    is        => 'rw',
    isa       => 'Str',
    required  => 1,
);

sub evaluate {
    my ($self, $message, $rpl, @args) = @_;

    return unless exists $self->bot->macros->{$message->network->id}{$self->value};
    return $self->bot->macros->{$message->network->id}{$self->value}->expand(
        $message,
        map {
            blessed($_) && $_->can('evaluate')
            ? $_->evaluate($message, $rpl)
            : $_
        } @args
    );
}

sub flatten {
    my ($self) = @_;

    return $self->value;
}

__PACKAGE__->meta->make_immutable;

1;
