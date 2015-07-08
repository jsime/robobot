package RoboBot::Network;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

has 'type' => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

has 'id' => (
    is     => 'rw',
    isa    => 'Num',
    traits => [qw( SetOnce )],
);

has 'config' => (
    is       => 'ro',
    isa      => 'RoboBot::Config',
    required => 1,
);

has 'bot' => (
    is       => 'ro',
    isa      => 'RoboBot',
    required => 1,
);

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'nick' => (
    is       => 'ro',
    isa      => 'RoboBot::Nick',
    required => 1,
);

has 'channels' => (
    is  => 'rw',
    isa => 'ArrayRef[RoboBot::Channel]',
);

sub BUILD {
    my ($self) = @_;

    my $res = $self->config->db->do(q{
        select id, name
        from networks
        where lower(name) = lower(?)
    }, $self->name);

    if ($res && $res->next) {
        $self->id($res->{'id'});
    } else {
        $res = $self->config->db->do(q{
            insert into networks ??? returning id
        }, { name => $self->name });

        if ($res && $res->next) {
            $self->id($res->{'id'});
        } else {
            die "Could not generate a new network ID.";
        }
    }

}

__PACKAGE__->meta->make_immutable;

1;
