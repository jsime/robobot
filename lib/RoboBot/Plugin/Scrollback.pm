package RoboBot::Plugin::Scrollback;

use strict;
use warnings;

sub commands { qw( scrollback ) }
sub usage { "[minutes]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my $minutes = 240;
    if ($message =~ m{\b(\d+)\b}o) {
        $minutes = $1;
    }

    # We set the limit on the query to 1 higher than the allowed message
    # limit we pass back to the main routine, so that if there were more
    # channel messages within the specified time limit, the recipient will
    # see an "output truncated" notice.

    my $res = $bot->{'dbh'}->do(q{
        select to_char(l.posted_at, 'HH24:MI') as posted_at, n.nick, l.message
        from logger_log l
            join nicks n on (n.id = l.nick_id)
            join channels c on (c.id = l.channel_id)
        where c.name = ? and l.posted_at >= now() - (interval '1 minute' * ?)
        order by l.posted_at desc
        limit 21
    }, $channel, $minutes);

    return unless $res;

    my @r = ({ to => $sender, msg_limit => 20 });

    while ($res->next) {
        push(@r, sprintf('%s [%s] <%s> %s', $res->{'posted_at'}, $channel,
            $res->{'nick'}, $res->{'message'}));
    }

    # >1 (not 0) because there will always be the options hashref in @r
    push(@r, 'Nothing found.') unless scalar(@r) > 1;

    return @r;
}

1;
