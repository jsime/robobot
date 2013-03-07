package RoboBot::Plugin::Sub;

use utf8;
use 5.014;

use strict;
use warnings;

sub commands { qw( sub ) }
sub usage { "s/<pattern>/<replacement>/ [source]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my ($source);

    my $slash = "/\N{U+2044}\N{U+2215}\N{U+ff0f}";

    if ($message =~ m|^\s*s?[$slash](.*)(?<!\x{5c})[$slash](.*)(?<!\x{5c})[$slash]\s+(.*)|ou) {
        my $search = $1;
        my $replace = $2;
        $source = $3;

        eval {
            $source =~ s{$search}{$replace}igu;
        };
    } elsif ($message =~ m|^\s*s{(.*)(?<!\x{5c})}\s*{(.*)(?<!\x{5c})}\s+(.*)|ou) {
        my $search = $1;
        my $replace = $2;
        $source = $3;

        eval {
            $source =~ s{$search}{$replace}uigx;
        };
    } else {
        return;
    }

    return $source unless $@;
    return;
}

1;
