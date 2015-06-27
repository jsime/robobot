package RoboBot::Network;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

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
            die "Could not generate a new network ID.";
        }
    }

}

sub get_nick_data {
    my ($self, %args) = @_;

    # Does not cache and only returns nick data based on what it is given. This
    # method should be overridden by any protocol specific classes which can
    # actually do something meaningful about resolving unknown nicks.

    # Fail if neither of nick and full_name exist.
    return unless exists $args{'nick'} || exists $args{'full_name'};

    # Use the full name as the nick if the nick wasn't already present. Leave
    # any other keys intact.
    $args{'nick'} = $args{'full_name'} unless exists $args{'nick'};

    return %args;
}

__PACKAGE__->meta->make_immutable;

1;
