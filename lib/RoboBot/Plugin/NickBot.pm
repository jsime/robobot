package RoboBot::Plugin::NickBot;

use strict;
use warnings;

sub commands { qw( * ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($message =~ m{^\s*!!(\S+)(\s.+)?$}o) {
        return random_from_nick($bot, $channel, $1, $2 || undef);
    }

    return -1;
}

sub random_from_nick {
    my ($bot, $channel, $nick, $phrase) = @_;

    $phrase =~ s{(^\s+|\s+$)}{}ogs if defined $phrase;

    my ($res, $nick_ids);

    if ($nick eq '*') {
        $res = $bot->db->do(q{
            select id from nicks
        });

        return (-1) unless $res;

        while ($res->next) {
            push(@{$nick_ids}, $res->{'id'});
        }
    } else {
        $res = $bot->db->do(q{
            select id
            from nicks
            where lower(nick) = lower(?)
        }, $nick);

        return (-1) unless $res && $res->next;
        $nick_ids = [$res->{'id'}];
    }

    return (-1) unless scalar(@{$nick_ids}) > 0;

    if (defined $phrase && length($phrase) > 0) {
        $res = $bot->db->do(q{
            select n.nick, ll.message, to_char(ll.posted_at, 'YYYY-MM-DD HH24:MI') as posted_at
            from nicks n
                join logger_log ll on (ll.nick_id = n.id)
                join channels c on (c.id = ll.channel_id)
                join servers s on (s.id = c.server_id)
            where n.id in ??? and lower(c.name) = lower(?)
                and lower(s.name) = lower(?) and ll.message ~* ?::text
            order by random()
            limit 1
        }, $nick_ids, $channel, $bot->config->server, $phrase);

        return sprintf("No messages located for nick %s matching pattern '%s'.", $nick, $phrase)
            unless $res && $res->next;
    } else {
        $res = $bot->db->do(q{
            select n.nick, ll.message, to_char(ll.posted_at, 'YYYY-MM-DD HH24:MI') as posted_at
            from nicks n
                join logger_log ll on (ll.nick_id = n.id)
                join channels c on (c.id = ll.channel_id)
                join servers s on (s.id = c.server_id)
            where n.id in ??? and lower(c.name) = lower(?)
                and lower(s.name) = lower(?)
            order by random()
            limit 1
        }, $nick_ids, $channel, $bot->config->server);

        return sprintf("No messages located for nick %s.", $nick)
            unless $res && $res->next;
    }

    return sprintf('[%s] <%s> %s', $res->{'posted_at'}, $res->{'nick'}, $res->{'message'});
}

1;
