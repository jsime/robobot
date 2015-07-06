package RoboBot::NetworkFactory;

use v5.20;

use namespace::autoclean;

use Moose;

use Module::Loaded;

use RoboBot::Nick;
use RoboBot::Network::IRC;
use RoboBot::Network::Slack;

has 'bot' => (
    is       => 'ro',
    isa      => 'RoboBot',
    required => 1,
);

has 'config' => (
    is       => 'ro',
    isa      => 'RoboBot::Config',
    required => 1,
);

has 'nick' => (
    is       => 'ro',
    isa      => 'RoboBot::Nick',
    required => 1,
);

sub create {
    my ($self, $name, $net_cfg) = @_;

    die 'Network name not provided.' unless defined $name && $name =~ m{^[a-z0-9_-]+$}oi;
    die 'Configuration invalid.' unless defined $net_cfg && ref($net_cfg) eq 'HASH';
    die 'Missing network type.' unless exists $net_cfg->{'type'};

    # Check for network-specific nick (and create object for it if present) or
    # fall back to the NetworkFactory default nick.
    if (exists $net_cfg->{'nick'}) {
        $net_cfg->{'nick'} = RoboBot::Nick->new(
            config => $self->config,
            name   => $net_cfg->{'nick'},
        );
    } else {
        $net_cfg->{'nick'} = $self->nick;
    }

    return $self->create_irc($name, $net_cfg) if $net_cfg->{'type'} eq 'irc';
    return $self->create_slack($name, $net_cfg) if $net_cfg->{'type'} eq 'slack';
    die 'Invalid network type.';
}

sub create_irc {
    my ($self, $name, $net_cfg) = @_;

#    eval 'use RoboBot::Network::IRC;' unless is_loaded('RoboBot::Network::IRC');

    return RoboBot::Network::IRC->new(
        %{$net_cfg},
        bot    => $self->bot,
        name   => $name,
        config => $self->config,
    );
}

sub create_slack {
    my ($self, $name, $net_cfg) = @_;

#    eval 'use RoboBot::Network::Slack;' unless is_loaded('RoboBot::Network::Slack');

    return RoboBot::Network::Slack->new(
        %{$net_cfg},
        bot    => $self->bot,
        name   => $name,
        config => $self->config,
    );
}

__PACKAGE__->meta->make_immutable;

1;
