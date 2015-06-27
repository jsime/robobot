package RoboBot::Network::Slack;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use AnyEvent;
use AnyEvent::SlackRTM;

use Data::Dumper;
use JSON;
use LWP::Simple;

extends 'RoboBot::Network';

has 'token' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'client' => (
    is     => 'rw',
    isa    => 'AnyEvent::SlackRTM',
    traits => [qw( SetOnce )],
);

has 'keepalive' => (
    is     => 'rw',
    traits => [qw( SetOnce )],
);

has 'ping_payload' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { { pong => 1 } },
);

has 'profile_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    $self->client(AnyEvent::SlackRTM->new(
        $self->token
    ));

    $self->client->on( 'hello' => sub {
        # TODO: EV is complaining about this I think, because the SlackRTM ping()
        #       method is pitting back undefined value errors on the message hash.
        $self->keepalive(AnyEvent->timer(
            interval => 60,
            cb       => sub { $self->client->ping($self->ping_payload); }
        ));
    });

    $self->client->on( 'message' => sub {
        my ($cl, $msg) = @_;
        $self->handle_message($msg);
    });
}

sub connect {
    my ($self) = @_;

    # Callbacks should be registered already in the BUILD method, so we just
    # need to start the client and have it connect to the Slack WebSocket API.
    $self->client->start;
}

sub disconnect {
    # TODO: remove callbacks
    #       call client->disconnect
}

sub send {
    my ($self, $response) = @_;

    unless ($response->has_channel) {
        printf STDERR "!!!! Cannot send direct messages via SlackRTM network. (At least not yet.) Response dropped.\n";
        return;
    }

    my $output = join(($response->collapsible ? ' ' : "\n"), @{$response->content});

    # For now, set an arbitrary limit on responses of 2K (SlackRTM says 16K,
    # which assuming absolute worst-case with wide characters would be 4K
    # glyphs, but even that seems really excesive for a chatbot).
    if (length($output) > 2048) {
        $output = substr($output, 0, 2048) .
            "\n\n... Output truncated ...";
    }

    $self->client->send({
        channel => $response->channel->channel,
        type    => 'message',
        text    => $output,
    });

    $response->clear_content;

    return;
}

sub handle_message {
    my ($self, $msg) = @_;

    # TODO: Ignore messages that are delivered immediately upon connection
    #       (since this can lead to repetition of processing and output when
    #       the bot disconnects and reconnects).

    # Short circuit if this isn't a 'message' type message.
    return unless defined $msg && ref($msg) eq 'HASH'
        && exists $msg->{'type'} && $msg->{'type'} eq 'message'
        && exists $msg->{'text'} && $msg->{'text'} =~ m{\w+};

    # Ignore messages which are hidden or have a subtype (these are generall
    # message edits or similar events).
    # TODO: Consider trapping message_edit subtypes and replacing log history?
    #       Most likely more work than it's worth, especially since it would
    #       require direct and special-snowflake interaction with a plugin.
    return if exists $msg->{'subtype'} && $msg->{'subtype'} =~ m{\w+};
    return if exists $msg->{'hidden'} && $msg->{'hidden'} == 1;

    # TODO: SlackRTM provides back channel IDs, not channel names. We need to convert
    #       (and cache the mappings for) these IDs to meaningful names. And the
    #       reverse mapping needs to be kept so that we can send responses back to
    #       the proper channel.
    my $channel = RoboBot::Channel->new( config => $self->config, network => $self, channel => $msg->{'channel'} );
    # TODO: Same exact deal with Users as with Channels - we only get an ID here.
    my $sender = RoboBot::Nick->new( config => $self->config, network => $self, slack_id => $msg->{'user'} );

    my $message = RoboBot::Message->new(
        bot     => $self->bot,
        raw     => ($msg->{'text'} || ''),
        network => $self,
        sender  => $sender,
        channel => $channel,
    );

    $message->process;
}

sub get_nick_data {
    my ($self, %args) = @_;

    # RoboBot::Nick couldn't find an existing nick record that matched, so we
    # need to look for a match in our cache or poll the SlackRTM API for the
    # user's name and handle.
    return $self->profile_cache->{$args{'slack_id'}} if exists $self->profile_cache->{$args{'slack_id'}};

    my $json = get('https://slack.com/api/users.info?token=' . $self->token . '&user=' . $args{'slack_id'});
    return unless defined $json;

    my $data = decode_json($json);

    return unless defined $data && ref($data) eq 'HASH' && exists $data->{'ok'} && $data->{'ok'};

    my %nick = (
        nick     => $data->{'user'}{'name'},
        slack_id => $data->{'user'}{'id'},
    );
    $nick{'full_name'} = $data->{'user'}{'profile'}{'real_name'} if exists $data->{'user'}{'profile'}{'real_name'} && $data->{'user'}{'profile'}{'real_name'} =~ m{\w+};

    $self->profile_cache->{$args{'slack_id'}} = \%nick;

    return %nick;
}

__PACKAGE__->meta->make_immutable;

1;
