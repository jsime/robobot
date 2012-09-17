package RoboBot::Plugin::Perl;

use strict;
use warnings;

use Data::Dumper;
use Safe;

sub commands { qw( perl ) }
sub usage { "<code>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message;

    if (grep { $message =~ m{$_} } denied()) {
        return "Error: restricted keyword or variable detected";
    }

    my $safe = Safe->new;

    if (my $output = $safe->reval($message)) {
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::Indent = 0;

        $output = Dumper($output) if ref($output);

        return $output;
    } elsif ($@) {
        return "Error: $@";
    }
}

sub denied {
    qw(
        `
        system
        exec
        open
        close
        use
        require
        sysopen
        link
        unlink
        chdir
        SIG
        ENV
        INC        
    );
}

1;
