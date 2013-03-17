package RoboBot::Macro;

use strict;
use warnings;

=head1 NAME

RoboBot::Macro - Management of user-defined command macros

=head1 SYNOPSIS

This modules provides for the creation, modification, and use of user-defined
command macros. These macros allow a user to combine pre-defined series of
other commands (any builtins or plugins), along with arguments, to be executed
any time the macro is sent to the channel.

Macros can be created or modified in an IRC channel with the following syntax:

    @+<macroname> <commands>

Deleted with:

    @-<macroname>

And run with:

    @<macroname> [arg1, ..., argN]

Arguments to macros are simple scalar values, and may be designated in the
macro definition using C<$$>. Any number may be used. Thus, if we want to create
a macro called C<bozo> which makes use of the Logger plugin's ability to recall
messages from a specific user (in our example "jon") that contain a particular
string, we can do so with:

    @+bozo !!$$ i'm.*bozo

After which we can run the macro, and (hypothetically) get back something like:

    <ournick> @bozo jon
    <RoboBot> <jon> i'm such a bozo, i just deleted my home directory

Macros may make use of multiple commands piped together, or even output
redirection. Macro processing (as you would expect) occurs prior to all other
message processing, and as such any pipes and redirects are saved as part of
the macro, not used to process the output of the macro management commands
themselves.

=cut

=head1 METHODS

=head2 new

=cut

sub new {
    my ($class, $bot, %args) = @_;

    my $self = bless {}, $class;

    $args{'mode'} = 'run' unless exists $args{'mode'};

    die "Macros require a name!" unless exists $args{'name'};

    $self->mode($args{'mode'});
    $self->name($args{'name'});
    $self->bot($bot);

    $self->nick($args{'nick'}) if exists $args{'nick'};

    return $self;
}

sub process {
    my ($self, $msg_ref, $args) = @_;

    return $self->macro_list($args || undef) if $self->mode eq 'list';
    return $self->macro_delete if $self->mode eq 'delete';
    return $self->macro_save($args) if $self->mode eq 'save';
    return $self->macro_run($msg_ref, $args) if $self->mode eq 'run';

    return;
}

sub bot {
    my ($self, $bot) = @_;

    if (defined $bot && ref($bot) eq 'RoboBot') {
        $self->{'bot'} = $bot;

        $self->db($bot->db) unless $self->db;
    }

    return $self->{'bot'} if exists $self->{'bot'};
    return;
}

sub db {
    my ($self, $db) = @_;

    $self->{'dbh'} = $db if defined $db && ref($db) eq 'DBIx::DataStore';

    return $self->{'dbh'} if exists $self->{'dbh'};
    return;
}

sub mode {
    my ($self, $mode) = @_;

    $self->{'mode'} = $mode if defined $mode;

    return $self->{'mode'} if exists $self->{'mode'};
    return;
}

sub name {
    my ($self, $name) = @_;

    $self->{'name'} = $name if defined $name;

    return $self->{'name'} if exists $self->{'name'};
    return;
}

sub nick {
    my ($self, $nick) = @_;

    $self->{'nick'} = $nick if defined $nick && ref($nick) eq 'RoboBot::Nick';

    return $self->{'nick'} if exists $self->{'nick'};
    return;
}

sub macro_list {
    my ($self, $name) = @_;

    if (defined $name) {
        my $res = $self->db->do(q{
            select * from macros where nick_id = ? and lower(name) = lower(?)
        }, $self->nick->id, $name);

        return sprintf('%s := %s', $res->{'name'}, $res->{'macro'}) if $res && $res->next;
        return sprintf('You have no defined macros named "%s".', $name);
    } else {
        my $res = $self->db->do(q{
            select name
            from macros
            where nick_id = ?
            order by name asc
        }, $self->nick->id);

        my @macros;

        while ($res->next) {
            push(@macros, $res->{'name'});
        }

        return sprintf('You have no macros.') if scalar(@macros) < 1;

        my @output = sprintf('Defined macros: %s', join(', ', take_n(20, \@macros)));
        push(@output, join(', ', take_n(20, \@macros))) while scalar(@macros) > 0;

        return @output;
    }

    return;
}

sub macro_delete {
    my ($self) = @_;

    my $res = $self->db->do(q{
        delete from macros where nick_id = ? and lower(name) = lower(?)
    }, $self->nick->id, $self->name);

    return sprintf('Macro "%s" deleted.', $self->name) if $res;
    return sprintf('Could not delete macro by the name of "%s".', $self->name);
}

sub macro_save {
    my ($self, $arg) = @_;

    my $res = $self->db->do(q{
        select macro_id from macros where nick_id = ? and lower(name) = lower(?)
    }, $self->nick->id, $self->name);

    if ($res && $res->next) {
        $res = $self->db->do(q{
            update macros
            set macro = ?,
                updated_at = now()
            where nick_id = ? and lower(name) = lower(?)
        }, $arg, $self->nick->id, $self->name);

        return sprintf('Macro "%s" successfully updated.', $self->name) if $res;
        return sprintf('Could not update macro "%s".', $self->name);
    } else {
        $res = $self->db->do(q{
            insert into macros
                ( nick_id, name, macro )
            values
                ( ?, ?, ? )
        }, $self->nick->id, $self->name, $arg);

        return sprintf('Macro "%s" successfully saved.', $self->name) if $res;
        return sprintf('Could not save macro "%s".', $self->name);
    }

    return;
}

sub macro_run {
    my ($self, $msg_ref, $arg) = @_;

    my $macro = $self->db->do(q{
        select * from macros where nick_id = ? and lower(name) = lower(?)
    }, $self->nick->id, $self->name);

    return sprintf('No such macro "%s".', $self->name) unless $macro && $macro->next;

    my @args = grep { defined $_ && length($_) > 0 } split(/\s+/, $arg);
    $_ =~ s{(^\s+|\s+$)}{}ogs for @args;

    $macro->{'macro'} =~ s{\$\$}{ shift @args }oge;

    $$msg_ref = $macro->{'macro'};
    return;
}

sub take_n {
    my ($num, $ref) = @_;

    my @ret;

    my $i = 0;
    push(@ret, shift @{$ref}) while $i++ < $num && scalar(@{$ref}) > 0;

    return @ret;
}

1;
