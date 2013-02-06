package RoboBot::Plugin::Memo;

use strict;
use warnings;

sub commands { qw( * memo ) }
sub usage { "<nick> <message>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command eq 'memo') {
        my @t = split(/\s+/o, $message);
        return unless scalar(@t) > 1;

        my $to_nick = shift(@t);
        $message = join(' ', @t);

        return save_memo($bot, $sender, $to_nick, $message);
    } else {
        return check_memos($bot, $sender);
    }

    return (-1);
}

sub check_memos {
    my ($bot, $nick) = @_;

    my $res = $bot->db->do(q{
        select m.memo_id, nfrom.nick, m.message,
            to_char(m.created_at, 'YYYY-MM-DD HH24:MI TZ') as memo_time
        from memo_memos m
            join nicks nfrom on (nfrom.id = m.from_nick_id)
            join nicks nto on (nto.id = m.to_nick_id)
        where lower(nto.nick) = lower(?) and m.delivered_at is null
        order by m.created_at asc
    }, $nick);

    return (-1) unless $res;

    my (@ids, @r);

    while ($res->next) {
        push(@ids, $res->{'memo_id'});

        push(@r, sprintf('%s: Memo from %s (%s) > %s',
            $nick, $res->{'nick'}, $res->{'memo_time'}, $res->{'message'}));
    }

    return (-1) unless scalar(@ids) > 0;

    $res = $bot->db->do(q{ update memo_memos set delivered_at = now() where memo_id in ??? }, \@ids);
    return @r if scalar(@r) > 0;

    return (-1);
}

sub save_memo {
    my ($bot, $from_nick, $to_nick, $message) = @_;

    $from_nick =~ s{(\s+|\s+$)}{}ogs;
    $to_nick =~ s{(^\s+|\s+$)}{}ogs;

    $message =~ s{\s+}{ }ogs;
    $message =~ s{(^\s+|\s+$)}{}ogs;

    return sprintf('Your memo exceeds the 200 character limit and will not be saved.')
        if length($message) > 200;

    my $res = $bot->db->do(q{
        insert into memo_memos
            ( from_nick_id, to_nick_id, message )
        values (
            (select id from nicks where lower(nick) = lower(?)),
            (select id from nicks where lower(nick) = lower(?)),
            ?
        )
        returning memo_id
    }, $from_nick, $to_nick, $message);

    return sprintf("I'm sorry, but there was an error saving your memo.")
        unless $res && $res->next;
    return sprintf("Your memo has been saved and will be sent to %s when they next speak.", $to_nick);
}

1;
