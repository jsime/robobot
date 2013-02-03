package RoboBot::Plugin::Fortune;

use strict;
use warnings;

sub commands { qw( fortune ) }
sub usage { "[ files | <file>]" }

my $fortune_bin = '/usr/games/fortune';
my @fortune_files = qw(
    computers cookie definitions disclaimer drugs education food fortunes
    humorists kids law linuxcookie linux literature love medicine
    miscellaneous news paradoxum people perl pets platitudes riddles
    science startrek wisdom work zippy
);

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    $message =~ s{(^\s+|\s+$)}{}ogs;

    my $files;

    if ($message =~ m{\w+}o) {
        if (lc($message) eq 'files') {
            return sprintf('The following fortune files are available: %s', join(', ', @fortune_files));
        }

        if (grep { $_ eq $message } @fortune_files) {
            $files = $message;
        } else {
            return sprintf('Unknown fortune file: %s', $message);
        }
    } else {
        $files = join(' ', @fortune_files);
    }

    my $fortune = `$fortune_bin -n 180 -s $files`;

    return unless $fortune && $fortune =~ m{\w+}o;

    $fortune =~ s{\s+}{ }ogs;
    $fortune =~ s{(^\s+|\s+$)}{}ogs;

    return $fortune;
}

1;
