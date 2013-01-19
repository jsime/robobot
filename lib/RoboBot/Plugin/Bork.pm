package RoboBot::Plugin::Bork;

use strict;
use warnings;

use utf8;

sub commands { qw( bork ) }
sub usage { "<text>" }

my %repl = (
    A   => ['A',"\N{U+00c4}","\N{U+00c5}"],
    O   => ['O',"\N{U+00d6}","\N{U+00d8}"],
    U   => ['U',"\N{U+00dc}"],
    AE  => ["\N{U+00c6}"],
    Ae  => ["\N{U+00c6}"],
    SS  => ["\N{U+00df}"],
    Ss  => ["\N{U+00df}"],
    TH  => ['TH',"\N{U+00de}"],
    Th  => ['Th',"\N{U+00de}"],

    a   => ['a',"\N{U+00e4}","\N{U+00e5}"],
    o   => ['o',"\N{U+00f6}","\N{U+00f8}"],
    oo  => ["\N{U+00fc}\N{U+00fc}\N{U+00fc}\N{U+00fc}"],
    u   => ['u',"\N{U+00fc}"],
    ae  => ["\N{U+00e6}"],
    ss  => ['ss',"\N{U+00df}"],
    th  => ['th',"\N{U+00f0}"],
);

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    foreach my $ch (sort { length($b) <=> length($a) } keys %repl) {
#        my $new_ch = rand() <= 0.5 ? $repl{$ch}[int(rand(scalar(@{$repl{$ch}})))] : $repl{$ch}->[0];

        $message =~
            s<
                ($ch)+
            ><
                rand() <= 0.8
                    ? $repl{$ch}[int(rand(scalar(@{$repl{$ch}})))]
                    : $repl{$ch}->[0]
            >gex;
    }

    my @words = split(/\s+/, $message);

    foreach my $word (@words) {
        $word = 'bork bork bork' if rand() <= 0.1;
    }

    return join(' ', @words);
}

1;
