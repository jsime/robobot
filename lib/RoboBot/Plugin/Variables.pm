package RoboBot::Plugin::Variable;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Variable',
);

has '+description' => (
    default => 'Provides functions to create and manage variables.',
);

has '+commands' => (
    default => sub {{
        'setvar' => { method  => 'setvar',
                      usage   => '<variable name> <value or expression>',
                      example => 'foo "A Value"',
                      result  => 'A Value' },

        'undef' => { method  => 'undef_var',
                     usage   => '<variable name>',
                     example => 'foo',
                     result  => '' },
    }},
);

sub setvar {
    my ($self, $message, $command, @args) = @_;

    if (@args && @args == 2 && $args[0] =~ m{^[\$\@\*\:\+0-9a-zA-Z_-]+$}) {
print STDERR "Setting variable $args[0] to $args[1]\n";
        return $message->vars->{$args[0]} = $args[1];
    }

    return $self->usage($message, 'setvar');
}

sub undef_var {
    my ($self, $message, $command, @args) = @_;

    if (@args && @args == 1) {
        if (exists $message->vars->{$args[0]}) {
            return delete $message->vars->{$args[0]};
        } else {
            return $message->response->raise('No such variable.');
        }
    }

    return $self->usage($message, 'undef');
}

__PACKAGE__->meta->make_immutable;

1;
