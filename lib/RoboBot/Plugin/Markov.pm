package RoboBot::Plugin::Markov;

use strict;
use warnings;

use Lingua::EN::Tagger;

sub commands { qw( * markov ) }
sub usage { "<nick> [seed phrase]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command && lc($command) eq 'markov') {
        return build_phrase($bot, $message);
    } elsif (!$command) {
        log_phrases($bot, $sender, $message);
    }

    return -1;
}

sub build_phrase {
    my ($bot, $message) = @_;

    return -1 unless $message =~ m{^(\w+)\b(.*)}o;

    my $nick = $1;
    my $seed_phrase = $2;

    my $nick_id = sender_nick_id($bot, $nick);

    return unless $nick_id;

    my ($res);

    $seed_phrase = normalize_text($seed_phrase) if $seed_phrase;

    $seed_phrase = pick_seed_phrase($bot, $nick_id) unless $seed_phrase;

    if ($seed_phrase) {
        $res = $bot->db->do(q{
            select structure, phrase
            from markov_phrases
            where nick_id = ? and phrase = ?
        }, $nick_id, $seed_phrase);

        unless ($res && $res->next) {
            return 'Seed phrase not found for specified nick.';
        }

        my $sentence_form = pick_sentence_form($bot, $nick_id, $res->{'structure'});

        return 'Seed phrase resulted in no usable sentence forms.' unless $sentence_form;

        return make_seeded_phrase($bot, $nick, $nick_id, $sentence_form, $res->{'structure'}, $res->{'phrase'});
    }
}

sub pick_seed_phrase {
    my ($bot, $nick_id) = @_;

    my $res = $bot->db->do(q{
        select phrase
        from markov_phrases
        where nick_id = ?
        order by cos(log((used_count * 2) + 1)) * random() desc
        limit 1
    }, $nick_id);

    return unless $res && $res->next;
    return $res->{'phrase'};
}

sub make_seeded_phrase {
    my ($bot, $nick, $nick_id, $form, $seed_form, $seed) = @_;

    my @words = split(/\s+/, $form);

    my %structure_counts;
    $structure_counts{$_}++ for @words;

    my (@queries, @binds);

    foreach my $structure (keys %structure_counts) {
        push(@queries, qq{
            select *
            from (  select structure, phrase
                    from markov_phrases
                    where nick_id = ? and structure = ?
                    order by cos(log((used_count * 2) + 1)) * random() desc
                    limit ?
                ) xd_$structure
        });
        push(@binds, $nick_id, $structure, $structure_counts{$structure});
    }

    my $res = $bot->db->do(join(' union all ', @queries), @binds);

    return unless $res;

    # make sure the seed phrase gets in there
    $form =~ s/\b$seed_form\b/$seed/;

    while ($res->next) {
        $form =~ s/\b$res->{'structure'}\b/$res->{'phrase'}/;
    }

    # remove remaining placeholders
    $form =~ s/\b[A-Z]+\b//og;

    $form = normalize_text($form);

    return "<$nick> $form";
}

sub pick_sentence_form {
    my ($bot, $nick_id, $phrase_structure) = @_;

    my $res = $bot->db->do(q{
        select structure
        from markov_sentence_forms
        where nick_id = ? and structure ~ ?
        order by cos(log((used_count * 2) + 1)) * random() desc
        limit 1
    }, $nick_id, '\m' . $phrase_structure . '\M');

    return unless $res && $res->next;
    return $res->{'structure'};
}

sub log_phrases {
    my ($bot, $sender, $message) = @_;

    # we don't want to put the words of one person into another's history, so if it looks
    # like they had pasted in something from elsewhere, skip logging it
    return if $message =~ m{^\<[ \w]+\>\s+}o;       # irc messages
    return if $message =~ m{\d+:\d+(\s+\w+)+:\s+}o; # some IM clients
    return if $message =~ m{\b\w+/(NN|JJ|DET|IN|PRP|RB|VB)}o; # already parsed text

    # we can't log it if we don't know who it was for
    my $nick_id = sender_nick_id($bot, $sender);
    return unless $nick_id;

    $message = normalize_text($message);

    my $tagger = Lingua::EN::Tagger->new();
    my $tagged = $tagger->get_readable($message);

    my @phrases = parse_noun_phrases(\$tagged);
    push(@phrases, parse_descriptives(\$tagged));
    push(@phrases, parse_verbs(\$tagged));
    push(@phrases, parse_misc(\$tagged));

    save_phrase($bot, $nick_id, $_) for @phrases;
    save_sentence_form($bot, $nick_id, $tagged);
}

sub normalize_text {
    my ($text) = @_;

    $text = lc($text);
    $text =~ s{\s+}{ }ogs;
    $text =~ s{(^\s+|\s+$)}{}ogs;

    return $text;
}

