package RoboBot::Nick;

use strict;
use warnings;

=head1 NAME

RoboBot::Nick - Manages looking up and saving nicks encountered during IRC
message processing.

=head1 SYNOPSIS

Usage is simple:

    my $nick = RoboBot::Nick->new($bot);

Or:

    my $nick = RoboBot::Nick->new->bot($bot);

For database interaction and ensuring that nicks are properly associated to
a server (given that a single RoboBot instance may be connected to any number
of distinct servers), Nick objects created need to be given a reference to
the caller's RoboBot instance (shown above as $bot).

This gives the Nick module access to the same RoboBot::Config and DBIx::DataStore
objects that RoboBot itself (as well as all its plugins) uses.

=cut

=head1 METHODS

=head2 new

Accepts one optional argument, which is the RoboBot $bot object for the current
context (from which it will inherit the DBIx::DataStore database object).

=cut

sub new {
    my ($class, $bot, %args) = @_;

    my $self = bless {}, $class;

    $self->bot($bot) if defined $bot;

    return $self;
}

=head2 bot

Getter/setter for the current context's RoboBot object.

=cut

sub bot {
    my ($self, $bot) = @_;

    if (defined $bot && ref($bot) eq 'RoboBot') {
        $self->{'bot'} = $bot;
        $self->db($bot->dbh);
    } elsif (defined $bot) {
        delete $self->{'bot'};
    }

    return $self->{'bot'} if exists $self->{'bot'};
    return;
}

=head2 db

Getter/setter for the current context's DBIx::DataStore object. You can override
this to an object which does not match that of the Nick's bot() reference, but
you may find strange results result from such a strange approach.

=cut

sub db {
    my ($self, $dbh) = @_;

    $self->{'dbh'} = $dbh if defined $dbh && ref($dbh) eq 'DBIx::DataStore';
    return $self->{'dbh'} if exists $self->{'dbh'};
    return;
}

=head2 id

Getter method for the current nick's ID. Returns nothing if there is no associated
nick (i.e. you have not called the nick() method yet). Will automatically save the
nick to the database if it is new and has not yet received an ID. If the nick is
already present in the database, this simply returns the existing ID.

=cut

sub id {
    my ($self) = @_;

    return unless exists $self->{'nick'} && $self->{'nick'} =~ m{\w+}o;
    return $self->{'id'} if exists $self->{'id'} || $self->save;
    return;
}

=head2 nick

Getter/setter for the object's nick.

=cut

sub nick {
    my ($self, $nick) = @_;

    if (defined $nick && $nick =~ m{^\w+$}o) {
        $nick =~ s{(^\s+|\s+$)}{}ogs;
        $self->{'nick'} = $nick;
    }

    return unless exists $self->{'nick'};
    return $self->{'nick'};
}

=head2 save

Forces a save of the object's nick to the database. This method will first check
the database for a match against the nick (case insensitive) and if one is found,
then the current Nick object will be associated with that record by returning its
ID. If no match it found, a new record will be created and the ID returned.

This method is automatically called by the id() method, if the Nick object has
not yet been saved.

=cut

sub save {
    my ($self) = @_;

    return unless exists $self->{'dbh'};
    return unless $self->nick;

    my ($res);

    $self->db->begin;

    if (exists $self->{'id'}) {
        $res = $self->db->do(q{
            update nicks set nick = ? where id = ?
        }, $self->{'nick'}, $self->{'id'});

        unless ($res) {
            $self->db->rollback;
            return;
        }
    } else {
        $res = $self->db->do(q{
            insert into nicks (nick) values (?) returning id
        }, $self->{'nick'};

        unless ($res && $res->next && $res->{'id'} =~ m{^\d+$}o) {
            $self->db->rollback;
            return;
        }

        $self->{'id'} = $res->{'id'};
    }

    $self->db->commit;
    return $self->{'id'};
}

1;
