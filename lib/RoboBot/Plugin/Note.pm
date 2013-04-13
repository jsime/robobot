package RoboBot::Plugin::Note;

use strict;
use warnings;

sub commands { qw( note ) }
sub usage { '[[ <id> ] | list | add <text> | delete <id> | update <id> <text> ]' }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return update_note($bot, $sender, $1, $2) if $message =~ m{^\s*update\s+(\d+)\s+(.+)}oi;
    return delete_note($bot, $sender, $1) if $message =~ m{^\s*delete\s+(\d+)}oi;
    return add_note($bot, $sender, $1) if $message =~ m{^\s*add\s+(.+)}oi;
    return list_notes($bot, $sender) if $message =~ m{^\s*list}oi;
    return show_note($bot, $sender, $1) if $message =~ m{^\s*(\d+)}oi;

    return;
}

sub list_notes {
    my ($bot, $nick) = @_;

    my $res = $bot->db->do(q{
        select row_number() over () as rownum,
            no.note_id, no.note, n.nick,
            to_char(no.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at,
            to_char(no.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at
        from note_notes no
            join nicks n on (n.id = no.nick_id)
        where lower(n.nick) = lower(?)
        order by coalesce(no.updated_at, no.created_at) desc
        limit 10;
    }, $nick);

    return (-1) unless $res;

    my @output = ({ to => $nick });

    while ($res->next) {
        push(@output, sprintf('%d. %s (%s)',
            $res->{'rownum'},
            substr($res->{'note'}, 0, 64) . (length($res->{'note'}) > 64 ? '...' : ''),
            $res->{'updated_at'} || $res->{'created_at'}
        ));
    }

    return @output if @output > 0;
    return sprintf('You have not saved any notes.');
}

sub add_note {
    my ($bot, $nick, $note) = @_;

    my $res = $bot->db->do(q{
        insert into note_notes
            ( nick_id, note )
        select n.id, ?
        from nicks n
        where lower(n.nick) = lower(?)
        returning note_id
    }, $note, $nick);

    return unless $res && $res->next;
    return sprintf('Note %d saved.', $res->{'note_id'});
}

sub update_note {
    my ($bot, $nick, $note_id, $note) = @_;

    my $res = $bot->db->do(q{
        update note_notes
        set note = ?,
            updated_at = now()
        where note_id = ( select note_id
                          from note_notes nn
                              join nicks n on (n.id = nn.nick_id)
                          where lower(n.nick) = lower(?)
                          order by coalesce(nn.updated_at, nn.created_at) desc
                          limit 1 offset ? )
        returning note_id
    }, $note, $nick, $note_id);

    return unless $res && $res->next;
    return sprintf('Note %d updated.', $res->{'note_id'});
}

sub show_note {
    my ($bot, $nick, $note_id) = @_;

    my $res = $bot->db->do(q{
        select no.note_id, no.note, to_char(no.created_at, 'YYYY-MM-DD HH24:MI:SS') as created_at,
            to_char(no.updated_at, 'YYYY-MM-DD HH24:MI:SS') as updated_at
        from note_notes no
            join nicks n on (n.id = no.nick_id)
        where lower(n.nick) = lower(?) and no.note_id = ?
    }, $nick, $note_id);

    return unless $res;
    return sprintf('Note %d is not valid for your nick.', $note_id) unless $res->next;
    return ($res->{'note'}, sprintf('Created: %s / Updated: %s', $res->{'created_at'}, $res->{'updated_at'} || 'never'));
}

sub delete_note {
    my ($bot, $nick, $note_id) = @_;

    my $res = $bot->db->do(q{
        delete from note_notes
        where nick_id = (select id from nicks where lower(nick) = lower(?))
            and note_id = ?
    }, $nick, $note_id);

    return unless $res;
    return sprintf('Note %d deleted.', $note_id);
}

1;
