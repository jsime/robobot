package RoboBot::Network::IRC;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use AnyEvent;
use AnyEvent::IRC::Client;
use Data::Dumper;
use Time::HiRes qw( usleep );

use RoboBot::Channel;
use RoboBot::Message;
use RoboBot::Nick;

extends 'RoboBot::Network';

has '+type' => (
    default => 'irc',
);

has 'host' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'port' => (
    is      => 'ro',
    isa     => 'Int',
    default => 6667,
);

has 'ssl' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

has 'username' => (
    is  => 'ro',
    isa => 'Str',
);

has 'password' => (
    is  => 'ro',
    isa => 'Str',
);

has 'client' => (
    is      => 'ro',
    isa     => 'AnyEvent::IRC::Client',
    default => sub { AnyEvent::IRC::Client->new },
);

has 'nick_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    $self->client->enable_ssl() if $self->ssl;
}

sub connect {
    my ($self) = @_;

    $self->client->reg_cb( registered => sub {
        my ($con) = @_;

        $self->client->enable_ping(30, sub {});
    });

    $self->client->reg_cb( publicmsg => sub {
        my ($con, $chan, $msg_h) = @_;
        $self->handle_message($msg_h);
    });

    $self->client->reg_cb( privatemsg => sub {
        my ($con, $sender, $msg_h) = @_;
        $self->handle_message($msg_h);
    });

    $self->client->connect($self->host, $self->port, { nick => $self->nick->name });
    $_->join for @{$self->channels};
}

sub disconnect {
    # TODO: remove callbacks
    #       call client->disconnect
}

sub send {
    my ($self, $response) = @_;

    my @output;

    # TODO: Move maximum number of output lines into a config var for each IRC
    #       network (with a default).

    if ($response->num_lines > 10) {
        my $n = $response->num_lines;
        @output = (
            @{$response->content}[0..3],
            '... Output Truncated (' . ($n - 7) . ' lines removed) ...',
            @{$response->content}[($n-3)..($n-1)]
        );
    } else {
        @output = @{$response->content};
    }

    my $recipient = $response->has_channel ? '#' . $response->channel->name : $response->nick->name;

    my $d = 0;
    for (my $i = 0; $i <= $#output; $i++) {
        my $line = $output[$i];

        $self->client->send_srv( PRIVMSG => $recipient, $line);

        # TODO: Move send rate to a config var which can be overridden per
        #       network.

        # Ignorant and ineffective flood "protection" will gradually slow down
        # message sending the more lines there are to deliver, unless we've just
        # sent the last line.
        $d += 25_000 * log($i+1); # will cause a 10 line response to take about 2 seconds in total to send
        usleep($d) unless $i == $#output;
    }

    # Clear content that has been sent. Error conditions/messages are left intact
    # if present, so that we can continue to send other output, while still short
    # circuiting any further list processing.
    $response->clear_content;

    return;
}

sub handle_message {
    my ($self, $msg) = @_;

    my $message;

    if ($msg->{'command'} eq 'PRIVMSG') {
        # TODO  Make sure we're handling non-nicked messages (if any) properly
        #       instead of just short-circuiting here).
        return unless exists $msg->{'prefix'} && $msg->{'prefix'} =~ m{\w+!.+}o;

        my $channel = undef;
        if (substr($msg->{'params'}->[0], 0, 1) eq '#') {
            $channel = (grep { '#' . $_->name eq $msg->{'params'}->[0] } @{$self->channels})[0];
            # TODO log messages that came from channels we don't know we're on?
            return unless defined $channel;
        }

        my $message = RoboBot::Message->new(
            bot     => $self->bot,
            raw     => $msg->{'params'}->[1],
            network => $self,
            sender  => $self->resolve_nick($msg->{'prefix'}),
            channel => $channel,
        );

        $message->process;
    }
}

sub join_channel {
    my ($self, $channel) = @_;

    $self->client->send_srv( JOIN => '#' . $channel->name );
}

sub resolve_nick {
    my ($self, $prefix) = @_;

    my $username = (split(/!/, $prefix))[0];

    return $self->nick_cache->{$username} if exists $self->nick_cache->{$username};

    my $res = $self->config->db->do(q{ select id, name from nicks where lower(name) = lower(?) }, $username);

    if ($res && $res->next) {
        $self->nick_cache->{$username} = RoboBot::Nick->new(
            id     => $res->{'id'},
            name   => $res->{'name'},
            config => $self->config,
        );

        return $self->nick_cache->{$username};
    }

    $res = $self->config->db->do(q{
        insert into nicks ??? returning id, name
    }, { name => $username });

    if ($res && $res->next) {
        $self->nick_cache->{$username} = RoboBot::Nick->new(
            id     => $res->{'id'},
            name   => $res->{'name'},
            config => $self->config,
        );

        return $self->nick_cache->{$username};
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
