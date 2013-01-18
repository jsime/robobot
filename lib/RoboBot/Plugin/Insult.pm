package RoboBot::Plugin::Insult;

use strict;
use warnings;

use Acme::Scurvy::Whoreson::BilgeRat;

sub commands { qw( insult ) }
sub usage { "" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my @salutations = (
        "You \%s!",
        "You're such a \%s!",
        "What a \%s ...",
        "Pipe down, you \%s!",
        "Stop being such a \%s!",
        "Well aren't you being a real \%s!",
        "Never did I think I would live to see such a \%s.",
        "Why if it isn't the \%s.",
        "I should have known a \%s like you could be found here!",
    );

    my $insult = Acme::Scurvy::Whoreson::BilgeRat->new( language => 'pirate' );

    return sprintf($salutations[int(rand(scalar(@salutations)))], $insult);
}

1;
