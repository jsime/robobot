package RoboBot::Channel;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use JSON;

has 'id' => (
    is        => 'rw',
    isa       => 'Int',
    traits    => [qw( SetOnce )],
    predicate => 'has_id',
);

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    predicate => 'has_name' # TODO: this is pointless, but something is still calling it and that needs to be fixed
);

has 'extradata' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'network' => (
    is        => 'ro',
    isa       => 'RoboBot::Network',
    required  => 1,
    predicate => 'has_network' # TODO: this is pointless, but something is still calling it and that needs to be fixed
);

has 'config' => (
    is       => 'ro',
    isa      => 'RoboBot::Config',
    required => 1,
);

sub find_by_id {
    my ($class, $bot, $id) = @_;

    my $res = $bot->config->db->do(q{
        select c.id, c.name, c.extradata, n.name as network
        from channels c
            join networks n on (n.id = c.network_id)
        where c.id = ?
    }, $id);

    return unless $res && $res->next;

    return $class->new(
        id        => $res->{'id'},
        name      => $res->{'name'},
        extradata => decode_json($res->{'extradata'}),
        network   => (grep { $_->name eq $res->{'network'} } @{$bot->networks})[0],
        config    => $bot->config,
    );
}

sub BUILD {
    my ($self) = @_;

    unless ($self->has_id) {
        die "Invalid channel creation" unless $self->has_name && $self->has_network;

        my $res = $self->config->db->do(q{
            select id
            from channels
            where network_id = ? and lower(name) = lower(?)
        }, $self->network->id, $self->name);

        if ($res && $res->next) {
            $self->id($res->{'id'});
        } else {
            $res = $self->config->db->do(q{
                insert into channels ??? returning id
            }, { network_id => $self->network->id, name => $self->name });

            if ($res && $res->next) {
                $self->id($res->{'id'});
            }
        }

        die "Could not generate channel ID" unless $self->has_id;
    }
}

sub join {
    my ($self) = @_;

    $self->network->join_channel($self);
}

sub part {
    my ($self, $irc) = @_;

    # TODO switch to AnyEvent and perform part appropriate to network's type
}

__PACKAGE__->meta->make_immutable;

1;
