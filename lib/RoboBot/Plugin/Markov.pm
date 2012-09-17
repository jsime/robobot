package RoboBot::Plugin::Markov;

use strict;
use warnings;

use Lingua::EN::Tagger;

sub commands { qw( * markov ) }
sub usage { "[nick] [seed phrase]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($command && $command eq 'markov') {

    } elsif (!$command) {
        log_phrases($bot, $sender, $message);
    }

    return -1;
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

    print "Lingua Tagged Phrase:\n  $tagged\n";

    my @phrases = parse_noun_phrases(\$tagged);
    push(@phrases, parse_descriptives(\$tagged));
    push(@phrases, parse_verbs(\$tagged));
    push(@phrases, parse_misc(\$tagged));

    my %uniq;
    keys %{{ map { $_->{'word'} => $_ } @phrases}}

    save_phrase($bot, $nick_id, $_) for @phrases;
    save_sentence_form($bot, $nick_id, $tagged);
}

sub normalize_text {
    my ($text) = @_;

    $text = lc($text);

    return $text;
}

sub parse_descriptives {
    my ($text) = @_;

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

        push(@phrases, { structure => 'JP', phrase => $ph }) if scalar(@words) > 1;
        push(@phrases, { structure => 'J',  phrase => $_->{'word'} }) for @words;
    }

    return @phrases;
}

sub parse_misc {
    my ($text) = @_;

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

        push(@phrases, { structure => 'NP', phrase => $ph }) if scalar(@words) > 1;
        push(@phrases, { structure => 'N',  phrase => $_->{'word'} }) for @words;
    }

    return @phrases;
}

sub parse_verbs {
    my ($text) = @_;

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

        push(@phrases, { structure => 'VP', phrase => $ph }) if scalar(@words) > 1;
        push(@phrases, { structure => 'V',  phrase => $_->{'word'} }) for @words;
    }

    return @phrases;
}

sub save_phrase {
    my ($bot, $nick_id, $phrase) = @_;

    print "Saving phrase '$phrase->{'phrase'}' [$phrase->{'structure'}]\n";
}

sub save_sentence_form {
    my ($bot, $nick_id, $form) = @_;

    my @parts_of_speech = $form =~ m{\b([A-Z]+)\b}og;

    $form = join(' ', @parts_of_speech);

    print "Saving sentence form '$form' for nick ID $nick_id\n";
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
