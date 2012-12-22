package RoboBot::Plugin::CPAN;

use strict;
use warnings;

use DateTime::Format::Flexible;
use JSON;
use LWP::Simple;

sub commands { qw( cpan ) }
sub usage { 'author|dist|module <name>' }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless $message =~ m{\b(a|m|d)(?:uthor|odule|ist)?\b(.*)}oi;

    my $subcommand = $1;
    my $name = $2;

    $name =~ s{(^\s+|\s+$)}{}ogs;

    return lookup_author($bot, $name) if lc($subcommand) eq 'a';
    return lookup_dist($bot, $name)   if lc($subcommand) eq 'd';
    return lookup_module($bot, $name) if lc($subcommand) eq 'm';
    return;
}

sub lookup_author {
    my ($bot, $name) = @_;

    return sprintf("The name supplied (%s) doesn't look like a CPANID to me.", $name)
        unless $name =~ m{^[A-Z0-9_-]+$}oi;

    my $res = get('http://search.cpan.org/api/author/' . $name);
    return "Error looking up author information on CPAN." unless $res;

    my $json = decode_json($res);
    return "Couldn't parse JSON response from CPAN." unless $json;

    my @sorted_releases =
        map { $_->{'distvname'} }
        sort {
            DateTime::Format::Flexible->parse_datetime($b->{'released'})
            <=>
            DateTime::Format::Flexible->parse_datetime($a->{'released'})
        } @{$json->{'releases'}};

    # limit to five more recent releases for brevity
    @sorted_releases = @sorted_releases[0..4] if scalar(@sorted_releases) > 5;

    my @r = (sprintf('%s appears to be %s', $name, $json->{'name'}));
    push(@r, sprintf('Latest releases: %s', join(', ', @sorted_releases)))
        if scalar(@sorted_releases) > 0;

    return @r;
}

sub lookup_dist {
    my ($bot, $name) = @_;

    return sprintf("%s does not look like a distribution name to me.", $name)
        unless $name =~ m{^[A-Z0-9]\w+(-\w+)*$}oi;

    my $res = get('http://search.cpan.org/api/dist/' . $name);
    return "Error looking up module information on CPAN." unless $res;

    my $json = decode_json($res);
    return "Couldn't parse JSON response from CPAN." unless $json;

    return sprintf('%s was most recently released at version %s by %s.',
        $json->{'name'},
        $json->{'releases'}->[0]->{'version'},
        $json->{'releases'}->[0]->{'cpanid'});
}

sub lookup_module {
    my ($bot, $name) = @_;

    return sprintf("%s does not look like a module name to me.", $name)
        unless $name =~ m{^[A-Z0-9]\w+(::\w+)*$}oi;

    my $res = get('http://search.cpan.org/api/module/' . $name);
    return "Error looking up module information on CPAN." unless $res;

    my $json = decode_json($res);
    return "Couldn't parse JSON response from CPAN." unless $json;

    my @r = (sprintf('%s was released by %s and is contained most recently in the distribution %s.',
                $json->{'module'}, $json->{'cpanid'}, $json->{'distvname'}));
    push(@r, sprintf('Abstract: %s', $json->{'abstract'})) if $json->{'abstract'};

    return @r;
}

1;
