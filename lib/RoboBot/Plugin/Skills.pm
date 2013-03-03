package RoboBot::Plugin::Skills;

use strict;
use warnings;

sub commands { qw( skill ) }
sub usage { "[ list | levels | <nick> | <skill> | register <skill> <level> | unregister <skill> | add|save <skill> ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($message =~ m{\w+}o) {
        $message =~ s{(^\s+|\s+$)}{}ogs;

        my @t = split(/\s+/o, $message);

        my $subcmd = lc(shift(@t));
        $message = join(' ', @t);

        my ($nick_id, $skill_id);

        return list_skills(     $bot                ) if $subcmd eq 'list';
        return list_levels(     $bot                ) if $subcmd eq 'levels';
        return register_skill(  $bot, $sender, @t   ) if $subcmd eq 'register';
        return unregister_skill($bot, $sender, @t   ) if $subcmd eq 'unregister';
        return save_skill(      $bot, $sender, @t   ) if ($subcmd eq 'add' || $subcmd eq 'save');
        return show_nick_skills($bot, $nick_id      ) if ($nick_id = lookup_nick_id($bot, $subcmd));
        return show_skill_nicks($bot, $skill_id     ) if ($skill_id = lookup_skill_id($bot, $subcmd));
    } else {
        return show_nick_skills($bot, lookup_nick_id($bot, $sender));
    }

    return;
}

sub list_levels {
    my ($bot) = @_;

    my $res = $bot->db->do(q{
        select name, sort_order from skills_levels order by sort_order asc
    });

    return unless $res;

    my @levels;

    while ($res->next) {
        push(@levels, sprintf('%d: %s', $res->{'sort_order'}, $res->{'name'}));
    }

    return sprintf('There are no skill levels established yet.') unless scalar(@levels) > 0;
    return join(', ', @levels);
}

sub list_skills {
    my ($bot) = @_;

    my $res = $bot->db->do(q{
        select name from skills_skills order by name asc
    });

    return unless $res;

    my @skills;

    while ($res->next) {
        push(@skills, $res->{'name'});
    }

    return sprintf('It seems nobody knows anything yet.') unless scalar(@skills) > 0;
    return join(', ', @skills);
}

sub lookup_nick_id {
    my ($bot, $nick) = @_;

    $nick =~ s{(^\s+|\s+$)}{}ogs;

    my $res = $bot->db->do(q{
        select id from nicks where lower(nick) = lower(?)
    }, $nick);

    return $res->{'id'} if $res && $res->next;
    return;
}

sub lookup_skill_id {
    my ($bot, $skill) = @_;

    $skill =~ s{(^\s+|\s+$)}{}ogs;

    my $res = $bot->db->do(q{
        select skill_id from skills_skills where lower(name) = lower(?)
    }, $skill);

    return $res->{'skill_id'} if $res && $res->next;
    return;
}

sub register_skill {
    my ($bot, $nick, $skill, $skill_level) = @_;

    my $nick_id = lookup_nick_id($bot, $nick);
    my $skill_id = lookup_skill_id($bot, $skill);

    return unless $nick_id && $skill_id;

    my $level = $bot->db->do(q{
        select level_id, name, sort_order
        from skills_levels
        where lower(name) = lower(?) or sort_order = ?
    }, $skill_level, ($skill_level =~ m{^\d+$}o ? $skill_level : undef));

    return sprintf('Unknown skill level: %s', $skill_level) unless $level && $level->next;

    my $res = $bot->db->do(q{
        select sn.*
        from skills_nicks sn
        where skill_id = ? and nick_id = ?
    }, $skill_id, $nick_id);

    if ($res && $res->next) {
        $res = $bot->db->do(q{
            update skills_nicks
            set skill_level_id = ?
            where skill_id = ? and nick_id = ?
            returning * 
        }, $level->{'level_id'}, $skill_id, $nick_id);

        return sprintf('Skill level updated to %s', $level->{'name'}) if $res && $res->next;
    } else {
        $res = $bot->db->do(q{
            insert into skills_nicks ( skill_id, nick_id, skill_level_id )
            values (?, ?, ?)
            returning *
        }, $skill_id, $nick_id, $level->{'level_id'});

        return sprintf('Registered skill level of %s', $level->{'name'}) if $res && $res->next;
    }

    return;
}

