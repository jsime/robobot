package RoboBot::Plugin::Echo;

use strict;
use warnings;

sub commands { qw( echo ) }
sub usage { "<text to be repeated back in-channel>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    return sprintf('%s, at %02d:%02d:%02d you said: %s',
        $sender, (localtime($timestamp))[2,1,0], $message);
}

1;
