package RoboBot::Plugin::Oper;

use strict;
use warnings;

sub commands { qw( op deop ) }
sub usage { "[ <nick> ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command eq 'op') {
        return op_nick($bot, $channel, $message || $sender);
    } elsif ($command eq 'deop') {
        return deop_nick($bot, $channel, $message || $sender);
    }

    return (-1);
}

sub op_nick {
    my ($bot, $channel, $nick) = @_;

    return ('Invalid nick provided for op.') unless $nick =~ m{^[a-z0-9_-]+$}ois;

    $bot->{'irc'}->yield( mode => sprintf('%s +o %s', $channel, $nick));

    return (-1);
}

sub deop_nick {
    my ($bot, $channel, $nick) = @_;

    return ('Invalid nick provided for deop.') unless $nick =~ m{^[a-z0-9_-]+$}ois;

    $bot->{'irc'}->yield( mode => sprintf('%s -o %s', $channel, $nick));

    return (-1);
}

1;
