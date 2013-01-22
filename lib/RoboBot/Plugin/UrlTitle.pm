package RoboBot::Plugin::UrlTitle;

use strict;
use warnings;

use HTML::HeadParser;
use LWP::UserAgent;
use Text::Levenshtein qw(distance);

sub commands { qw( * ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my @urls = ($message =~ m{\b(https?://\S+)\b}oig);

    if (scalar(@urls) > 0) {
        my $ua = LWP::UserAgent->new();
        $ua->timeout(3); # short timeout because we don't want to hold up other plugins/commands

        my @output = ();

        foreach my $url (@urls) {
            my $r = $ua->get($url);

            if ($r->is_success) {
                my $parser = HTML::HeadParser->new();
                $parser->parse($r->decoded_content());

                my $title = $parser->header('Title');

                my $final_url = $r->base;

                push(@output, sprintf('Title: %s', (length($title) > 120 ? substr($title, 0, 110) . '...' : $title)))
                    if $title =~ m{\w+};

                # seems a little odd, but direct comparisons weren't working reliably, maybe because of
                # character set mismatches? anyway -- only show redirect if the levenshtein between the
                # two URLs is greater than X% of the lenght of the input URL.
                push(@output, sprintf('Redirected to: %s', $final_url))
                    if distance($final_url, $url) >= length($url) * 0.1;
            }
        }

        return scalar(@output) > 0 ? @output : -1;
    }

    return (-1);
}

1;
