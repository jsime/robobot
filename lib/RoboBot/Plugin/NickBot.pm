package RoboBot::Plugin::NickBot;

use strict;
use warnings;

sub commands { qw( * ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($message =~ m{^\s*!!(\w+)(\s.+)?$}o) {
        return random_from_nick($bot, $channel, $1, $2 || undef);
    }

    return -1;
}

sub random_from_nick {
    my ($bot, $channel, $nick, $phrase) = @_;

    $phrase =~ s{(^\s+|\s+$)}{}ogs if defined $phrase;
    my $res;

    if (defined $phrase && length($phrase) > 0) {
        $res = $bot->db->do(q{
            select n.nick, ll.message
            from nicks n
                join logger_log ll on (ll.nick_id = n.id)
                join channels c on (c.id = ll.channel_id)
                join servers s on (s.id = c.server_id)
            where lower(n.nick) = lower(?) and lower(c.name) = lower(?)
                and lower(s.name) = lower(?) and ll.message ~* ?::text
            order by random()
            limit 1
        }, $nick, $channel, $bot->config->server, $phrase);

        return sprintf("No messages located for nick %s matching pattern '%s'.", $nick, $phrase)
            unless $res && $res->next;
    } else {
        $res = $bot->db->do(q{
            select n.nick, ll.message
            from nicks n
                join logger_log ll on (ll.nick_id = n.id)
                join channels c on (c.id = ll.channel_id)
                join servers s on (s.id = c.server_id)
            where lower(n.nick) = lower(?) and lower(c.name) = lower(?)
                and lower(s.name) = lower(?)
            order by random()
            limit 1
        }, $nick, $channel, $bot->config->server);

        return sprintf("No messages located for nick %s.", $nick)
            unless $res && $res->next;
    }

    return sprintf('<%s> %s', $res->{'nick'}, $res->{'message'});
}

1;
