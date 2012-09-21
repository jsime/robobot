package RoboBot::Plugin::Say;

use strict;
use warnings;

sub commands { qw( say ) }
sub usage { "<message>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    return $message;
}

1;
