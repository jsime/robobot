package RoboBot::Plugin::Spellcheck;

use strict;
use warnings;

use Text::Aspell;

sub commands { qw( * ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    # never spell check input that included a command
    return -1 if $command && length($command) > 0;

    # we don't want to fire off too often, so just return right away some portion of the time
    return -1 if rand() >= 1;

    my $ts = Text::Aspell->new();
    return unless $ts;

    my @words = grep { length($_) >= 10 } split(/\s+/o, $message);

    my @new = ();
    my $misspelled = 0;

    foreach my $word (@words) {
        my $found = $ts->check($word);

        next if $found;

        if (defined $found) {
            my @suggestions = $ts->suggest($word);

            if (scalar(@suggestions) > 0) {
                push(@new, $suggestions[0]);
                $misspelled = 1;
            } else {
                return -1;
            }
        } else {
            # got an error checking a word, and it wasn't found, so we'll just skip this message
            return -1;
        }
    }

    @new = sort { length($b) <=> length($a) } @new;
    @new = @new[0..3] if scalar(@new) > 4;

    return -1 unless $misspelled;
    return sprintf('%s: %s', $sender, join(', ', map { "*$_" } @new)) unless rand() > 1;
    return -1;
}

1;
