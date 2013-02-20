package RoboBot::Plugin::Info;

use strict;
use warnings;

sub commands { qw( * ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my $my_nick = $bot->config->nick;
    my $sender_id = sender_nick_id($bot, $sender);

    return (-1) unless defined $sender_id && $sender_id =~ m{^\d+$}o;

    if ($message =~ m|^\s*${my_nick}[:,]?\s+(.+)\s+:=\s+(\S+.*)$|oi) {
        return save_info($bot, $sender_id, $1, $2);
    } elsif ($message =~ m|^\s*${my_nick}[:,]?\s+(\S+.*)$|oi) {
        return find_info($bot, $sender_id, $1);
    }

    return (-1);
}

sub find_info {
    my ($bot, $sender_id, $title) = @_;

    $title = clean_text($title, 1);
    return (-1) unless defined $title && length($title) > 0;

    my $res = $bot->db->do(q{
        select ie.info_id, ie.title, ir.body, n.nick,
             to_char(ir.added_at, 'YYYY-MM-DD HH24:MI TZ') as last_updated,
            (select count(*) from info_revisions where info_id = ie.info_id) as revisions
        from info_entries ie
            join info_revisions ir on (ir.info_id = ie.info_id)
            join nicks n on (n.id = ir.added_by)
        where ir.revision_id = ( select info_revisions.revision_id
                                    from info_revisions
                                        join info_entries using (info_id)
                                    where lower(info_entries.title) like ?
                                        and not info_entries.deleted
                                    order by info_revisions.added_at desc
                                    limit 1
                                  )
    }, '%' . $title . '%');

    if ($res && $res->next) {
        return ($res->{'body'},
                sprintf('Revised %d time%s, most recently by %s at %s',
                    $res->{'revisions'}, ($res->{'revisions'} > 1 ? 's' : ''),
                    $res->{'nick'}, $res->{'last_updated'})
               );
    }

    return (-1);
}

sub save_info {
    my ($bot, $sender_id, $title, $body) = @_;

    $title = clean_text($title, 1);
    $body = clean_text($body);

    return (-1) unless defined $title && defined $body && length($title) > 0 && length($body) > 0;

    $bot->db->begin;

    my $info = $bot->db->do(q{
        select info_id
        from info_entries
        where lower(title) = ?
    }, $title);

    if ($info && $info->next) {
        my $res = $bot->db->do(q{
            insert into info_revisions ( info_id, added_by, body ) values ( ?, ?, ? )
        }, $info->{'info_id'}, $sender_id, $body);

        $bot->db->commit;
        return sprintf('Info for %s updated.', $title) if $res;
    } else {
        $info = $bot->db->do(q{
            insert into info_entries ( title ) values ( ? ) returning info_id
        }, $title);

        if ($info && $info->next) {
            my $res = $bot->db->do(q{
                insert into info_revisions ( info_id, added_by, body ) values ( ?, ?, ? )
            }, $info->{'info_id'}, $sender_id, $body);

            $bot->db->commit;
            return sprintf('Info for %s added.', $title) if $res;
        }
    }

    $bot->db->rollback;
    return (-1);
}

sub clean_text {
    my ($text, $to_lower) = @_;

    $text =~ s{(^\s+|\s+$)}{}ogs;
    $text =~ s{\s+}{ }ogs;

    return defined $to_lower && $to_lower ? lc($text) : $text;
}

sub sender_nick_id {
    my ($bot, $nick) = @_;

    $nick = clean_text($nick);

    my $res = $bot->db->do(q{
        select id from nicks where lower(nick) = lower(?)
    }, $nick);

    return $res->{'id'} if $res && $res->next;

    $res = $bot->db->do(q{
        insert into nicks ( nick ) values ( ? ) returning id
    }, $nick);

    return $res->{'id'} if $res && $res->next;

    return;
}

1;