sub parse_descriptives {
    my ($text) = @_;

    return unless defined $$text;

    my @phrases = ();

    my @ap = $$text =~ m{
        \b(
            (?: \w+/JJR? \s*)+
        )\b
    }ogx;

    foreach my $ph (@ap) {
        $ph =~ s{(^\s+|\s+$)}{}og;
        $$text =~ s{$ph}{J}g;

        my @words = grep { $_->{'type'} }
            map { $_ =~ m{\b(\w+)/(\w+)\b}o ? { type => $2, word => $1 } : {} }
            split(/\s+/, $ph);

        $ph = join(' ', map { $_->{'word'} } @words);

        push(@phrases, { structure => 'J', phrase => $ph }) if scalar(@words) > 1;
        push(@phrases, { structure => 'J',  phrase => $_->{'word'} }) for @words;
    }

    return @phrases;
}

sub parse_misc {
    my ($text) = @_;

    return unless defined $$text;

    my @phrases = ();

    my @words = grep { $_->{'type'} && $_->{'type'} !~ m{^(PP.?|POS)$}o }
        map { $_ =~ m{\b(\w+)/([A-Z]+)\b}o ? { type => $2, word => $1 } : {} }
        split(/\s+/, $$text);

    foreach my $word (@words) {
        $$text =~ s|$word->{'word'}/$word->{'type'}|$word->{'type'}|og;

        $word->{'word'} = 'not' if $word->{'word'} eq "n't"; # fixup from parsing
    }

    push(@phrases, { structure => $_->{'type'},  phrase => $_->{'word'} }) for @words;

    return @phrases;
}

sub parse_noun_phrases {
    my ($text) = @_;

    return unless defined $$text;

    my @phrases = ();

    my @np = $$text =~ m{
        \b(
            (?: \w+/NNS? \s*)+
        )\b
    }ogx;

    foreach my $ph (@np) {
        $ph =~ s{(^\s+|\s+$)}{}og;
        $$text =~ s{$ph}{N}g;

        my @words = grep { $_->{'type'} }
            map { $_ =~ m{\b(\w+)/(\w+)\b}o ? { type => $2, word => $1 } : {} }
            split(/\s+/, $ph);

        $ph = join(' ', map { $_->{'word'} } @words);

        push(@phrases, { structure => 'N', phrase => $ph }) if scalar(@words) > 1;
        push(@phrases, { structure => 'N',  phrase => $_->{'word'} }) for @words;
    }

    return @phrases;
}

sub parse_verbs {
    my ($text) = @_;

    return unless defined $$text;

    my @phrases = ();

    my @np = $$text =~ m{
        \b(
            (?: \w+/VB.? \s*)+
        )\b
    }ogx;

    foreach my $ph (@np) {
        $ph =~ s{(^\s+|\s+$)}{}og;
        $$text =~ s{$ph}{V}g;

        my @words = grep { $_->{'type'} }
            map { $_ =~ m{\b(\w+)/(\w+)\b}o ? { type => $2, word => $1 } : {} }
            split(/\s+/, $ph);

        $ph = join(' ', map { $_->{'word'} } @words);

        push(@phrases, { structure => 'V', phrase => $ph }) if scalar(@words) > 1;
        push(@phrases, { structure => 'V',  phrase => $_->{'word'} }) for @words;
    }

    return @phrases;
}

sub save_phrase {
    my ($bot, $nick_id, $phrase) = @_;

    my $res = $bot->db->do(q{
        update markov_phrases
        set used_count = used_count + 1
        where nick_id = ? and phrase = ?
        returning id
    }, $nick_id, $phrase->{'phrase'});

    return if $res && $res->next;

    $res = $bot->db->do(q{
        insert into markov_phrases ??? returning id
    }, { nick_id    => $nick_id,
         structure  => $phrase->{'structure'},
         phrase     => $phrase->{'phrase'},
         used_count => 1,
    });
}

sub save_sentence_form {
    my ($bot, $nick_id, $form) = @_;

    return unless defined $form;

    my @parts_of_speech = $form =~ m{\b([A-Z]+)\b}og;

    $form = join(' ', @parts_of_speech);

    my $res = $bot->db->do(q{
        update markov_sentence_forms
        set used_count = used_count + 1
        where nick_id = ? and structure = ?
        returning id
    }, $nick_id, $form);

    return if $res && $res->next;

    $res = $bot->db->do(q{
        insert into markov_sentence_forms ??? returning id
    }, { nick_id    => $nick_id,
         structure  => $form,
         used_count => 1,
    });
}

sub sender_nick_id {
    my ($bot, $sender) = @_;

    $sender =~ s{\_+$}{}og;

    return $bot->{'db'}{'nicks'}{$sender}
        if $bot->{'db'}{'nicks'} && $bot->{'db'}{'nicks'}{$sender};

    my $res = $bot->db->do(q{ select id from nicks where lower(nick) = lower(?) }, $sender);

    $bot->{'db'}{'nicks'} = {} unless $bot->{'db'}{'nicks'};

    if ($res && $res->next) {
        $bot->{'db'}{'nicks'}{$sender} = $res->{'id'};

        return $res->{'id'};
    } else {
        $res = $bot->db->do(q{ insert into nicks (nick) values (?) returning id }, $sender);

        return unless $res && $res->next;

        $bot->{'db'}{'nicks'}{$sender} = $res->{'id'};

        return $res->{'id'};
    }
}

1;
