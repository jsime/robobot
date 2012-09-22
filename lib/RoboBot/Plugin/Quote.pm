package RoboBot::Plugin::Quote;

use strict;
use warnings;

use Number::Format;

sub commands { qw( quote ) }
sub usage { '[[<id>] | [#<tag>] | [add|save <text>] | [delete|remove|forget <id>] | [search <text>] | [tag <id> <tag>]]' }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($message =~ m{^\s*(?:add|save)\s+(\w+.*)$}oi) {
        return save_quote($bot, $sender, $1);
    } elsif ($message =~ m{^\s*(?:del(?:ete)?|rem(?:ove)?|rm|forget)\s+(\d+)\s*$}oi) {
        return delete_quote($bot, $1);
    } elsif ($message =~ m{^\s*search\s+(\w+.*)$}oi) {
        return display_quotes($bot, search_quotes($bot, $1));
    } elsif ($message =~ m{^tag\s+(\d+)\s+(\#?\w+)\s*}oi) {
        return tag_quote($bot, $1, $2);
    } elsif ($message =~ m{^\s*\#(\w+)\s*$}oi) {
        return display_quotes($bot, quote_by_tag($bot, $1));
    } elsif ($message =~ m{^\s*(\d+)\s*$}o) {
        return display_quotes($bot, $1);
    } elsif ($message =~ m{^\s*$}o) {
        return display_quotes($bot, random_quote($bot));
    }

    return;
}

sub display_quotes {
    my ($bot, @ids) = @_;

    return 'No quotes found matching that criteria.' unless scalar(@ids) > 0;

    my $res = $bot->{'dbh'}->do(q{
        select qq.id, qq.quote
        from quote_quotes qq
        where qq.id in ??? and not qq.deleted
    }, \@ids);

    return unless $res;

    my @quotes = ();

    while ($res->next) {
        my $tags = $bot->{'dbh'}->do(q{
            select qt.tag_name
            from quote_quote_tags qqt
                join quote_tags qt on (qt.id = qqt.tag_id)
            where qqt.quote_id = ?
            order by qt.tag_name asc
        }, $res->{'id'});

        my @t;

        if ($tags) {
            while ($tags->next) {
                push(@t, '#' . $tags->{'tag_name'});
            }
        }

        $res->{'quote'} .= ' [ ' . join(' ', @t) . ' ]'
            if @t && scalar(@t) > 0;

        push(@quotes, sprintf('[%d] %s', $res->{'id'}, $res->{'quote'}));
    }

    return 'No quotes found matching that criteria.' unless scalar(@quotes) > 0;
    return @quotes;
}

sub save_quote {
    my ($bot, $sender, $message) = @_;

    $message =~ s{(^\s+|\s+$)}{}ogs;

    my $nick_id = sender_nick_id($bot, $sender);

    my $res = $bot->{'dbh'}->do(q{
        insert into quote_quotes ??? returning id
    }, {    quote    => $message,
            added_by => $nick_id,
    });

    return 'An error occurred while attempting to save the quote.' unless $res && $res->next;
    return sprintf('Quote %d saved.', $res->{'id'});
}

sub delete_quote {
    my ($bot, $quote_id) = @_;

    my $res = $bot->{'dbh'}->do(q{ update quote_quotes set deleted = true where id = ? }, $quote_id);

    return sprintf('An error occurred while deleting quote %d', $quote_id) unless $res;
    return sprintf('Quote %d has been deleted.', $quote_id);
}

sub search_quotes {
    my ($bot, $qstring) = @_;

    return unless $qstring && $qstring =~ m{\w+}o;

    my $res = $bot->{'dbh'}->do(q{
        select qq.id
        from quote_quotes qq
        where quote ~* ? and not deleted
        order by random()
        limit 1
    }, $qstring);

    return unless $res && $res->next;
    return $res->{'id'};
}

sub tag_quote {
    my ($bot, $quote_id, $tag_name) = @_;

    $tag_name = normalize_tag($tag_name);
    return unless length($tag_name) > 0;

    my $tag_id;

    my $res = $bot->{'dbh'}->do(q{ select id from quote_tags where tag_name = ? }, $tag_name);

    if ($res && $res->next) {
        $tag_id = $res->{'id'};
    } else {
        $res = $bot->{'dbh'}->do(q{ insert into quote_tags (tag_name) values (?) returning id }, $tag_name);

        return unless $res && $res->next;
        $tag_id = $res->{'id'};
    }

    $res = $bot->{'dbh'}->do(q{ select * from quote_quote_tags where quote_id = ? and tag_id = ? }, $quote_id, $tag_id);

    return unless $res;
    return sprintf('Quote %d already tagged with #%s', $quote_id, $tag_name) if $res->next;

    $res = $bot->{'dbh'}->do(q{ insert into quote_quote_tags (quote_id, tag_id) values (?,?) }, $quote_id, $tag_id);

    return sprintf('An error occurred while tagging quote %d with #%s', $quote_id, $tag_name) unless $res;
    return sprintf('Quote %d has now been tagged with #%s', $quote_id, $tag_name);
}

sub quote_by_tag {
    my ($bot, $tag_name) = @_;

    $tag_name = normalize_tag($tag_name);

    my $res = $bot->{'dbh'}->do(q{
        select qq.id
        from quote_quotes qq
            join quote_quote_tags qqt on (qqt.quote_id = qq.id)
            join quote_tags qt on (qt.id = qqt.tag_id)
        where qt.tag_name = ? and not qq.deleted
        order by random()
        limit 1
    }, $tag_name);

    return unless $res && $res->next;
    return $res->{'id'};
}

sub random_quote {
    my ($bot) = @_;

    my $res = $bot->{'dbh'}->do(q{
        select qq.id
        from quote_quotes qq
        where not deleted
        order by random()
        limit 1
    });

    return unless $res && $res->next;
    return $res->{'id'};
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

    return $bot->{'db'}->{'nicks'}->{$sender}
        if $bot->{'db'}->{'nicks'} && $bot->{'db'}->{'nicks'}->{$sender};

    my $res = $bot->{'dbh'}->do(q{ select id from nicks where nick = ? }, $sender);

    $bot->{'db'}->{'nicks'} = {} unless $bot->{'db'}->{'nicks'};

    if ($res && $res->next) {
        $bot->{'db'}->{'nicks'}->{$sender} = $res->{'id'};

        return $res->{'id'};
    } else {
        $res = $bot->{'dbh'}->do(q{ insert into nicks (nick) values (?) returning id }, $sender);

        return unless $res && $res->next;

        $bot->{'db'}->{'nicks'}->{$sender} = $res->{'id'};

        return $res->{'id'};
    }
}

1;
