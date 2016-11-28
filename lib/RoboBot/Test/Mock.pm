package RoboBot::Test::Mock;

use RoboBot;

use RoboBot::Channel;
use RoboBot::Message;
use RoboBot::NetworkFactory;
use RoboBot::Nick;

use Exporter::Easy (
    'EXPORT' => [ 'mock_all' ],
    'OK'     => [ 'mock_bot', 'mock_channel', 'mock_message', 'mock_network' ],
);

our %config = (
    global => {
        nick => 'robobot',
    },
    database => {
        cache_connections => 0,
        cache_statements  => 0,
        primary => {
            driver      => 'Pg',
            database    => ($ENV{'R_DBNAME'} // 'robobot_test'),
            host        => ($ENV{'R_DBHOST'} // 'localhost' ),
            port        => ($ENV{'R_DBPORT'} // '5432'),
            user        => ($ENV{'R_DBUSER'} // 'robobot'),
            schemas     => ["robobot","public"],
        },
    },
    network => {
        "test-net" => {
            type    => "irc",
            enabled => 0,
            host    => "localhost",
            port    => "6667",
            channel => ["test-channel"],
        },
    },
);

sub envset_message {
    my $msg = "R_DBTEST not set.";
    my @vars = grep { ! exists $ENV{'R_DB'.$_} } qw( HOST PORT NAME USER );
    $msg .= ' (Use R_DB{' . join(',', @vars) . '} to override connection info.)' if @vars > 0;
    return $msg;
}

sub mock_all {
    my ($text) = @_;

    die "must provide message text to use for mock message" unless defined $text && $text =~ m{\w+};

    my $bot = mock_bot();
    die "could not mock bot object" unless defined $bot && ref($bot) eq 'RoboBot';

    my $net = mock_network($bot);
    die "could not mock network object" unless defined $net && ref($net) =~ m{^RoboBot::Network};

    my $chn = mock_channel($bot, $net);
    die "could not mock channel object" unless defined $chn && ref($chn) eq 'RoboBot::Channel';

    my $msg = mock_message($bot, $chn, $text);
    die "could not mock message object" unless defined $msg && ref($msg) eq 'RoboBot::Message';

    return ($bot, $net, $chn, $msg);
}

sub mock_bot {
    my $bot = RoboBot->new( raw_config => \%config );
    my $cfg = RoboBot::Config->new( bot => $bot, config => \%config );

    die "could not mock bot" unless defined $bot;

    return $bot;
}

sub mock_channel {
    my ($bot, $network) = @_;

    die "must provide network for channel mockup" unless defined $network;

    my $channel = RoboBot::Channel->new(
        network => $network,
        name    => $config{'network'}{'test-net'}{'channel'}[0],
        config  => $bot->config,
    );

    die "could not mock channel" unless defined $channel;

    return $channel;
}

sub mock_message {
    my ($bot, $channel, $text);

    my $sender = RoboBot::Nick->new(
        name    => 'mockuser',
        network => $channel->network,
        config  => $bot->config,
    );

    my $message = RoboBot::Message->new(
        bot     => $bot,
        network => $channel->network,
        channel => $channel,
        sender  => $sender,
        raw     => $text,
    );

    return $message;
}

sub mock_network {
    my ($bot) = @_;

    my $factory = RoboBot::NetworkFactory->new(
        bot    => $bot,
        config => $bot->config,
        nick   => RoboBot::Nick->new( name => $config{'global'}{'nick'}, config => $bot->config ),
    );

    my $network = $factory->create(
        'test-net',
        $config{'network'}{'test-net'},
    );

    return $network;
}

1;
