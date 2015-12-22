package RoboBot::Plugin::Macro;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use RoboBot::Macro;

use Data::Dumper;

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
                        description     => 'Defines a new macro, or replaces an existing macro of the same name. Macros may call, or even create/modify/delete other macros.',
                        usage           => '<name> (<... argument list ...>) \'(<definition body list>)',
                        example         => "plus-one (a) '(+ a 1)" },

        'undefmacro' => { method      => 'undefine_macro',
                          description => 'Undefines an existing macro.',
                          usage       => '<name>' },

        'show-macro' => { method      => 'show_macro',
                          description => 'Displays the definition of a macro.',
                          usage       => '<name>' },

        'list-macros' => { method      => 'list_macros',
                           description => 'Displays a list of all registered macros. Optional pattern will limit list to only those macros whose names match.',
                           usage       => '[<pattern>]', },

        'lock-macro' => { method      => 'lock_macro',
                          description => 'Locks a macro from further modification or deletion. This function is only available to the author of the macro.',
                          usage       => '<macro name>' },

        'unlock-macro' => { method      => 'unlock_macro',
                            description => 'Unlocks a previously locked macro, allowing it to once again be modified or deleted. This function is only available to the author of the macro.',
                            usage       => '<macro name>' },
    }},
);

sub list_macros {
    my ($self, $message, $command, $pattern) = @_;

    my $res = $self->bot->config->db->do(q{
        select name
        from macros
        where name ~* ?
        order by name asc
    }, ($pattern // '.*'));

    unless ($res) {
        $message->response->raise('Could not obtain list of macros. If you supplied a pattern, please ensure that it is a valid regular expression.');
        return;
    }

    my @macros;

    while ($res->next) {
        push(@macros, $res->{'name'});
    }

    $message->response->push(join(', ', @macros));
    return;
}

sub define_macro {
    my ($self, $message, $command, $macro_name, $args, $def) = @_;

    unless (defined $macro_name && defined $args && defined $def) {
        $message->response->raise('Macro definitions must consist of a name, a list of arguments, and a definition body list.');
        return;
    }

    if (exists $self->bot->macros->{lc($macro_name)} && $self->bot->macros->{lc($macro_name)}->is_locked) {
        if ($self->bot->macros->{lc($macro_name)}->definer->id != $message->sender->id) {
            $message->response->raise(
                'The %s macro has been locked by its creator (who happens to not be you) and cannot be redefined by anyone else.',
                $self->bot->macros->{lc($macro_name)}->name
            );
            return;
        }
    }

    unless (ref($args) eq 'ARRAY' && ref($def) eq 'ARRAY') {
        $message->response->raise('Macro arguments and definition body must both be provided as lists.');
        return;
    }

    # Work through the argument list looking for &optional (and maybe in the
    # future we'll do things like &key and friends), building up the arrayref
    # of hashrefs for our macro's arguments. Note: All values are forced into
    # plain strings via interpolation to drop all the D::S blessings.
    my $args_def = {
        has_optional => 0,
        positional   => [],
        keyed        => {},
        rest         => undef,
    };
    my $next_rest = 0;

    foreach my $arg (@{$args}) {
        if ($next_rest) {
            $args_def->{'rest'} = "$arg";
            $next_rest = 0;
            next;
        }

        # We hit an '&optional', so all following arguments are optional. And if
        # more than the stated number are passed, they can be accessed through
        # the autovivified &rest list in the macro.
        if ("$arg" eq '&optional') {
            $args_def->{'has_optional'} = 1;
            next;
        } elsif ("$arg" eq '&rest') {
            $next_rest = 1;
            next;
        }

        # TODO; Add support for &key'ed macro arguments.

        push(@{$args_def->{'positional'}}, {
            name     => "$arg",
            optional => $args_def->{'has_optional'},
        });
    }

    # Having &rest in the argument list without naming the variable into which
    # the remaining values will be placed is invalid. If the flag is still set
    # when we're done processing the arglist, then that has happened.
    if ($next_rest) {
        $message->response->raise('The &rest collection must be named.');
        return;
    }

    # We aren't really doing actual Lisp macros, just a shoddy simulacrum, so if someone has passed
    # a quoted list as the macro definition, pop out the list itself and remove the quoting before
    # we process everything and save the macro.
    if (@{$def} == 2 && "$def->[0]" eq 'backquote' && ref($def->[1]) eq 'ARRAY') {
        $def = $def->[1];
    }

    my $body;
    unless ($body = RoboBot::Macro->collapse($def)) {
        $message->response->raise('Could not collapse macro definition.');
        return;
    }

    if ($self->bot->add_macro($message->sender, $macro_name, $args_def, $body)) {
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

    if ($self->bot->macros->{$macro_name}->is_locked && $self->bot->macros->{$macro_name}->definer != $message->sender->id) {
        $message->response->raise(
            'The %s macro has been locked by its creator (who happens to not be you). You may not undefine it.',
            $self->bot->macros->{$macro_name}->name
        );
    } else {
        if ($self->bot->remove_macro($macro_name)) {
            $message->response->push(sprintf('Macro %s undefined.', $macro_name));
        } else {
            $message->response->push(sprintf('Could not undefine macro %s.', $macro_name));
        }
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

    my $pp;

    # Only do multi-line pretty-printing with indentation and all that other
    # fancy business for macros over a given length.
    if (length($macro->definition) > 40) {
        $pp = sprintf("(defmacro %s\n  (%s)\n  '%s)", $macro->name, $macro->signature, _pprint($macro->expression, 2));
    } else {
        $pp = sprintf('(defmacro %s (%s) \'%s)', $macro->name, $macro->signature, $macro->definition);
    }

    $pp =~ s{\n\s+([^\(]+)\n}{ $1\n}gs;
    $message->response->push($pp);
    $message->response->push(sprintf('Defined by <%s> on %s', $macro->definer->name, $macro->timestamp->ymd));
    $message->response->push('This macro is locked and may only be edited by its definer.') if $macro->is_locked;

    return;
}

sub lock_macro {
    my ($self, $message, $command, $macro) = @_;

    unless (defined $macro && $macro =~ m{\S+}) {
        $message->response->raise('Must provide the name of the macro you wish to lock.');
        return;
    }

    unless (exists $self->bot->macros->{lc($macro)}) {
        $message->response->raise('No such macro defined.');
        return;
    }

    $macro = $self->bot->macros->{lc($macro)};

    if ($macro->is_locked) {
        $message->response->raise('The macro %s is already locked.', $macro->name);
        return;
    }

    unless ($macro->definer->id == $message->sender->id) {
        $message->response->raise('You did not define the %s macro and cannot lock it. You may only lock your own macros.', $macro->name);
        return;
    }

    unless ($macro->lock(1) && $macro->save) {
        $message->response->raise('Could not lock the %s macro. Please try again.', $macro->name);
        return;
    }

    $message->response->push(sprintf('Your %s macro is now locked. Nobody but you may modify or delete it.', $macro->name));
    return;
}

sub unlock_macro {
    my ($self, $message, $command, $macro) = @_;

    unless (defined $macro && $macro =~ m{\S+}) {
        $message->response->raise('Must provide the name of the macro you wish to unlock.');
        return;
    }

    unless (exists $self->bot->macros->{lc($macro)}) {
        $message->response->raise('No such macro defined.');
        return;
    }

    $macro = $self->bot->macros->{lc($macro)};

    if ( ! $macro->is_locked) {
        $message->response->raise('The macro %s is not locked.', $macro->name);
        return;
    }

    unless ($macro->definer->id == $message->sender->id) {
        $message->response->raise('You did not define the %s macro and cannot unlock it. You may only unlock your own macros.', $macro->name);
        return;
    }

    unless ($macro->lock(0) && $macro->save) {
        $message->response->raise('Could not unlock the %s macro. Please try again.', $macro->name);
        return;
    }

    $message->response->push(sprintf('Your %s macro is now unlocked. Anybody else may modify or delete it.', $macro->name));
    return;
}

sub _pprint {
    my ($list, $nlv) = @_;

    $list //= [];
    $nlv  //= 1;

    if ($nlv <= 1 && ref($list) eq 'ARRAY' && scalar(@{$list}) == 1) {
        # Special-case looking for unnecessary nesting and remove the extra layers.
        return _pprint($list->[0], $nlv);
    } elsif (ref($list) eq 'ARRAY') {
        if (scalar(@{$list}) == 2 && $list->[0] eq 'backquote' && ref($list->[1]) eq 'ARRAY') {
            # Special case the '(...) forms so they don't show up as (backquote (...))
            return sprintf("'%s", _pprint($list->[1], $nlv));
        } elsif (scalar(grep { ref($_) eq 'ARRAY' } @{$list}) == 0) {
            # Simplest case: we are at a terminus list with no children.
            return sprintf('(%s)', join(' ', map { _fmtstr($_) } @{$list}));
        } else {
            # Harder case: there are child lists which must be formatted.
            my @subs;
            push(@subs, _pprint($_, $nlv + 1)) for @{$list};
            return sprintf('(%s)', join(sprintf("\n%s", "  " x $nlv), @subs));
        }
    } else {
        return _fmtstr($list);
    }
}

sub _fmtstr {
    my ($str) = @_;

    $str = "$str";

    if ($str =~ m{[\s"']}s) {
        $str =~ s{"}{\\"}g;
        $str =~ s{\n}{\\n}gs;
        return '"' . $str . '"';
    }
    return $str;
}

__PACKAGE__->meta->make_immutable;

1;
