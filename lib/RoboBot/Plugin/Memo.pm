package RoboBot::Plugin::Memo;

use strict;
use warnings;

sub commands { qw( * memo ) }
sub usage { "[ unread | <nick> <message> ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command eq 'memo') {
        return unread_memos($bot, $sender) if $message =~ m{^\s*unread}oi;

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

    my (@ids);

    my @r = ({ to => $nick });

    while ($res->next) {
        push(@ids, $res->{'memo_id'});
        push(@r, sprintf('Memo from %s (%s) > %s',
            $res->{'nick'}, $res->{'memo_time'}, $res->{'message'}));
    }

    return (-1) unless scalar(@ids) > 0;

    $res = $bot->db->do(q{ update memo_memos set delivered_at = now() where memo_id in ??? }, \@ids);
    return @r if scalar(@r) > 1;

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

sub unread_memos {
    my ($bot, $nick) = @_;

    my @output = ({ to => $nick });

    my $res = $bot->db->do(q{
        select n.nick as to, to_char(mm.created_at, 'YYYY-MM-DD HH24:MI:SS') as created,
            mm.message
        from memo_memos mm
            join nicks n on (n.id = mm.to_nick_id)
            join nicks n2 on (n2.id = mm.from_nick_id)
        where lower(n2.nick) = lower(?) and mm.delivered_at is null
        order by mm.created_at asc
    }, $nick);

    return unless $res;

    while ($res->next) {
        push(@output, sprintf('[%s] To: %s, Memo: %s',
            $res->{'created'}, $res->{'to'}, substr($res->{'message'}, 0, 64)));
    }

    push(@output, 'None of your memos are still unread.') if @output < 2;

    return @output;
}

1;
