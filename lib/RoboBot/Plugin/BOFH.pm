package RoboBot::Plugin::BOFH;

use strict;
use warnings;

sub commands { qw( bofh ) }
sub usage { "" }

my $fortune_bin = '/usr/games/fortune';

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my $fortune = `$fortune_bin bofh-excuses`;

    return unless $fortune && $fortune =~ m{\w+}o;

    $fortune =~ s{\s+}{ }ogs;
    $fortune =~ s{(^\s+|\s+$)}{}ogs;

    return $fortune;
}

1;
