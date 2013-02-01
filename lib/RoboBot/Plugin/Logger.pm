package RoboBot::Plugin::Logger;

use strict;
use warnings;

sub commands { qw( * last ) }
sub usage { "[nick] [num]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command eq 'last') {
        my @opt = split(/\s+/, $message);

        my ($nick, $num);

        if (scalar(@opt) == 2 && $opt[1] =~ m{^\d+$}o) {
            ($nick, $num) = @opt;
        } elsif (scalar(@opt) == 1 && $opt[0] =~ m{^\d+$}o) {
            $num = $opt[0];
        } elsif (scalar(@opt) == 1) {
            $nick = $opt[0];
            $num = 1;
        }

        return last_message($bot, $channel, $nick, $num);
    } elsif (length($command) == 0) {
        log_message($bot, $sender, $channel, $message);
    }

    return -1;
}

sub last_message {
    my ($bot, $channel, $nick, $num) = @_;

    my $nick_where = '';
    my @binds = ();

    $nick_where = qq{ and nick_id = (select nx.id from nicks nx where nx.nick = ?) } if $nick;
    push(@binds, $nick) if $nick;

    my $res = $bot->db->do(qq{
        select n.nick, ll.message
        from logger_log ll
            join nicks n on (n.id = ll.nick_id)
        where ll.channel_id = ? $nick_where
        order by ll.posted_at desc
        limit 1 offset ?
    }, $bot->{'db'}->{'channels'}->{$channel}, @binds, $num > 0 ? $num - 1 : 0);

    if ($res && $res->next) {
        return sprintf('<%s> %s', $res->{'nick'}, $res->{'message'});
    } else {
        return 'Nothing found.';
    }
}

sub log_message {
    my ($bot, $sender, $channel, $message) = @_;

    # normalize nicks to remove the common "_" from unintended reconnects
    $sender =~ s{\_+$}{}og;

    my ($res, $nick_id);

    if ($bot->{'db'}->{'nicks'} && $bot->{'db'}->{'nicks'}->{$sender}) {
        $nick_id = $bot->{'db'}->{'nicks'}->{$sender};
    } else {
        $res = $bot->db->do(q{ select id from nicks where nick = ? }, $sender);

        if ($res && $res->next) {
            $nick_id = $res->{'id'};
        } else {
            $res = $bot->db->do(q{ insert into nicks (nick) values (?) returning id }, $sender);

            return unless $res && $res->next;

            $nick_id = $res->{'id'};
        }
    }

    $bot->{'db'}->{'nicks'} = {} unless $bot->{'db'}->{'nicks'};
    $bot->{'db'}->{'nicks'}->{$sender} = $nick_id;

    $res = $bot->db->do(q{
        insert into logger_log ???
    }, { channel_id => $bot->{'db'}->{'channels'}->{$channel},
         nick_id    => $nick_id,
         message    => $message,
    });

    return;
}

1;
