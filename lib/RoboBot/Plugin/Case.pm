package RoboBot::Plugin::Case;

use strict;
use warnings;

use utf8;

sub commands { qw( lc uc ) }
sub usage { "<text>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return lc($message) if lc($command) eq 'lc';
    return uc($message) if lc($command) eq 'uc';

    return;
}

1;
