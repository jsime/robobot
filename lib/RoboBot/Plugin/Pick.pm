package RoboBot::Plugin::Pick;

use strict;
use warnings;

sub commands { qw( pick ) }
sub usage { "choice1, choice2, ..., choiceN" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my %choice_map = map { lc($_) => $_ } grep { $_ =~ m{\S+} } split(/\s*,\s*/, $message);
    my @choices = values %choice_map;

    return unless scalar(@choices) > 0;

    my $choice = $choices[int(rand(scalar(@choices)))];

    return sprintf('%s: I cannot make up my mind.', $sender) unless $choice =~ m{\S+};

    $choice =~ s{(^\s+|\s+$)}{}ogs;

    return sprintf('%s: %s', $sender, $choice);
}

1;
