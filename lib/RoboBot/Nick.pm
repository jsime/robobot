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

sub new {
    my ($class, $bot, %args) = @_;

    my $self = bless {}, $class;

    $self->bot($bot) if defined $bot;

    return $self;
}

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

sub db {
    my ($self, $dbh) = @_;

    $self->{'dbh'} = $dbh if defined $dbh && ref($dbh) eq 'DBIx::DataStore';
    return $self->{'dbh'} if exists $self->{'dbh'};
    return;
}

sub id {
    my ($self) = @_;

    return $self->{'id'} if exists $self->{'id'} || $self->save;
    return;
}

sub nick {
    my ($self, $nick) = @_;

    if (defined $nick && $nick =~ m{^\w+$}o) {
        $nick =~ s{(^\s+|\s+$)}{}ogs;
        $self->{'nick'} = $nick;
    }

    return unless exists $self->{'nick'};
    return $self->{'nick'};
}

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
