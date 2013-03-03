package RoboBot::Plugin::Sub;

use strict;
use warnings;

sub commands { qw( sub ) }
sub usage { "s/<pattern>/<replacement>/ [source]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message =~ m{^s?/(.*)(?<!\x{5c})/(.*)/\s+(.*)}o;

    my $search = $1;
    my $replace = $2;
    my $source = $3;

    eval {
        $source =~ s{$search}{$replace}ig;
    };

    return $source unless $@;
    return;
}

1;
