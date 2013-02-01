package RoboBot::Plugin::Karma;

use strict;
use warnings;

sub commands { qw( * karma ) }
sub usage { "<nick>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command && $command eq 'karma') {
        return display_karma($bot, $message);
    } elsif ($message =~ m{(\w+)[:,]?\s*(\-\-|\+\+)}o) {
        return add_karma($bot, $sender, $1) if $2 eq '++';
        return remove_karma($bot, $sender, $1) if $2 eq '--';
    }

    return -1;
}

sub display_karma {
    my ($bot, $message) = @_;

    return unless $message =~ m{\b(\w+)\b}o;
    my $nick = $1;

    my $nick_id = nick_id($bot, $nick);
    return unless $nick_id;

    my $res = $bot->db->do(q{
        select sum(d.karma) as karma
        from (
            select from_nick_id, log(sum(karma))
            from karma_karma
            where nick_id = ? and karma = 1
            group by from_nick_id

            union all

            select from_nick_id, log(sum(abs(karma))) * -1
            from karma_karma
            where nick_id = ? and karma = -1
            group by from_nick_id
        ) d(from_nick_id, karma)
    }, $nick_id, $nick_id);

    return unless $res && $res->next;

    return sprintf('%s has %.2f karma', $nick, $res->{'karma'});
}

sub add_karma {
    my ($bot, $sender, $nick) = @_;

    my $sender_id = nick_id($bot, $sender);
    return unless $sender_id;

    my $nick_id = nick_id($bot, $nick);
    return unless $nick_id;

    return -1 if $sender_id == $nick_id;

    my $res = $bot->db->do(q{
        insert into karma_karma (nick_id, from_nick_id, karma) values (?,?,?)
    }, $nick_id, $sender_id, 1);

    return -1;
}

sub remove_karma {
    my ($bot, $sender, $nick) = @_;

    my $sender_id = nick_id($bot, $sender);
    return unless $sender_id;

    my $nick_id = nick_id($bot, $nick);
    return unless $nick_id;

    return -1 if $sender_id == $nick_id;

    my $res = $bot->db->do(q{
        insert into karma_karma (nick_id, from_nick_id, karma) values (?,?,?)
    }, $nick_id, $sender_id, -1);

    return -1;
}

sub nick_id {
    my ($bot, $sender) = @_;

    $sender =~ s{\_+$}{}og;

    return $bot->{'db'}->{'nicks'}->{$sender}
        if $bot->{'db'}->{'nicks'} && $bot->{'db'}->{'nicks'}->{$sender};

    my $res = $bot->db->do(q{ select id from nicks where nick = ? }, $sender);

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

1;
