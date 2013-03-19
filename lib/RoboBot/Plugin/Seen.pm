package RoboBot::Plugin::Seen;

use strict;
use warnings;

sub commands { qw( seen ) }
sub usage { "<nick>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless defined $message && $message =~ m{\w+}o;

    $message =~ s{(^\s+|s+$)}{}ogs;

    my $res = $bot->db->do(q{
        select s.name as server, c.name as channel, n.nick, ll.message,
            to_char(ll.posted_at, 'YYYY-MM-DD HH24:MM') as posted_at
        from nicks n
            join logger_log ll on (ll.nick_id = n.id)
            join channels c on (c.id = ll.channel_id)
            join servers s on (s.id = c.server_id)
        where lower(n.nick) = lower(?)
        order by ll.posted_at desc
        limit 1
    }, $message);

    if ($res && $res->next) {
        return sprintf('%s last seen on %s/%s at %s saying: %s',
            $res->{'nick'}, $res->{'server'}, $res->{'channel'}, $res->{'posted_at'},
            $res->{'message'});
    }

    return sprintf('I have no record of messages from that nick on any of the servers to which I connect.');
}

1;
