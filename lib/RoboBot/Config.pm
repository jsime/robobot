package RoboBot::Config;

use strict;
use warnings;

use File::HomeDir;
use Storable qw( freeze thaw );
use YAML qw( LoadFile );

sub new {
    my ($class, %args) = @_;

    my $self = {};

    if ($args{'path'}) {
        die "Invalid configuration file path provided: $args{'path'}" unless -f $args{'path'};

        $self->{'config_path'} = $args{'path'};
    } else {
        my $home = File::HomeDir->my_home();

        foreach my $path (("$home/.robobot.conf", "$home/.robobot/robobot.conf", "/etc/robobot.conf")) {
            if (-e $path) {
                $self->{'config_path'} = $path;
                last;
            }
        }
    }

    die "Could not locate a configuration file!\n" unless $self->{'config_path'};

    my $yaml = LoadFile($self->{'config_path'});

    $self->{'servers'} = {};

    $self->{'servers'}->{$_} = _server_config($_, $yaml->{'global'} || {}, $yaml->{$_})
        for grep { $_ ne 'global' } keys %{$yaml};

    my $obj = bless $self, $class;

    $obj->server($args{'server'}) if $args{'server'};

    return $obj;
}

sub servers {
    my ($self) = @_;

    return sort keys %{$self->{'servers'}};
}

sub server {
    my ($self, $server) = @_;

    if ($server) {
        die "Invalid server: $server" if !exists $self->{'servers'}->{$server};

        $self->{'server'} = $server;
    }

    return $self->{'server'};
}

sub host {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'host'};
}

sub port {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'port'};
}

sub ssl {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'ssl'} ? 1 : 0;
}

sub msgrate {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'msgrate'};
}

sub msglimit {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'msglimit'};
}

sub nick {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'nick'};
}

sub username {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'user'}
        ? $self->{'servers'}->{$self->server}->{'user'}
        : $self->nick();
}

sub password {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'pass'} if $self->{'servers'}->{$self->server}->{'pass'};
    return;
}

sub channels {
    my ($self) = @_;

    return @{$self->{'servers'}->{$self->server}->{'channels'}};
}

sub plugins {
    my ($self) = @_;

    return $self->{'servers'}->{$self->server}->{'plugins'};
}

sub _server_config {
    my ($name, $global, $server) = @_;

    my $config = {
        nick     => undef,
        host     => undef,
        port     => undef,
        ssl      => 0,
        user     => undef,
        pass     => undef,
        msgrate  => 10,
        msglimit => 10,
        channels => [],
        plugins  => {},
    };

    foreach my $k (qw( nick host port ssl user pass msgrate msglimit )) {
        $config->{$k} = $global->{$k} if $global->{$k};
        $config->{$k} = $server->{$k} if $server->{$k};
    }

    if ($global->{'channels'} && ref($global->{'channels'}) eq 'ARRAY') {
        foreach my $ch (@{$global->{'channels'}}) {
            $ch = _channel_name($ch);
            next if grep { lc($ch) eq $_ } @{$config->{'channels'}};
            push(@{$config->{'channels'}}, lc($ch));
        }
    }

    if ($server->{'channels'} && ref($server->{'channels'}) eq 'ARRAY') {
        foreach my $ch (@{$server->{'channels'}}) {
            $ch = _channel_name($ch);
            next if grep { lc($ch) eq $_ } @{$config->{'channels'}};
            push(@{$config->{'channels'}}, lc($ch));
        }
    }

    # Per-Plugin configurations -- using Storable's freeze/thaw for deep copies

    if ($global->{'plugins'} && ref($global->{'plugins'}) eq 'HASH') {
        foreach my $plugin (keys %{$global->{'plugins'}}) {
            my $plugin_cfg = freeze(%{$global->{'plugins'}{$plugin}});
            $config->{'plugins'}{$plugin} = { thaw($plugin_cfg) };
        }
    }

    if ($server->{'plugins'} && ref($server->{'plugins'}) eq 'HASH') {
        foreach my $plugin (keys %{$server->{'plugins'}}) {
            my $plugin_cfg = freeze($server->{'plugins'}{$plugin});
            $config->{'plugins'}{$plugin} = thaw($plugin_cfg);
        }
    }

    return $config;
}

sub _channel_name {
    my ($name) = @_;

    $name = '#' . $name unless $name =~ m{^\#}o;

    return $name;
}

1;
