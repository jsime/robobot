package RoboBot::Plugin::Roll;

use strict;
use warnings;

use Number::Format;

sub commands { qw( roll ) }
sub usage { "<int16>d<int16>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message =~ m{(\d+)d(\d+)}o;

    my $num = $1;
    my $die = $2;

    return unless $num > 0 && $num < 2**16;
    return unless $die > 0 && $die < 2**16;

    my $result = 0;

    $result += int(rand($die))+1 for (1..$num);

    my $frmt = Number::Format->new();

    return sprintf('%s %s of a %s-sided die gave %s.',
        $frmt->format_number($num, 0),
        $num == 1 ? 'roll' : 'rolls',
        $frmt->format_number($die, 0),
        $frmt->format_number($result, 0));
}

1;
