package RoboBot::Plugin::UrlTitle;

use strict;
use warnings;

use HTML::HeadParser;
use LWP::UserAgent;
use Text::Levenshtein qw(distance);

sub commands { qw( !title ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    # transitioning to the new robobot and disabling automatic URL parsing in this version
    return -1;

    my @urls = ($message =~ m{\b(https?://\S+)\b}oig);

    if (scalar(@urls) > 0) {
        my $ua = LWP::UserAgent->new();
        $ua->timeout(3); # short timeout because we don't want to hold up other plugins/commands

        my @output = ();

        URL:
        foreach my $url (@urls) {
            my $r = $ua->get($url);

            if ($r->is_success) {
                my $parser = HTML::HeadParser->new();
                next URL unless eval { $parser->parse($r->decoded_content()) };

                my $title = $parser->header('Title');

                my $final_url = $r->base;

                push(@output, sprintf('Title: %s', (length($title) > 120 ? substr($title, 0, 110) . '...' : $title)))
                    if defined $title && $title =~ m{\w+}o;

                # seems a little odd, but direct comparisons weren't working reliably, maybe because of
                # character set mismatches? anyway -- only show redirect if the levenshtein between the
                # two URLs is greater than X% of the lenght of the input URL.
                push(@output, sprintf('Redirected to: %s', $final_url))
                    if distance($final_url, $url) >= length($url) * 0.1;

                my $res = $bot->db->do(q{
                    select n.nick, c.name as channel, to_char(u.linked_at, 'YYYY-MM-DD HH24:MI') as linked_at
                    from urltitle_urls u
                        join nicks n on (n.id = u.nick_id)
                        join channels c on (c.id = u.channel_id)
                    where u.final_url = ?
                    order by u.linked_at desc
                }, $final_url);

                if ($res && $res->next) {
                    push(@output, sprintf('Last posted by %s on %s in channel %s.',
                        $res->{'nick'}, $res->{'linked_at'}, $res->{'channel'}));

                    if ($res->count > 1) {
                        $output[-1] .= sprintf(' Posted a total of %d times.', $res->count);
                    }
                }

                log_url($bot, $sender, $channel, $title, $url, $final_url);
            }
        }

        return scalar(@output) > 0 ? @output : -1;
    }

    return (-1);
}

sub log_url {
    my ($bot, $nick, $channel, $title, $url, $final_url) = @_;

    my $res = $bot->db->do(q{
        insert into urltitle_urls
            ( channel_id, nick_id, title, original_url, final_url )
        select (select id from channels where lower(name) = lower(?)),
               (select id from nicks where lower(nick) = lower(?)),
               ?, ?, ?
    }, $channel, $nick, $title, $url, $final_url);

    return 1 if $res;
    return;
}

1;
