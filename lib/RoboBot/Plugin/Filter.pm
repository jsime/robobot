package RoboBot::Plugin::Filter;

use strict;
use warnings;

use FileHandle;
use IPC::Open2;

sub commands { qw( b1ff chef cockney eleet fudd nethackify newspeak pirate scottish scramble uniencode ) }
sub usage { "<text>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message =~ m{\w+}o;
    return unless grep { $_ eq $command } commands();

    my $prog = `which $command`;
    chomp($prog);
    print STDERR "Filter program: [[$prog]]\n";
    return "That filter does not appear to be installed on this machine." unless -x $prog;

    my $pid = open2(my $rfh, my $wfh, $prog) || return;

    print $wfh $message;
    close($wfh);

    my $filtered_text = join("\n", <$rfh>);

    $filtered_text =~ s{[\n\r]+}{\n}ogs;

    return $filtered_text;
}

1;
