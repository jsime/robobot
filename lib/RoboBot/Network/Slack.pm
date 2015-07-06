package RoboBot::Network::Slack;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use AnyEvent;
use AnyEvent::SlackRTM;

use Data::Dumper;
use JSON;
use LWP::Simple;

use RoboBot::Channel;
use RoboBot::Nick;

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

has 'start_ts' => (
    is      => 'ro',
    isa     => 'Int',
    default => sub { time() },
);

has 'profile_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'channel_cache' => (
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
        $self->keepalive(AnyEvent->timer(
            interval => 60,
            cb       => sub { $self->reconnect if $self->client->finished }
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
    my ($self) = @_;

    $self->client->close;
}

sub reconnect {
    my ($self) = @_;

    $self->client->disconnect && $self->client->connect;
}

sub send {
    my ($self, $response) = @_;

    unless ($response->has_channel) {
        printf STDERR "!!!! Cannot send direct messages via SlackRTM network. (At least not yet.) Response dropped.\n";
        $response->clear_content;
        return;
    }

    unless (exists $response->channel->extradata->{'slack_id'}) {
        printf STDERR "!!!! Channel target for response does not have a Slack ID. Cannot send message.\n";
        $response->clear_content;
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
        channel => $response->channel->extradata->{'slack_id'},
        type    => 'message',
        text    => $output,
    });

    $response->clear_content;

    return;
}

sub handle_message {
    my ($self, $msg) = @_;

    # TODO: Ignore messages that are delivered very shortly after connection
    #       (since this can lead to repetition of processing and output when
    #       the bot disconnects and reconnects).
    return if exists $msg->{'ts'} && int($msg->{'ts'}) <= $self->start_ts + 5;

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

    my $message = RoboBot::Message->new(
        bot     => $self->bot,
        raw     => ($msg->{'text'} || ''),
        network => $self,
        sender  => $self->resolve_nick($msg->{'user'}),
        channel => $self->resolve_channel($msg->{'channel'}),
    );

    $message->process;
}

sub resolve_channel {
    my ($self, $slack_id) = @_;

    return $self->channel_cache->{$slack_id} if exists $self->channel_cache->{$slack_id};

    my $channel;

    my $res = $self->bot->config->db->do(q{
        select id, name, extradata
        from channels
        where network_id = ? and extradata @> ?
    }, $self->id, encode_json({ slack_id => $slack_id }));

    if ($res && $res->next) {
        $channel = RoboBot::Channel->new(
            id          => $res->{'id'},
            name        => $res->{'name'},
            extradata   => decode_json($res->{'extradata'}),
            network     => $self,
            config      => $self->bot->config,
        );

        $self->channel_cache->{$slack_id} = $channel;
        return $channel;
    }

    my $json;

    # Slack has different API endpooints for channels and private groups, so
    # make sure we're using the right one based on the first character of the
    # identifier.
    if (substr($slack_id, 0, 1) eq 'C') {
        $json = get('https://slack.com/api/channels.info?token=' . $self->token . '&channel=' . $slack_id);
    } elsif (substr($slack_id, 0, 1) eq 'G') {
        $json = get('https://slack.com/api/groups.info?token=' . $self->token . '&channel=' . $slack_id);
    } else {
        # Not a group or a channel, bail out.
        return;
    }

    return unless defined $json;

    my $chandata = decode_json($json);
    return unless defined $chandata && ref($chandata) eq 'HASH' && exists $chandata->{'ok'} && $chandata->{'ok'};

    $res = $self->bot->config->db->do(q{
        select id, name, extradata
        from channels
        where network_id = ? and lower(name) = lower(?)
    }, $self->id, ($chandata->{'group'}{'name'} || $chandata->{'channel'}{'name'}));

    if ($res && $res->next) {
        $res->{'extradata'} = decode_json($res->{'extradata'});
        $res->{'extradata'}{'slack_id'} = $slack_id;

        $self->bot->config->db->do(q{
            update channels
            set extradata = ?,
                updated_at = now() where id = ?
        }, encode_json($res->{'extradata'}), $res->{'id'});

        $channel = RoboBot::Channel->new(
            id          => $res->{'id'},
            name        => $res->{'name'},
            extradata   => $res->{'extradata'},
            network     => $self,
            config      => $self->bot->config,
        );

        $self->channel_cache->{$slack_id} = $channel;
        return $channel;
    }

    $res = $self->bot->config->db->do(q{
        insert into channels ??? returning id, name, extradata
    }, { name       => ($chandata->{'group'}{'name'} || $chandata->{'channel'}{'name'}),
         network_id => $self->id,
         extradata  => encode_json({ slack_id => $slack_id }),
    });

    if ($res && $res->next) {
        $channel = RoboBot::Channel->new(
            id          => $res->{'id'},
            name        => $res->{'name'},
            extradata   => decode_json($res->{'extradata'}),
            network     => $self,
            config      => $self->bot->config,
        );

        $self->channel_cache->{$slack_id} = $channel;
        return $channel;
    }

    return;
}

