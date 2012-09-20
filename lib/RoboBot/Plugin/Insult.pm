package RoboBot::Plugin::Insult;

use strict;
use warnings;

use Acme::Scurvy::Whoreson::BilgeRat;

sub commands { qw( insult ) }
sub usage { "<nick>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    $message = (split(/\s+/, $message))[0];
    $message =~ s{(^\s+|\s+$)}{}ogs; 

    my @salutations = ("You", "You're such a", "What a", "Pipe down, you", "Stop being such a",
        "Well aren't you being a real" );

    my $insult = Acme::Scurvy::Whoreson::BilgeRat->new( language => 'pirate' );

    return sprintf('%s: %s %s!', $message, $salutations[int(rand(scalar(@salutations)))], $insult);
}

1;
