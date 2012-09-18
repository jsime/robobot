package RoboBot::Plugin::UrlTitle;

use strict;
use warnings;

use HTML::HeadParser;
use LWP::UserAgent;

sub commands { qw( * ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($message =~ m{\b(https?://\S+)\b}oi) {
        my $url = $1;

        my $ua = LWP::UserAgent->new();
        $ua->timeout(3); # short timeout because we don't want to hold up other plugins/commands

        my $r = $ua->get($url);

        if ($r->is_success) {
            my $parser = HTML::HeadParser->new();
            $parser->parse($r->decoded_content());

            my $title = $parser->header('Title');

            my $final_url = $r->base;

            my @output = ();

            push(@output, sprintf('Title: %s', (length($title) > 120 ? substr($title, 0, 110) . '...' : $title)))
                if $title =~ m{\w+};
            push(@output, sprintf('Redirected to: %s', $final_url))
                if $final_url ne $url;

            return scalar(@output) > 0 ? @output : -1;
        }
    }

    return (-1);
}

1;