sub resolve_nick {
    my ($self, $slack_id) = @_;

    # User profile already in our cache (we've seen or created it during this
    # session, so simply return what we have.
    return $self->profile_cache->{$slack_id} if exists $self->profile_cache->{$slack_id};

    # Check database for a nick with this Slack ID. If found, instantiate a new
    # RoboBot::Nick object with the data, cache it, and return.
    my $nick;

    my $res = $self->bot->config->db->do(q{
        select id, name, extradata
        from nicks where extradata @> ?
    }, encode_json({ slack_id => $slack_id }));

    if ($res && $res->next) {
        $nick = RoboBot::Nick->new(
            id        => $res->{'id'},
            name      => $res->{'name'},
            extradata => decode_json($res->{'extradata'}),
            network   => $self,
            config    => $self->config,
        );

        $self->profile_cache->{$slack_id} = $nick;
        return $nick;
    }

    # We haven't encountered this nick before, so we need to query the SlackAPI
    # for their handle and other profile details.
    my $json = get('https://slack.com/api/users.info?token=' . $self->token . '&user=' . $slack_id);
    return unless defined $json;

    my $userdata = decode_json($json);
    return unless defined $userdata && ref($userdata) eq 'HASH' && exists $userdata->{'ok'} && $userdata->{'ok'};

    # Now that we know their handle, we can see if we already have a record for
    # that. If so, we update it to include their Slack ID, drop it in our cache,
    # and return the nick object.
    $res = $self->bot->config->db->do(q{
        select id, name, extradata
        from nicks
        where lower(name) = lower(?)
    }, $userdata->{'user'}{'name'});

    if ($res && $res->next) {
        $res->{'extradata'} = decode_json($res->{'extradata'});
        $res->{'extradata'}{'slack_id'} = $slack_id;
        $res->{'extradata'}{'full_name'} = $userdata->{'user'}{'profile'}{'real_name'} if exists $userdata->{'user'}{'profile'}{'real_name'};

        $self->bot->config->db->do(q{
            update nicks
            set extradata = ?,
                updated_at = now()
            where id = ?
        }, encode_json($res->{'extradata'}), $res->{'id'});

        $nick = RoboBot::Nick->new(
            id        => $res->{'id'},
            name      => $res->{'name'},
            extradata => $res->{'extradata'},
            network   => $self,
            config    => $self->bot->config,
        );

        $self->profile_cache->{$slack_id} = $nick;
        return $nick;
    }

    # And finally, we've had no luck finding any matches, so we assume that the
    # nick is totally new to us. Create a new record, cache that, and return.
    my $extra = { slack_id => $slack_id };
    $extra->{'full_name'} = $userdata->{'user'}{'profile'}{'real_name'} if exists $userdata->{'user'}{'profile'}{'real_name'};

    $res = $self->bot->config->db->do(q{
        insert into nicks ??? returning id, name, extradata
    }, { name      => $userdata->{'user'}{'name'},
         extradata => encode_json($extra),
    });

    if ($res && $res->next) {
        $nick = RoboBot::Nick->new(
            id        => $res->{'id'},
            name      => $res->{'name'},
            extradata => decode_json($res->{'extradata'}),
            network   => $self,
            config    => $self->bot->config,
        );

        $self->profile_cache->{$slack_id} = $nick;
        return $nick;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
