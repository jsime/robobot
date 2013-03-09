package RoboBot::Plugin::Spellcheck;

use strict;
use warnings;

use File::HomeDir;
use Text::Aspell;

sub commands { qw( * remember forget ) }
sub usage { "<word>[, <word>, ...]" }

my $aspell_word_file = File::HomeDir->my_home() . '/.aspell.en.pws';

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return remember_words($bot, $message) if $command && $command eq 'remember';
    return forget_words($bot, $message) if $command && $command eq 'forget';

    # never spell check input that included a command or is intended for NickBot
    return -1 if $command && length($command) > 0;
    return -1 if $message =~ m{^\s*!!}o;

    # we don't want to fire off too often, so just return right away some portion of the time
    return -1 if rand() >= 0.85;

    my $ts = Text::Aspell->new();
    return unless $ts;

    my @words = grep { length($_) >= 4 } split(/\s+/o, $message);

    my @new = ();
    my $misspelled = 0;

    foreach my $word (@words) {
        $word = clean_word($word);
        next unless $word;

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
    return sprintf('%s: %s', $sender, join(', ', map { "*$_" } @new)) unless rand() > 0.85;
    return -1;
}

sub clean_word {
    my ($word) = @_;

    return if $word =~ m{[0-9_@/:;~<>\{\}\[\[\\\]]}o;

    $word =~ s{(^[^a-zA-Z]+|[^a-zA-Z\.]+$)}{}ogs;
    $word =~ s{\.+$}{\.}ogs;
    $word =~ s{\.+$}{}ogs unless $word =~ m{\w+\.\w+}o;

    return $word;
}

sub forget_words {
    my ($bot, $message) = @_;

    $message =~ s{,}{ }ogs;
    my @words = map { clean_word($_) } grep { $_ =~ m{\w} } split(m{\s*(,|\s+)\s*}, $message);

    my @removed_words;
    my @saved_words;

    open(my $word_fh, '<', $aspell_word_file) || return;
    while (my $word = <$word_fh>) {
        chomp($word);
        next unless $word =~ m{\w}o;

        if (scalar(grep { lc($word) eq lc($_) } @words) > 0) {
            push(@removed_words, $word);
        } else {
            push(@saved_words, $word);
        }
    }
    close($word_fh);

    open($word_fh, '>', $aspell_word_file) || return;
    print $word_fh join("\n", @saved_words);
    close($word_fh);

    return sprintf('None of those words were in my personal dictionary.') if scalar(@removed_words) < 1;
    return sprintf('I have forgotten the following words: %s', join(', ', @removed_words));
}

sub remember_words {
    my ($bot, $message) = @_;

    $message =~ s{,}{ }ogs;
    my @words = map { clean_word($_) } grep { $_ =~ m{\w} } split(m{\s*(,|\s+)\s*}, $message);

    my $ts = Text::Aspell->new();
    return unless $ts;

    my @new_words;

    foreach my $word (@words) {
        next if $ts->check($word);

        $ts->add_to_personal($word);
        push(@new_words, $word);
    }

    $ts->save_all_word_lists;

    return sprintf('I already knew all of those words!') if scalar(@new_words) < 1;
    return sprintf('Remembered the following new words: %s', join(', ', @new_words));
}

1;
