package RoboBot::Plugin::Bot;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Bot',
);

has '+description' => (
    default => 'Exports functions returning information about the bot and its environment.',
);

has '+commands' => (
    default => sub {{
        'version' => { method      => 'version',
                       description => 'Returns a string with the bot\'s version number.',
                       usage       => '' },

        'channel-list' => { method      => 'channels',
                            description => 'Returns a list of the channels on this network which the bot has joined.',
                            usage       => '' },

        'network-list' => { method      => 'networks',
                            description => 'Returns a list of the networks to which the bot is currently connected.',
                            usage       => '' },
    }},
);

sub channels {
    my ($self, $message) = @_;

    my $network = $self->bot->irc->{'alias'};

    unless (exists $self->bot->config->networks->{$network}) {
        $message->response->raise('I somehow cannot determine what network I am connected to right now.');
        return;
    }

    return join(', ', sort { lc($a) cmp lc($b) } map { '#' . $_->channel } @{$self->bot->config->networks->{$network}->channels});
}

sub networks {
    my ($self, $message) = @_;

    return join(', ', sort { lc($a) cmp lc($b) } keys %{$self->bot->config->networks});
}

sub version {
    my ($self, $message) = @_;

    return $self->bot->version;
}

__PACKAGE__->meta->make_immutable;

1;
