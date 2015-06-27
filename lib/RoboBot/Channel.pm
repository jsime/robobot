package RoboBot::Channel;

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

# TODO: change this attribute to 'name' instead
has 'channel' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'network' => (
    is       => 'ro',
    isa      => 'RoboBot::Network',
    required => 1,
);

sub BUILD {
    my ($self) = @_;

    my $res = $self->config->db->do(q{
        select id, server_id, name
        from channels
        where '#' || lower(name) = '#' || lower(?) and server_id = ?
    }, $self->channel, $self->network->id);

    if ($res && $res->next) {
        $self->id($res->{'id'});
    } else {
        $res = $self->config->db->do(q{
            insert into channels ??? returning id
        }, { name => $self->channel, server_id => $self->network->id });

        if ($res && $res->next) {
            $self->id($res->{'id'});
        } else {
            # TODO
        }
    }
}

sub join {
    my ($self) = @_;

    $self->network->join_channel($self);
}

sub part {
    my ($self, $irc) = @_;

    # TODO switch to AnyEvent and perform part appropriate to network's type
    $irc->yield( part => '#' . $self->channel );
}

__PACKAGE__->meta->make_immutable;

1;
