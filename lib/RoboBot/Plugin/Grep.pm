package RoboBot::Plugin::Grep;

use strict;
use warnings;

sub commands { qw( grep ) }
sub usage { '/<pattern>/ <message>' }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    my @lines = split(/\n/, $message);
    my @ret;

    return unless defined $lines[0] && $lines[0] =~ m|^\s*m?/([^/]+)/ (.+)$|;
    my $pattern = qr/$1/;
    $lines[0] = $2;

    foreach my $line (@lines) {
        push(@ret, $line) if $line =~ $pattern;
    }

    return @ret;
}

1;
