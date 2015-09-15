package RoboBot::Plugin::Bot;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

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
                            description => 'By default, returns a list of the channels on this network which the bot has joined. If provided a network name, will return the list of channels joined by the bot on that network. Refer to (network-list) for the list of network names.',
                            usage       => '[<network>]' },

        'network-list' => { method      => 'networks',
                            description => 'Returns a list of the networks to which the bot is currently connected.',
                            usage       => '' },
    }},
);

sub channels {
    my ($self, $message, $command, $pattern) = @_;

    my $network = $message->network;

    if (defined $pattern) {
        $network = (grep { $_->name =~ m{$pattern}i } @{$self->bot->networks})[0];
        unless (defined $network) {
            $message->response->raise('Could not find a network which matches the pattern %s. Please check (network-list).', $pattern);
            return;
        }
    }

    return join(', ', sort { lc($a) cmp lc($b) } map { '#' . $_->name } @{$network->channels});
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
