package RoboBot;

use v5.16;
use strict;
use warnings;

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

use Data::Dumper;
use Module::Pluggable::Object;
use POE;
use POE::Component::IRC;

use RoboBot::Config;
use RoboBot::Message;
use RoboBot::Plugin;

our $VERSION = '1.001001';

has 'config' => (
    is     => 'rw',
    isa    => 'RoboBot::Config',
    traits => [qw( SetOnce )],
);

has 'plugins' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has 'commands' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'before_hooks' => (
    is        => 'rw',
    isa       => 'ArrayRef',
    predicate => 'run_before_hooks',
    default   => sub { [] },
);

has 'after_hooks' => (
    is        => 'rw',
    isa       => 'ArrayRef',
    predicate => 'run_after_hooks',
    default   => sub { [] },
);

has 'irc' => (
    is  => 'rw',
    isa => 'Object',
);

sub BUILD {
    my ($self) = @_;

    $self->config(RoboBot::Config->new())->load_config;

    # Gather list of supported plugin commands (naming conflicts are considered
    # warnable offenses, not fatal errors).
    my $finder = Module::Pluggable::Object->new( search_path => 'RoboBot::Plugin', instantiate => 'new' );

    foreach my $plugin ($finder->plugins) {
        push(@{$self->plugins}, $plugin);
        $plugin->bot($self);

        foreach my $command (keys %{$plugin->commands}) {
            warn sprintf("Command name collision: %s::%s superseded by %s::%s",
                         $self->commands->{$command}->name, $command, $plugin->name, $command)
                if exists $self->commands->{$command};

            # Offer both plain and namespaced access to individual functions
            $self->commands->{$command} = $plugin;
            $self->commands->{sprintf('%s::%s', lc($plugin->name), $command)} = $plugin;
        }

        # Gather list of plugins which have before/after hooks.
        push(@{$self->before_hooks}, $plugin) if $plugin->has_before_hook;
        push(@{$self->after_hooks}, $plugin) if $plugin->has_after_hook;
    }

    $self->irc(POE::Component::IRC->spawn());

    POE::Session->create(
        object_states => [
            $self => {
                _start      => "on_start",
                irc_001     => "on_connect",
                irc_msg     => "on_message",
                irc_public  => "on_message",
                irc_join    => "notice_join",
                irc_kick    => "notice_kick",
                irc_nick    => "notice_nick",
                irc_part    => "notice_part",
            }
        ],
        options => { trace => 0, debug => 0 },
    );
}

sub run {
    my ($self) = @_;

    $poe_kernel->run();
}

sub on_start {
    my ($self) = $_[OBJECT];

    $self->irc->yield( register => 'all' );

    foreach my $network (values %{$self->config->networks}) {
        $self->irc->yield(
            connect => {
                alias    => $network->name,
                Nick     => $network->nick->nick,
                Username => $network->username,
                Ircname  => "RoboBot (POE::Component::IRC) Bot v$VERSION",
                Server   => $network->host,
                Port     => $network->port,
                UseSSL   => $network->ssl || 0,
                Flood    => 0,
            }
        );
    }
}

sub on_connect {
    my ($self) = $_[OBJECT];

    my $network = $self->config->networks->{$self->irc->{'alias'}};

    if ($network->username && $network->password) {
        $self->irc->yield(
            privmsg => 'userserv',
            sprintf('login %s %s', $network->username, $network->password)
        );
    }

    $_->join($self->irc) for @{$network->channels};
}

sub on_message {
    my ($self, $kernel, $who, $where, $msg) = @_[OBJECT, KERNEL, ARG0, ARG1, ARG2];

    my $network = $self->config->networks->{$self->irc->{'alias'}};
    my $channel = $where->[0] =~ m{^#+(\S+)}o
        ? (grep { $1 eq $_->channel } @{$network->channels})[0]
        : undef;

    my $sender_nick = RoboBot::Nick->new( config => $self->config, nick => (split(/!/, $who))[0] );

    my $message = RoboBot::Message->new(
        bot     => $self,
        raw     => $msg,
        sender  => $sender_nick,
        network => $network,
        channel => $channel,
    );

    # Process any before-hooks on incoming messages
    if ($self->run_before_hooks) {
        foreach my $plugin (@{$self->before_hooks}) {
            $plugin->hook_before($message);
        }
    }

    # Process the message itself
    if ($message->has_expression) {
        my (@r);

        foreach my $expr (@{$message->expression}) {
            @r = $self->process_list($message, $expr);
        }

        if (@r && scalar(@r) > 0) {
            $self->commands->{'print'}->process($message, 'print', @r);
        }
    }

    # Process any after-hooks on the outgoing response
    if ($self->run_after_hooks) {
        foreach my $plugin (@{$self->after_hooks}) {
            $plugin->hook_after($message);
        }
    }

    # Deliver the response
    $message->response->send;
}

sub notice_join {
}

sub notice_part {
}

sub notice_kick {
}

sub notice_nick {
}

sub process_list {
    my ($self, $message, $list) = @_;

    return $list unless ref($list) eq 'ARRAY';

    my $command = lc(scalar($list->[0]));

    if (exists $self->commands->{$command}) {
        # If first element is a recognized command, pass list to appropriate plugin
        return $self->commands->{$command}->process(
            $message,
            $command,
            @{$list}[1..$#$list]
        );
    } else {
        # Otherwise, just process any sub expressions in the order they appear,
        # then return the processed list
        my @r;
        foreach my $el (@{$list}) {
            if (ref($el) eq 'ARRAY') {
                push(@r, $self->process_list($message, $el));
            } else {
                if (exists $message->vars->{$el}) {
                    if (ref($message->vars->{$el}) eq 'ARRAY') {
                        push(@r, $self->process_list($message, $message->vars->{$el}));
                    } else {
                        push(@r, $message->vars->{$el});
                    }
                } else {
                    push(@r, $el);
                }
            }
        }
        return @r;
    }
}

sub version {
    my ($self) = @_;

    return $VERSION;
}

__PACKAGE__->meta->make_immutable;

1;
