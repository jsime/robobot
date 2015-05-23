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
        'setvar' => { method          => 'set_var',
                      preprocess_args => 0,
                      description     => 'Sets the value of a variable.',
                      usage           => '<variable name> <value or expression>',
                      example         => 'foo 10',
                      result          => '10' },

        'unsetvar' => { method          => 'unset_var',
                        preprocess_args => 0,
                        description     => 'Unsets a variable and removes it from the symbol table.',
                        usage           => '<variable name>',
                        example         => 'foo',
                        result          => '' },

        'incr' => { method          => 'increment_var',
                    preprocess_args => 0,
                    description     => 'Increments a numeric variable by the given amount. If no increment amount is provided, 1 is assumed. Negative amounts are permissible.',
                    usage           => '<variable name> [<amount>]' },
    }},
);

sub set_var {
    my ($self, $message, $command, @args) = @_;

    if (@args && @args == 2 && $args[0] =~ m{^[\$\@\*\:\+0-9a-zA-Z_-]+$}) {
        return $message->vars->{$args[0]} = $self->bot->process_list($message, $args[1]);
    }
}

sub unset_var {
    my ($self, $message, $command, @args) = @_;

    if (@args && @args == 1) {
        if (exists $message->vars->{$args[0]}) {
            return delete $message->vars->{$args[0]};
        } else {
            return $message->response->raise('No such variable.');
        }
    }
}

sub increment_var {
    my ($self, $message, $command, $var_name, $amount) = @_;

    $amount = 1 unless defined $amount;

    unless (defined $var_name && exists $self->message->vars->{$var_name}) {
        return $message->response->raise('Variable name unspecified or invalid.');
    }

    unless ($amount =~ m{\d+}o && m{^-?\d*\.\d*$}o) {
        return $message->response->raise('Increment amount "%s" does not appear to be a valid number.', $amount);
    }

    unless ($self->message->vars->{$var_name} =~ m{^-?\d*\.\d*$}o) {
        return $message->response->raise('Variable "%s" is not numeric. Cannot increment.', $var_name);
    }

    $self->message->vars->{$var_name} += $amount;
    return $self->message->vars->{$var_name};
}

__PACKAGE__->meta->make_immutable;

1;
