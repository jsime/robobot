package RoboBot::Plugin::FakeQuote;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'FakeQuote',
);

has '+description' => (
    default => 'Constructs fake quotes from (fictional?) personalities, based on pre-canned phrases and randomized substitutions.',
);

has '+commands' => (
    default => sub {{
        'fake-quote' => { method      => 'fake_quote',
                          description => 'Generates a fake quote either by the personality specified, otherwise by one chosen at random.',
                          usage       => '[<personality>]', },

        'add-fake-personality' => { method      => 'add_fake_person',
                                    description => 'Adds a new fake personality with the given name.',
                                    usage       => '<name>', },

        'add-fake-quote' => { method      => 'add_fake_quote',
                              description => 'Adds a fake quote phrase to the given personality, optionally including placeholders to use for randomized substitutions.',
                              usage       => '<personality> "<phrase>"',
                              example     => 'joe "I like {food}!"', },

        'add-fake-substitution' => { method      => 'add_fake_term',
                                     description => 'Adds a term to the list of possible substitutions when generating phrases for the given personality. The <type> should match the string used when including placeholders in (add-fake-quote) phrases. Multiple terms may be specified, as long as they are all for the same <type>.',
                                     usage       => '<personality> <type> "<term>" [<term2> ...]',
                                     example     => 'joe food "apple pie" "blueberry icecream" "hard gravel"', },
    }},
);

sub fake_quote {
    my ($self, $message, $command, $rpl, $personality) = @_;

    my $res;

    if (defined $personality) {
        $res = $self->bot->config->db->do(q{
            select id, name
            from fakequotes_people
            where lower(name) = lower(?)
        }, $personality);
    } else {
        $res = $self->bot->config->db->do(q{
            select id, name
            from fakequotes_people
            order by random() desc
            limit 1
        });
    }

    unless ($res && $res->next) {
        $message->response->raise('Could not locate a suitable personality for generating a fake quote.');
        return;
    }

    my ($person_id, $name) = ($res->{'id'}, $res->{'name'});

    $res = $self->bot->config->db->do(q{
        select id, phrase
        from fakequotes_phrases
        where person_id = ?
        order by random() desc
        limit 1
    }, $person_id);

    unless ($res && $res->next) {
        $message->response->raise('The personality %s has no phrases. I cannot generate a fake quote without any phrases.', $name);
        return;
    }

    my $phrase = $res->{'phrase'};

    my %term_types;
    # We start this off holding counters for how many unique terms of each type
    # to collect from the database. Once we run that query, we change it over
    # to contain an arrayref of the collected terms (including duplicates, if
    # necessary to meet the count).
    $term_types{$_}++ for $phrase =~ m|{([^}]+)}|g;

    foreach my $type (keys %term_types) {
        my @terms;

        # We'll repeat the query (assuming it doesn't came back with 0 results,
        # since that will trigger an error) until we have enough of the terms
        # of this type to meet the quota, in a randomized order each time.
        while (@terms < $term_types{$type}) {
            $res = $self->bot->config->db->do(q{
                select term
                from fakequotes_terms
                where person_id = ? and lower(term_type) = lower(?)
                order by random() desc
                limit ?
            }, $person_id, $type, $term_types{$type});

            unless ($res && $res->count > 0) {
                $message->response->raise('Cannot locate enough {%s} terms for %s to construct the fake quote. Please try again or add more terms.', $type, $name);
                return;
            }

            while ($res->next) {
                push(@terms, $res->{'term'});
            }
        }

        $term_types{$type} = \@terms;
    }

    # Switch out all the placeholders now with the randomized terms.
    $phrase =~ s|{([^}]+)}| shift(@{$term_types{$1}}) // "" |eg;

    # Send along the faked quote for any further processing.
    return sprintf('<%s> %s', $name, $phrase);
}

sub add_fake_person {
    my ($self, $message, $command, $rpl, $personality, $suppress_output) = @_;

    return unless defined $personality;

    my $res = $self->bot->config->db->do(q{
        select id
        from fakequotes_people
        where lower(name) = lower(?)
    }, $personality);

    if ($res && $res->next) {
        $message->response->push(sprintf('The personality %s already exists.', $personality))
            unless defined $suppress_output;
        return;
    }

    $res = $self->bot->config->db->do(q{
        insert into fakequotes_people (name) values (?) returning *
    }, $personality);

    unless ($res && $res->next) {
        $message->response->raise('Could not create the new personality %s. Please try again.', $personality);
        return;
    }

    $message->response->push(sprintf('New personality %s has been added.', $personality))
        unless defined $suppress_output;
    return;
}

sub add_fake_quote {
    my ($self, $message, $command, $rpl, $personality, $phrase) = @_;

    unless (defined $personality && defined $phrase && $personality =~ m{\w+} && $phrase =~ m{\w+}) {
        $message->response->raise('You must provide both a personality name and a fake quote phrase.');
        return;
    }

    $self->add_fake_person($message, $command, $personality, 1);

    my $res = $self->bot->config->db->do(q{
        insert into fakequotes_phrases (person_id, phrase) values (
            (select id from fakequotes_people where lower(name) = lower(?)),
            ?
        )
        returning *
    }, $personality, $phrase);

    if ($res && $res->next) {
        $message->response->push('Fake quote phrase has been added.');
    } else {
        $message->response->raise('Could not add the fake quote phrase. Please try again.');
    }

    return;
}

sub add_fake_term {
    my ($self, $message, $command, $rpl, $personality, $type, @terms) = @_;

    unless (defined $personality && defined $type && $personality =~ m{\w+} && $type =~ m{\w+}) {
        $message->response->raise('You must provide both a personality name and a term type.');
        return;
    }

    if (@terms) {
        @terms = grep { defined $_ && $_ =~ m{\w+} } @terms;
    }

    unless (@terms && @terms > 0) {
        $message->response->raise('You must supply at least one term.');
        return;
    }

    $self->add_fake_person($message, $command, $personality, 1);

    foreach my $term (@terms) {
        $self->bot->config->db->do(q{
            insert into fakequotes_terms (person_id, term_type, term) values (
                (select id from fakequotes_people where lower(name) = lower(?)),
                ?,?
            )
        }, $personality, $type, $term);
    }

    $message->response->push(sprintf('New Term%s added for %s.', (@terms == 1 ? '' : 's'), $personality));
    return;
}

__PACKAGE__->meta->make_immutable;

1;
