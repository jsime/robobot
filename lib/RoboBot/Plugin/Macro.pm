package RoboBot::Plugin::Macro;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

use RoboBot::Macro;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Macro',
);

has '+description' => (
    default => 'Provides functionality for defining and managing macros. Macros defined by this plugin are available to all users across all connected networks and channels, and persist across bot restarts.',
);

has '+commands' => (
    default => sub {{
        'defmacro' => { method          => 'define_macro',
                        preprocess_args => 0,
                        description     => 'Defines a new macro, or replaces an existing macro of the same name.',
                        usage           => '<name> (<... argument list ...>) (<definition body list>)',
                        example         => "plus-one (a) '(+ a 1)" },

        'undefmacro' => { method      => 'undefine_macro',
                          description => 'Undefines an existing macro.',
                          usage       => '<name>' },

        'show-macro' => { method      => 'show_macro',
                          description => 'Displays the definition of a macro.',
                          usage       => '<name>' },
    }},
);

sub define_macro {
    my ($self, $message, $command, $macro_name, $args, $def) = @_;

    unless (defined $macro_name && defined $args && defined $def) {
        $message->response->raise('Macro definitions must consist of a name, a list of arguments, and a definition body list.');
        return;
    }

    unless (ref($args) eq 'ARRAY' && ref($def) eq 'ARRAY') {
        $message->response->raise('Macro arguments and definition body must both be provided as lists.');
        return;
    }

    # Force entries in arguments list into plain scalar strings (removing the D::S class)
    foreach my $arg (@{$args}) {
        $arg = "$arg";
    }

    # We aren't really doing actual Lisp macros, just a shoddy simulacrum, so if someone has passed
    # a quoted list as the macro definition, pop out the list itself and remove the quoting before
    # we process everything and save the macro.
    if (@{$def} == 2 && "$def->[0]" eq 'quote' && ref($def->[1]) eq 'ARRAY') {
        $def = $def->[1];
    }

    my $body;
    unless ($body = RoboBot::Macro->collapse($def)) {
        $message->response->raise('Could not collapse macro definition.');
        return;
    }

    if ($self->bot->add_macro($message->sender, $macro_name, $args, $body)) {
        $message->response->push(sprintf('Macro %s defined.', $macro_name));
    } else {
        $message->response->raise('Could not define macro %s.', $macro_name);
    }

    return;
}

sub undefine_macro {
    my ($self, $message, $command, $macro_name) = @_;

    unless (defined $macro_name && $macro_name =~ m{\w+}o) {
        $message->response->raise('Must provide the name of a macro to undefine.');
        return;
    }

    unless (exists $self->bot->macros->{$macro_name}) {
        $message->response->raise('Macro %s has not been defined.', $macro_name);
        return;
    }

    if ($self->bot->remove_macro($macro_name)) {
        $message->response->push(sprintf('Macro %s undefined.', $macro_name));
    } else {
        $message->response->push(sprintf('Could not undefine macro %s.', $macro_name));
    }

    return;
}

sub show_macro {
    my ($self, $message, $command, $macro_name) = @_;

    unless (defined $macro_name && exists $self->bot->macros->{$macro_name}) {
        $message->response->raise('No such macro defined.');
        return;
    }

    my $macro = $self->bot->macros->{$macro_name};

    $message->response->push(sprintf('(defmacro %s (%s) \'%s)', $macro->name, join(' ', @{$macro->arguments}), $macro->definition));
    $message->response->push(sprintf('Defined by <%s> on %s', $macro->definer->nick, $macro->timestamp->ymd));

    return;
}

__PACKAGE__->meta->make_immutable;

1;
