package RoboBot::Nick;

use strict;
use warnings;

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
