package RoboBot::Plugin::URLs;

use strict;
#use warnings FATAL => 'all';
use warnings;

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

use HTML::TreeBuilder::LibXML;
use LWP::UserAgent;
use Text::Levenshtein qw( distance );
use URI::Find;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'URLs',
);

has '+description' => (
    default => 'Provides functions related to URLs.',
);

has '+before_hook' => (
    default => 'check_urls',
);

has '+commands' => (
    default => sub {{
        'shorten-url' => { method      => 'shorten_url',
                           description => 'Returns a short version of a URL for easier sharing.',
                           usage       => '"<url>"',
                           example     => '"http://images.google.com/really-long-image-url.jpg?with=plenty&of=tracking&arguments=foo123"',
                           result      => 'http://tinyurl.com/foObar42' },
    }},
);

has 'ua' => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    default => sub {
        LWP::UserAgent->new(
            agent        => "RoboBot/v".$RoboBot::VERSION." ",
            timeout      => 3,
            max_redirect => 5,
            ssl_opts => {
                verify_hostname => 0,
            },
            protocols_allowed => [qw( http https )],
        );
    },
);

sub check_urls {
    my ($self, $message) = @_;

    return if $message->has_expression;

    my @urls = $self->find_urls($message);

    foreach my $url (@urls) {
        my $r = $self->ua->get($url);

        if ($r->is_success) {
            my $title = $self->get_title($r);

            if (defined $title && length($title) > 0 && $title =~ m{\w+}o) {
                $title =~ s{\s+}{ }ogs;
                $title =~ s{(^\s+|\s+$)}{}ogs;

                $message->response->push(sprintf('Title: %s', $title));
            }

            if (scalar($r->redirects) > 0) {
                my $redir = ($r->redirects)[-1];

                # Limit notification of redirects to only those which differ from the
                # original URL by a distance of greater than 10% of the length of
                # original URL. This prevents some odd issues from reporting a
                # redirect to the same URL.
                if (distance($url, $redir) >= length($url) * 0.10) {
                    $message->response->push(sprintf('Redirected to: %s', $redir->base));
                }
            }
        }

        # TODO add URL logging and the "Last Seen:" output from the old plugin version
    }
}

sub shorten_url {
    my ($self, $message, $command, $url) = @_;

    return unless defined $url && length($url) > 0;

    # TODO actually shorten the URLs

    return $url;
}

sub find_urls {
    my ($self, $message) = @_;

    my $text = $message->raw;

    my @uris;
    my $finder = URI::Find->new(sub {
        my($uri) = shift;
        push @uris, $uri;
    });
    $finder->find(\$text);

    return @uris;
}

sub get_title {
    my ($self, $r) = @_;

    my $tree = HTML::TreeBuilder::LibXML->new;
    $tree->parse($r->decoded_content);
    $tree->eof;

    my @values = $tree->findvalue('//head/title');

    if (@values && scalar(@values) > 0) {
        return $values[0];
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
