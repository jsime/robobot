package RoboBot::Plugin::Topic;

use strict;
use warnings;

sub commands { qw( topic ) }
sub usage { "<topic message>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return undef unless $message =~ m{\w+}o;

    $message =~ s{\s+}{ }ogs;
    $message =~ s{(^\s+|\s+$)}{}ogs;

    $bot->{'irc'}->yield( topic => $channel, $message);

    return (-1);
}

1;
