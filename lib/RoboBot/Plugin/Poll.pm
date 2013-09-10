package RoboBot::Plugin::Poll;

use strict;
use warnings;

sub commands { qw( poll vote ) }
sub usage { ("!poll new Ask a question? [1] Choice 1 [2] Choice 2 ...","!poll close","!vote n") }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command eq 'poll') {
        if ($message =~ m{^\s*new\s+([^\?]+)\?\s+(.+)$}o) {
            return add_poll($bot, $sender, $1, $2);
        } elsif ($message =~ m{^\s*close\s*}o) {
            return close_poll($bot, $sender);
        } else {
            return poll_status($bot);
        }
    } elsif ($command eq 'vote') {
        if ($message =~ m{^\s*(\d+)\s*$}o) {
            return vote($bot, $sender, $1);
        }
    }
}

sub add_poll {
    my ($bot, $sender, $question, $choices) = @_;

    $question =~ s{(^\s+|\s+$)}{}ogs;

    return sprintf('No question was provided.') unless length($question) > 0;

    my $res = $bot->db->do(q{
        select p.*
        from poll_polls p
        where p.closed_at is null
    });

    my %choices;

    while ($choices =~ m{\s*\[(\d+)\]\s+([^\[]+)}og) {
        my ($num, $choice) = ($1, $2);
        $choice =~ s{(^\s+|\s+$)}{}ogs;

        $choices{$num} = $choice;
    }

    return sprintf('Could not figure out what your choices were. Please include them at the end of the command as "[1] Choice [2] Choice ... [n] Choice".') unless scalar keys %choices > 0;
    return sprintf('It is pointless to have a poll with only one option.') if scalar keys %choices == 1;

    if ($res && $res->next) {
        return sprintf('There is still a poll open. You cannot create a new one until it is closed.');
    }

    $res = $bot->db->do(q{
        insert into poll_polls
            ( question, nick_id )
        values
            ( ?, ( select id from nicks where lower(nick) = lower(?) ))
        returning poll_id
    }, "$question?", $sender);

    if ($res && $res->next) {
        my $poll_id = $res->{'poll_id'};

        $res = $bot->db->do(q{
            insert into poll_choices ???
        }, [map { { poll_id => $poll_id, choice_num => $_, choice => $choices{$_} } } keys %choices]);

        return sprintf('Polling has opened! %s has asked: %s?', $sender, $question),
               sprintf('Choices: %s', join(', ', map { sprintf('%d: %s', $_, $choices{$_}) } sort { $a <=> $b } keys %choices)),
               sprintf('Vote with: !vote [num]');
    }
}

sub close_poll {
    my ($bot, $sender) = @_;

    my $poll = $bot->db->do(q{
        update poll_polls
        set closed_at = now()
        where closed_at is null
            and nick_id = ( select id from nicks where lower(nick) = lower(?) )
        returning *
    }, $sender);

    if ($poll && $poll->next) {
        my @output = (sprintf('The poll "%s" has been closed. The results:', $poll->{'question'}));

        my $res = $bot->db->do(q{
            select c.choice,
                coalesce((select max(length(choice)) from poll_choices where poll_id = ?), 16) as len,
                count(distinct(v.nick_id)) as votes
            from poll_choices c
                left join poll_votes v using (poll_id, choice_num)
            where c.poll_id = ?
            group by c.choice
            order by 3 desc
        }, $poll->{'poll_id'}, $poll->{'poll_id'});

        if ($res) {
            while ($res->next) {
                push(@output, sprintf('  %-'.$res->{'len'}.'s >> %d', $res->{'choice'}, $res->{'votes'}));
            }
        }

        return @output;
    }

    return sprintf('Failed to close any polls.');
}

sub poll_status {
    my ($bot) = @_;

    my $poll = $bot->db->do(q{
        select p.*, n.nick
        from poll_polls p
            join nicks n on (n.id = p.nick_id)
        where p.closed_at is null
        order by p.created_at desc
        limit 1
    });

    if ($poll && $poll->next) {
        my @output = (sprintf('The current poll is "%s" by %s. The results:', $poll->{'question'}, $poll->{'nick'}));

        my $res = $bot->db->do(q{
            select c.choice, c.choice_num,
                coalesce((select max(length(choice)) from poll_choices where poll_id = ?), 16) as len,
                count(distinct(v.nick_id)) as votes
            from poll_choices c
                left join poll_votes v using (poll_id, choice_num)
            where c.poll_id = ?
            group by c.choice, c.choice_num
            order by 4 desc
        }, $poll->{'poll_id'}, $poll->{'poll_id'});

        if ($res) {
            while ($res->next) {
                push(@output, sprintf('  [%2d] %-'.$res->{'len'}.'s >> %d', $res->{'choice_num'}, $res->{'choice'}, $res->{'votes'}));
            }
        }
        push(@output, sprintf('Vote with: !vote [num]'));

        return @output;
    }

    return sprintf('No open polls could be found. Maybe you would like to start one?');
}

sub vote {
    my ($bot, $sender, $choice) = @_;

    my $res = $bot->db->do(q{
        insert into poll_votes
            ( nick_id, poll_id, choice_num )
        values
            ( (select id from nicks where lower(nick) = lower(?)),
              (select poll_id from poll_polls where closed_at is null),
              ?)
        returning *
    }, $sender, $choice);

    if ($res && $res->next) {
        return sprintf('%s: Your vote has been registered.', $sender);
    }

    return sprintf('%s: An error occurred while processing your vote. Please make sure you have chosen a valid option from the current poll.', $sender);
}


1;
