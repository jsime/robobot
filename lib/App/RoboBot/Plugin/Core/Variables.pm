package App::RoboBot::Plugin::Core::Variables;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
use Scalar::Util qw( blessed );

use App::RoboBot::Parser;

extends 'App::RoboBot::Plugin';

=head1 core.variables

Provides functions to create and manage variables.

There are two basic classes of variables in App::Robobot: global and lexically
scoped variables. The latter are handled by the ``let`` form and are not
covered here.

Global variables, those created with ``def`` are persistent across messages and
are accessible from all channels on the current network. They may be reused by
multiple messages, have their value updated repeatedly, and may be undefined by
any message on the same network. They are not visible across networks.

=cut

has '+name' => (
    default => 'Core::Variables',
);

has '+description' => (
    default => 'Provides functions to create and manage variables.',
);

=head2 def

=head3 Description

Defines a new global variable with the given value (or values, which will store
the list of values in the global). Note that if a quoted expression is
provided, it is captured and only evaluated when the variable is used. What
sets this apart from defining a macro is that global variable expressions
receive no arguments.

If the name of a global variable is provided, but no value or expression
follows, the definition of the variable is returned.

Repeated use of ``def`` with the same variable name will clobber prior values.

=head3 Usage

<name> [<value or quoted expression>]

=head3 Examples

    :emphasize-lines: 3,6

    (def two 2)
    (val two)
    2

    (def two)
    (def two 2)

=head2 defined?

=head3 Description

Returns true if the name provided is that of a currently defined global. False
in all other cases.

=head3 Usage

<name>

=head3 Examples

    :emphasize-lines: 3,6

    (def two 2)
    (defined? two)
    1

    (defined? this-is-not-a-variable)
    0

=head2 decr

=head3 Description

Given the name of a global variable which exists and stores a scalar numeric
value, decrements that stored value by 1 and returns the newly stored value.
The use of a global variable name which currently does not exist initializes a
global variable with the value of zero. If the variable exists, but contains
anything other than a scalar numeric, no change is made to the stored value and
a zero is returned.

=head3 Usage

<name>

=head3 Examples

    :emphasize-lines: 3,6,9

    (def my-counter 50)
    (decr my-counter)
    49

    (val my-counter)
    49

    (decr non-existent-counter)
    0

=head2 incr

=head3 Description

Given the name of a global variable which exists and stores a scalar numeric
value, increments that stored value by 1 and returns the newly stored value.
The use of a global variable name which currently does not exist initializes a
global variable with the value of zero. If the variable exists, but contains
anything other than a scalar numeric, no change is made to the stored value and
a zero is returned.

=head3 Usage

<name>

=head3 Examples

    :emphasize-lines: 3,6,9

    (def my-counter 50)
    (incr my-counter)
    51

    (val my-counter)
    51

    (incr non-existent-counter)
    0

=head2 undef

=head3 Description

If given the name of an extant global variable, undefines it while returning
the current value. Returns nil if the variable name does not exist.

=head3 Usage

<name>

=head3 Examples

    :emphasize-lines: 3,6

    (def two 2)
    (undef two)
    2

    (undef two)
    nil

=head2 val

=head3 Description

Returns the current value of the named global variable. Returns nil if the
variable does not exist. If the variable name references an expression, that
expression is evaluated and its result is returned.

=head3 Usage

<name>

