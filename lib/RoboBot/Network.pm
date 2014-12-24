package RoboBot::Network;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

has 'config' => (
    is       => 'ro',
    isa      => 'RoboBot::Config',
    required => 1,
);

has 'id' => (
    is     => 'rw',
    isa    => 'Num',
    traits => [qw( SetOnce )],
);

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'host' => (
    is  => 'ro',
    isa => 'Str',
);

has 'port' => (
    is  => 'ro',
    isa => 'Num',
);

has 'ssl' => (
    is  => 'ro',
    isa => 'Bool',
);

has 'username' => (
    is  => 'ro',
    isa => 'Str',
);

has 'password' => (
    is  => 'ro',
    isa => 'Str',
);

has 'nick' => (
    is  => 'ro',
    isa => 'RoboBot::Nick',
);

has 'channels' => (
    is  => 'rw',
    isa => 'ArrayRef[RoboBot::Channel]',
);

has 'connected' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub BUILD {
    my ($self) = @_;

    my $res = $self->config->db->do(q{
        select id, name
        from servers
        where lower(name) = lower(?)
    }, $self->name);

    if ($res && $res->next) {
        $self->id($res->{'id'});
    } else {
        $res = $self->config->db->do(q{
            insert into servers ??? returning id
        }, { name => $self->name });

        if ($res && $res->next) {
            $self->id($res->{'id'});
        } else {

        }
    }
}

sub connect {
    my ($self) = @_;
}

sub disconnect {
    my ($self) = @_;
}

sub add_channel {
    my ($self, $channel) = @_;
}

sub remove_channel {
    my ($self, $channel) = @_;
}

__PACKAGE__->meta->make_immutable;

1;