sub unregister_skill {
    my ($bot, $nick, $skill) = @_;

    my $nick_id = lookup_nick_id($bot, $nick);
    my $skill_id = lookup_skill_id($bot, $skill);

    return unless $nick_id && $skill_id;

    my $res = $bot->db->do(q{
        delete from skills_nicks where skill_id = ? and nick_id = ?
    }, $skill_id, $nick_id);

    return sprintf('You no longer know that skill. Good job?') if $res && $res->count > 0;
    return sprintf('You did not know that skill to begin with.') if $res;
    return;
}

sub save_skill {
    my ($bot, $nick, $skill) = @_;

    $nick =~ s{(^\s+|\s+$)}{}ogs;
    $skill =~ s{(^\s+|\s+$)}{}ogs;

    my $res = $bot->db->do(q{
        insert into skills_skills (name, created_by) values (
            ?,
            (select id from nicks where lower(nick) = lower(?))
        )
        returning skill_id
    }, $skill, $nick);

    return unless $res && $res->next;
    return sprintf('Skill %s saved as ID %d.', $skill, $res->{'skill_id'});
}

sub show_nick_skills {
    my ($bot, $nick_id) = @_;

    my $nick = $bot->db->do(q{
        select *
        from nicks
        where id = ?
    }, $nick_id);

    return unless $nick && $nick->next;

    my @order;
    my %levels;

    my $res = $bot->db->do(q{
        select sl.name as level, s.name as skill
        from skills_nicks sn
            join skills_skills s on (s.skill_id = sn.skill_id)
            join skills_levels sl on (sl.level_id = sn.skill_level_id)
        where sn.nick_id = ?
        order by sl.sort_order desc, s.name asc
    }, $nick_id);

    return unless $res;

    while ($res->next) {
        $levels{$res->{'level'}} = [] unless exists $levels{$res->{'level'}};
        push(@{$levels{$res->{'level'}}}, $res->{'skill'});
        push(@order, $res->{'level'}) unless scalar(@order) > 0 && $order[-1] eq $res->{'level'};
    }

    return sprintf("%s doesn't know nuffin' 'bout nuffin' apparently.", $nick->{'nick'})
        unless scalar(keys(%levels)) > 0;

    my @r = (sprintf('%s knows the following skills:', $nick->{'nick'}));

    foreach my $level (@order) {
        push(@r, sprintf('  %s: %s', $level, join(', ', @{$levels{$level}})));
    }

    return @r;
}

sub show_skill_nicks {
    my ($bot, $skill_id) = @_;

    my $skill = $bot->db->do(q{
        select * from skills_skills where skill_id = ?
    }, $skill_id);

    return unless $skill && $skill->next;

    my @order;
    my %levels;

    my $res = $bot->db->do(q{
        select sl.name as level, n.nick
        from skills_nicks sn
            join nicks n on (n.id = sn.nick_id)
            join skills_levels sl on (sl.level_id = sn.skill_level_id)
        where sn.skill_id = ?
        order by sl.sort_order desc, n.nick asc
    }, $skill_id);

    return unless $res;

    while ($res->next) {
        $levels{$res->{'level'}} = [] unless exists $levels{$res->{'level'}};
        push(@{$levels{$res->{'level'}}}, $res->{'nick'});
        push(@order, $res->{'level'}) unless scalar(@order) > 0 && $order[-1] eq $res->{'level'};
    }

    return sprintf("Nobody knows %s.", $skill->{'name'})
        unless scalar(keys(%levels)) > 0;

    my @r = (sprintf('The following people know %s', $skill->{'name'}));

    foreach my $level (@order) {
        push(@r, sprintf('  %s: %s', $level, join(', ', @{$levels{$level}})));
    }

    return @r;
}

1;
