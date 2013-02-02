package RoboBot::Plugin::Ping;

use strict;
use warnings;

use Net::Ping;
use Time::HiRes qw( gettimeofday tv_interval );

sub commands { qw( ping ) }
sub usage { "[hostname|ip]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return "pong!" unless $message;

    $message =~ s{(^\s+|\s+$)}{}ogs;

    my $p = Net::Ping->new('udp');

    my $t0 = [gettimeofday];
    my $r = $p->ping($message);
    my $t1 = [gettimeofday];

    $p->close();

    return sprintf('%s responded in %.2fms.', $message, tv_interval($t0, $t1)*1000) if $r;
    return sprintf('%s is NOT responding.', $message);
}

1;
