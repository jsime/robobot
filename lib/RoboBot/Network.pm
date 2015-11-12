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
    is      => 'rw',
    isa     => 'ArrayRef[RoboBot::Channel]',
    default => sub { [] },
);

has 'passive' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has 'disabled_plugins' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub BUILD {
    my ($self, $args) = @_;

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

    # downcase all disabled plugin names for easier matching during message processing
    if (scalar(keys(%{$self->disabled_plugins})) > 0) {
        $self->disabled_plugins({
            map { lc($_) => 1 }
            grep { $self->disabled_plugins->{$_} =~ m{(yes|on|true|1|disabled)}i }
            keys %{$self->disabled_plugins}
        });
    }
}

__PACKAGE__->meta->make_immutable;

1;
