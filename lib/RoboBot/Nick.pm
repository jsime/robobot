package RoboBot::Nick;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

has 'id' => (
    is     => 'rw',
    isa    => 'Int',
    traits => [qw( SetOnce )],
);

has 'nick' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    traits   => [qw( SetOnce )],
);

has 'alts' => (
    is  => 'rw',
    isa => 'ArrayRef[Str]',
);

has 'config' => (
    is       => 'ro',
    isa      => 'RoboBot::Config',
    required => 1,
);

sub BUILD {
    my ($self) = @_;

    # TODO basic normalization of nicks (removing trailing underscores and single
    # digits from automatic nick renames for dupe connections)

    my $res = $self->config->db->do(q{
        select id, nick, can_grant
        from nicks
        where lower(nick) = lower(?)
    }, $self->nick);

    if ($res && $res->next) {
        $self->id($res->{'id'});
    } else {
        $res = $self->config->db->do(q{
            insert into nicks ??? returning id
        }, { nick => $self->nick });

        if ($res && $res->next) {
            $self->id($res->{'id'});
        }
    }
}

sub add_alt {
    my ($self, $nick) = @_;

    # TODO this add_alt method (need corresponding schema)
}

sub remove_alt {
    my ($self, $nick) = @_;

    # TODO this remove_alt method (and corresponding schema)
}

__PACKAGE__->meta->make_immutable;

1;
