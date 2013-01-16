package RoboBot::Plugin::Scrollback;

use strict;
use warnings;

sub commands { qw( scrollback ) }
sub usage { "[minutes]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my $minutes = 60;
    if ($message =~ m{\b(\d+)\b}o) {
        $minutes = $1;
    }

    my $res = $bot->{'dbh'}->do(q{
        select to_char(l.posted_at, 'HH24:MI') as posted_at, n.nick, l.message
        from logger_log l
            join nicks n on (n.id = l.nick_id)
            join channels c on (c.id = l.channel_id)
        where c.name = ? and l.posted_at >= now() - (interval '1 minute' * ?)
        order by l.posted_at desc
        limit 10
    }, $channel, $minutes);

    return unless $res;

    my @r;

    while ($res->next) {
        push(@r, sprintf('%s <%s> %s', $res->{'posted_at'}, $res->{'nick'}, $res->{'message'}));
    }

    return @r if scalar(@r) > 0;
    return 'Nothing found.';
}

1;
