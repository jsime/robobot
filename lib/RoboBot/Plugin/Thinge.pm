package RoboBot::Plugin::Thinge;

use strict;
use warnings;

sub commands { qw( catte dogge frogge pony bike bear vidya food koi ) }
sub usage { '[[<id>] | [#<tag>] | [add|save <url>] | [delete|remove|forget <id>] | [tag <id> <tag>] | [untag <id> <tag>] | [tags]]' }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($message =~ m{^\s*(?:add|save)\s+(\w+.*)$}oi) {
        return save_thinge($bot, $command, $sender, $1);
    } elsif ($message =~ m{^\s*(?:del(?:ete)?|rem(?:ove)?|rm|forget)\s+(\d+)\s*$}oi) {
        return delete_thinge($bot, $command, $1);
    } elsif ($message =~ m{^tag\s+(\d+)\s+(\#?\S+)\s*}oi) {
        return tag_thinge($bot, $command, $1, $2);
    } elsif ($message =~ m{^untag\s+(\d+)\s+(\#?\S+)\s*}oi) {
        return untag_thinge($bot, $command, $1, $2);
    } elsif ($message =~ m{^\s*\#(\w+)\s*$}oi) {
        return display_thinges($bot, $command, thinge_by_tag($bot, $command, $1));
    } elsif ($message =~ m{^\s*(\d+)\s*$}o) {
        return display_thinges($bot, $command, $1);
    } elsif ($message =~ m{^\s*$}o) {
        return display_thinges($bot, $command, random_thinge($bot, $command));
    } elsif ($message =~ m{^tags\s*$}o) {
        return display_tags($bot, $command);
    }

    return;
}

sub display_thinges {
    my ($bot, $type, @ids) = @_;

    return 'Nothing found matching that criteria.' unless scalar(@ids) > 0;

    my $res = $bot->db->do(q{
        select tt.id, tt.thinge_url, tt.thinge_num, n.nick, tt.added_at::date
        from thinge_thinges tt
            join thinge_types tty on (tty.id = tt.type_id)
            join nicks n on (n.id = tt.added_by)
        where tt.thinge_num in ??? and tty.name = ? and not tt.deleted
    }, \@ids, $type);

    return unless $res;

    my @thinges = ();

    while ($res->next) {
        my $tags = $bot->db->do(q{
            select tt.tag_name
            from thinge_thinge_tags ttt
                join thinge_tags tt on (tt.id = ttt.tag_id)
            where ttt.thinge_id = ?
            order by tt.tag_name asc
        }, $res->{'id'});

        my @t;

        if ($tags) {
            while ($tags->next) {
                push(@t, '#' . $tags->{'tag_name'});
            }
        }

        $res->{'thinge_url'} .= ' [ ' . join(' ', @t) . ' ]'
            if @t && scalar(@t) > 0;

        push(@thinges,
            sprintf('[%d] %s (Added by %s on %s)', $res->{'thinge_num'}, $res->{'thinge_url'},
                $res->{'nick'}, $res->{'added_at'})
        );
    }

    return 'Nothing found matching that criteria.' unless scalar(@thinges) > 0;
    return @thinges;
}

sub save_thinge {
    my ($bot, $type, $sender, $message) = @_;

    $message =~ s{(^\s+|\s+$)}{}ogs;

    my $nick_id = sender_nick_id($bot, $sender);
    my $type_id = thinge_type_id($bot, $type);

    my $res = $bot->db->do(q{
        select thinge_num from thinge_thinges where type_id = ? and lower(thinge_url) = lower(?)
    }, $type_id, $message);

    if ($res && $res->next) {
        return sprintf('That %s%s was already saved as ID %d.',
            uc(substr($type, 0, 1)), substr($type, 1), $res->{'thinge_num'});
    }

    $res = $bot->db->do(q{
        insert into thinge_thinges
            (type_id, thinge_url, added_by, thinge_num )
        values
            ( ?, ?, ?, (select coalesce(max(thinge_num),0) + 1 from thinge_thinges where type_id = ?) )
        returning thinge_num
    }, $type_id, $message, $nick_id, $type_id);

    return sprintf('An error occurred while attempting to save the %s.', $type) unless $res && $res->next;
    return sprintf('%s%s %d saved.', uc(substr($type, 0, 1)), substr($type, 1), $res->{'thinge_num'});
}

sub delete_thinge {
    my ($bot, $type, $thinge_num) = @_;

    my $res = $bot->db->do(q{
        update thinge_thinges
        set deleted = true
        where thinge_num = ? and type_id = (select id from thinge_types where lower(name) = lower(?))
    }, $thinge_num, $type);

    return sprintf('An error occurred while deleting %s %d', $type, $thinge_num) unless $res;
    return sprintf('%s%s %d has been deleted.', uc(substr($type, 0, 1)), substr($type, 1), $thinge_num);
}

sub tag_thinge {
    my ($bot, $type, $thinge_num, $tag_name) = @_;

    $tag_name = normalize_tag($tag_name);
    return unless length($tag_name) > 0;

    my $tag_id;

    my $res = $bot->db->do(q{ select id from thinge_tags where lower(tag_name) = lower(?) }, $tag_name);

    if ($res && $res->next) {
        $tag_id = $res->{'id'};
    } else {
        $res = $bot->db->do(q{ insert into thinge_tags (tag_name) values (?) returning id }, $tag_name);

        return unless $res && $res->next;
        $tag_id = $res->{'id'};
    }

    $res = $bot->db->do(q{
        select ttg.*
        from thinge_thinge_tags ttg
            join thinge_thinges tt on (tt.id = ttg.thinge_id)
            join thinge_types tty on (tty.id = tt.type_id)
        where tt.thinge_num = ? and ttg.tag_id = ? and lower(tty.name) = lower(?)
    }, $thinge_num, $tag_id, $type);

    return unless $res;
    return sprintf('%s%s %d already tagged with #%s',
        uc(substr($type, 0, 1)), substr($type, 1), $thinge_num, $tag_name) if $res->next;

    $res = $bot->db->do(q{
        insert into thinge_thinge_tags
            (tag_id, thinge_id)
        values ( ?, ( select tt.id
                      from thinge_thinges tt
                          join thinge_types tty on (tty.id = tt.type_id)
                      where tt.thinge_num = ? and lower(tty.name) = lower(?)
                    )
            )
    }, $tag_id, $thinge_num, $type);

    return sprintf('An error occurred while tagging %s %d with #%s', $type, $thinge_num, $tag_name) unless $res;
    return sprintf('%s%s %d has now been tagged with #%s',
        uc(substr($type, 0, 1)), substr($type, 1), $thinge_num, $tag_name);
}

sub untag_thinge {
    my ($bot, $type, $thinge_num, $tag_name) = @_;

    $tag_name = normalize_tag($tag_name);
    return unless length($tag_name) > 0;

    my $tag_id;

    my $res = $bot->db->do(q{ select id from thinge_tags where tag_name = ? }, $tag_name);

    if ($res && $res->next) {
        $tag_id = $res->{'id'};
    } else {
        return sprintf('No such tag exists: %s', $tag_name);
    }

    $res = $bot->db->do(q{
        delete from thinge_thinge_tags
        where tag_id = ?
            and thinge_id = ( select tt.id
                              from thinge_thinges tt
                                  join thinge_types tty on (tty.id = tt.type_id)
                              where tt.thing_num = ? and lower(tty.name) = lower(?)
                            )
    }, $tag_id, $thinge_num, $type);

    return unless $res;
    return sprintf('Tag #%s removed from %s%s %d', $tag_name,
        uc(substr($type, 0, 1)), substr($type, 1), $thinge_num) if $res->count() > 0;
    return sprintf('%s%s %d was not tagged with #%s', uc(substr($type, 0, 1)), substr($type, 1), $thinge_num, $tag_name);
}

sub thinge_by_tag {
    my ($bot, $type, $tag_name) = @_;

    $tag_name = normalize_tag($tag_name);

    my $res = $bot->db->do(q{
        select tt.thinge_num
        from thinge_thinges tt
            join thinge_thinge_tags ttt on (ttt.thinge_id = tt.id)
            join thinge_tags tta on (tta.id = ttt.tag_id)
            join thinge_types tty on (tty.id = tt.type_id)
        where tty.name = ? and tta.tag_name = ? and not tt.deleted
        order by random()
        limit 1
    }, $type, $tag_name);

    return unless $res && $res->next;
    return $res->{'thinge_num'};
}

sub random_thinge {
    my ($bot, $type) = @_;

    my $res = $bot->db->do(q{
        select tt.thinge_num
        from thinge_thinges tt
            join thinge_types tty on (tty.id = tt.type_id)
        where tty.name = ? and not tt.deleted
        order by random()
        limit 1
    }, $type);

    return unless $res && $res->next;
    return $res->{'thinge_num'};
}

sub display_tags {
    my ($bot, $type) = @_;

    my $res = $bot->db->do(q{
        select ttg.tag_name, count(distinct(tt.id)) as num_thinges
        from thinge_types tty
            join thinge_thinges tt on (tt.type_id = tty.id)
            join thinge_thinge_tags ttt on (ttt.thinge_id = tt.id)
            join thinge_tags ttg on (ttg.id = ttt.tag_id)
        where tty.name = ?
        group by ttg.tag_name
        order by 2 desc
        limit 20 offset 0
    }, $type);

    return unless $res;

    my @tags;

    while ($res->next) {
        push(@tags, { name => $res->[0], num => $res->[1] });
    }

    return sprintf('No tags for %s%s', uc(substr($type, 0, 1)), substr($type, 1)) if scalar(@tags) < 1;

    return (
        sprintf('Top %d most popular tags for %s%s:', scalar(@tags), uc(substr($type, 0, 1)), substr($type, 1)),
        join(', ', map { sprintf('#%s (%d)', $_->{'name'}, $_->{'num'}) } @tags)
    );
}

sub normalize_tag {
    my ($tag) = @_;

    $tag =~ s{(^\s+|\s+$)}{}ogs;
    $tag =~ s{^\#}{}o;

    $tag = lc($tag) unless $tag =~ m{^https?}oi;

    return $tag;
}

sub sender_nick_id {
    my ($bot, $sender) = @_;

    $sender =~ s{\_+$}{}og;

    return $bot->db->{'nicks'}->{$sender}
        if $bot->db->{'nicks'} && $bot->{'db'}->{'nicks'}->{$sender};

    my $res = $bot->db->do(q{ select id from nicks where lower(nick) = lower(?) }, $sender);

    $bot->{'db'}->{'nicks'} = {} unless $bot->{'db'}->{'nicks'};

    if ($res && $res->next) {
        $bot->{'db'}->{'nicks'}->{$sender} = $res->{'id'};

        return $res->{'id'};
    } else {
        $res = $bot->db->do(q{ insert into nicks (nick) values (?) returning id }, $sender);

        return unless $res && $res->next;

        $bot->{'db'}->{'nicks'}->{$sender} = $res->{'id'};

        return $res->{'id'};
    }
}

sub thinge_type_id {
    my ($bot, $type) = @_;

    my $res = $bot->db->do(q{ select id from thinge_types where name = ? }, $type);

    return $res->{'id'} if $res && $res->next;

    $res = $bot->db->do(q{ insert into thinge_types (name) values (?) returning id }, $type);

    return unless $res && $res->next;
    return $res->{'id'};
}

1;
