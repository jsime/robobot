package RoboBot::Plugin::Fortune;

use strict;
use warnings;

sub commands { qw( fortune ) }
sub usage { "" }

my $fortune_bin = '/usr/games/fortune';
my $fortune_files = join(' ',qw(
    computers cookie definitions disclaimer drugs education food fortunes
    humorists kids law linuxcookie linux literature love medicine
    miscellaneous news paradoxum people perl pets platitudes riddles
    science startrek wisdom work zippy
));

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my $fortune = `$fortune_bin -n 180 -s $fortune_files`;

    return unless $fortune && $fortune =~ m{\w+}o;

    $fortune =~ s{\s+}{ }ogs;
    $fortune =~ s{(^\s+|\s+$)}{}ogs;

    return $fortune;
}

1;
