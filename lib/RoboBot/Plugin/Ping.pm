package RoboBot::Plugin::Ping;

use strict;
use warnings;

use Net::Ping;

sub commands { qw( ping ) }
sub usage { "[hostname|ip]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return "pong!" unless $message;

    my $p = Net::Ping->new('udp');
    my $r = $p->ping($message);
    $p->close();

    return sprintf('%s is responding.', $message) if $r;
    return sprintf('%s is NOT responding.', $message);
}

1;