=head3 Examples

    :emphasize-lines: 3,7,10

    (def two 2)
    (val two)
    2

    (def two-by-mathing '(+ 1 1))
    (def two-by-mathing)
    (+ 1 1)

    (val two-by-mathing)
    2

=cut

has '+commands' => (
    default => sub {{
        'def'      => { method => 'var_define', preprocess_args => 0 },
        'defined?' => { method => 'var_defined' },
        'decr'     => { method => 'var_decrement' },
        'incr'     => { method => 'var_increment' },
        'undef'    => { method => 'var_undefine' },
        'val'      => { method => 'var_value' },
    }},
);

sub var_define {
    my ($self, $message, $command, $rpl, $name, @values) = @_;

    if (defined $name && blessed($name) && $name->can('evaluate')) {
        $name = $name->evaluate($message, $rpl);
    } else {
        $message->response->raise('Must provide a name for the global variable.');
        return;
    }

    if (@values < 1) {
        # No new values provided, so show the definition without any evaluation
        my $res = $self->bot->config->db->do(q{
            select *
            from global_vars
            where network_id = ?
                and lower(var_name) = lower(?)
        }, $message->network->id, $name);

        unless ($res && $res->next) {
            $message->response->raise('No such global variable %s.', $name);
            return;
        }

        return @{$res->{'var_values'}};
    }

    my @flattened = map { $_->flatten } @values;

    my $res = $self->bot->config->db->do(q{
        update global_vars
        set var_values = ?,
            created_by = ?,
            updated_at = now()
        where network_id = ?
            and lower(var_name) = lower(?)
        returning *
    }, \@flattened, $message->sender->id, $message->network->id, $name);

    if ($res && $res->next) {
        $message->response->push(sprintf('Global variable %s updated.', $name));
        return;
    } else {
        $res = $self->bot->config->db->do(q{
            insert into global_vars ??? returning *
        }, {
            network_id => $message->network->id,
            var_name   => $name,
            var_values => \@flattened,
            created_by => $message->sender->id,
        });

        if ($res && $res->next) {
            $message->response->push(sprintf('Global variable %s created.', $name));
            return;
        }
    }

    $message->response->raise('Error while working with %s global variable definition.', $name);
    return;
}

sub var_defined {
    my ($self, $message, $command, $rpl, $name) = @_;

    unless (defined $name && $name =~ m{w\+}) {
        $message->response->raise('Must provide a variable name to check for defined-ness.');
        return;
    }

    my $res = $self->bot->config->db->do(q{
        select id
        from global_vars
        where network_id = ?
            and lower(var_name) = lower(?)
    }, $message->network->id, $name);

    return 1 if $res && $res->next;
    return 0;
}

sub var_decrement {
    my ($self, $message, $command, $rpl, $name) = @_;

    return $self->var_adjust($message, $name, -1);
}

sub var_increment {
    my ($self, $message, $command, $rpl, $name) = @_;

    return $self->var_adjust($message, $name, 1);
}

sub var_adjust {
    my ($self, $message, $name, $amount) = @_;

    unless (defined $name && $name =~ m{w\+}) {
        $message->response->raise('Must provide a variable name to increment or decrement.');
        return;
    }

    my $res = $self->bot->config->db->do(q{
        select id, var_values
        from global_vars
        where network_id = ?
            and lower(var_name) = lower(?)
    }, $message->network->id, $name);

    if ($res && $res->next) {
        if (@{$res->{'var_values'}} == 1 && $res->{'var_values'}[0] =~ m{^\d+$}o) {
            $res = $self->bot->config->db->do(q{
                update global_vars
                set var_value = ?,
                    updated_at = now()
                where id = ?
            }, [$res->{'var_values'}[0] + $amount], $res->{'id'});

            return $res->{'var_values'}[0] + $amount if $res;

            $message->response->raise('Could not adjust %s. Please try again.', $name);
            return $res->{'var_values'}[0];
        } else {
            $message->response->raise('Global variable %s is not a scalar numeric.', $name);
            return;
        }
    } else {
        $res = $self->bot->config->db->do(q{
            insert into global_vars ???
        }, {
            network_id  => $message->network->id,
            var_name    => $name,
            var_values  => [0],
            created_by  => $message->sender->id
        });

        return 0 if $res;

        $message->response->raise('Could not create new global variable %s.', $name);
        return;
    }

    return;
}

sub var_undefine {
    my ($self, $message, $command, $rpl, $name) = @_;

    unless (defined $name && $name =~ m{\w+}o) {
        $message->response->raise('Must provide name of global variable to undefine.');
        return;
    }

    my $res = $self->bot->config->db->do(q{
        delete from global_vars
        where network_id = ?
            and lower(var_name) = lower(?)
    }, $message->network->id, $name);

    return if $res;

    $message->response->raise('Could not undefine global variable %s.', $name);
    return;
}

sub var_value {
    my ($self, $message, $command, $rpl, $name) = @_;

    unless (defined $name && $name =~ m{\w+}o) {
        $message->response->raise('Must provide a global variable name who value you are retrieving.');
        return;
    }

    my $res = $self->bot->config->db->do(q{
        select *
        from global_vars
        where network_id = ?
            and lower(var_name) = lower(?)
    }, $message->network->id, $name);

    unless ($res && $res->next) {
        $message->response->raise('No such global variable %s.', $name);
        return;
    }

    my @ret;
    my $parser = App::RoboBot::Parser->new( bot => $self->bot );

    foreach my $v (@{$res->{'var_values'}}) {
        my $expr = $parser->parse($v);

        if (defined $expr && blessed($expr) && $expr->can('evaluate')) {
            push(@ret, $expr->evaluate($message, $rpl));
        }
    }

    return @ret;
}

__PACKAGE__->meta->make_immutable;

1;
