package RoboBot::Plugin::Logger;

use strict;
use warnings;

sub commands { qw( * last ) }
sub usage { "[nick[,nick,...]] [offset[,count]]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command eq 'last') {
        # collapse whitespace around commas, so it's easier for people to list multiple nicks
        $message =~ s{\s*,\s*}{,}ogs;

        my @opt = split(/\s+/, $message);

        my ($nick, $num);

        if (scalar(@opt) == 2 && $opt[1] =~ m{^\s*\d+(,\d+)?\s*$}o) {
            ($nick, $num) = @opt;
        } elsif (scalar(@opt) == 1 && $opt[0] =~ m{^\s*\d+(,\d+)?\s*$}o) {
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

    my @nicks;

    if (defined $nick && $nick =~ m{\w+}o) {
        @nicks = map { $_ =~ s{(^\s+|\s+$)}{}ogs; lc($_) } split(/,/, $nick);
    }

    my $limit = 1;
    my $offset = 0;

    if (defined $num && $num =~ m{^\s*(\d+)\s*$}o) {
        $offset = $1 - 1;
    } elsif (defined $num && $num =~ m{^\s*(\d+),(\d+)\s*$}o) {
        $offset = $1 - 1;
        $limit = $2;
    }

    # for now, force a limit of 5 messages (for sanity)
    $limit = 5 if $limit > 5;

    # because the offset is moving backwards, we need to make sure the limit doesn't
    # exceed it (as the limit then moves the end point back toward the most recent entry)
    $limit = ($offset + 1) if $limit >= $offset;

    # then we move the offset to mark the end point (closest to most recent) since we'll
    # be grabbing these in reverse order initially
    $offset = ($offset + 1) - $limit;

    my $res;

    if (scalar(@nicks) > 0) {
        $res = $bot->db->do(q{
            select d.*
            from ( select n.nick, l.message, l.posted_at
                   from nicks n
                       join logger_log l on (l.nick_id = n.id)
                       join channels c on (c.id = l.channel_id)
                   where lower(n.nick) in ??? and lower(c.name) = lower(?)
                   order by l.posted_at desc
                   limit ? offset ?
                 ) d
            order by d.posted_at asc
        }, \@nicks, $channel, $limit, $offset);
    } else {
        $res = $bot->db->do(q{
            select d.*
            from ( select n.nick, l.message, l.posted_at
                   from logger_log l
                       join channels c on (c.id = l.channel_id)
                       join nicks n on (n.id = l.nick_id)
                   where lower(c.name) = lower(?)
                   order by l.posted_at desc
                   limit ? offset ?
                 ) d
            order by d.posted_at asc
        }, $channel, $limit, $offset);
    }

    my @r;

    if ($res) {
        while ($res->next) {
            push(@r, sprintf('<%s> %s', $res->{'nick'}, $res->{'message'}));
        }
    }

    return 'Nothing found.' unless scalar(@r) > 0;
    return join(' ', @r);
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
