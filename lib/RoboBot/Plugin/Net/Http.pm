package RoboBot::Plugin::Net::Http;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
use LWP::UserAgent;
use URI;
use URI::QueryParam;

extends 'RoboBot::Plugin';

=head1 net.http

Exports a selection of functions for performing HTTP/HTTPS operations.

=cut

has '+name' => (
    default => 'Net::Http',
);

has '+description' => (
    default => 'Provides a selection of functions for performing HTTP/HTTPS operations.',
);

=head2 http-get

=head3 Description

Retrieves an HTTP/HTTPS document at the specified URL and returns its content.

=head3 Usage

<url>

=head3 Examples

    :emphasize-lines: 2

    (http-get "http://hasthelargehadroncolliderdestroyedtheworldyet.com/")
    "NOPE."

=cut

has '+commands' => (
    default => sub {{
        'http-get' => { method      => 'http_get',
                        description => 'Retrieves an HTTP/HTTPS document at the specified URL and returns its content.',
                        usage       => '<url>',
                        example     => '"http://hasthelargehadroncolliderdestroyedtheworldyet.com/"',
                        result      => '"NOPE."' },

        'http-head' => { method      => 'http_headers',
                         description => 'Returns a map of response headers obtained via a HEAD request to the given URL.',
                         usage       => '<url>',
                         example     => '"http://google.com/"',
                         result      => '{ Server "gws" Content-Length 219 Cache-Control "public, max-age=2592000" ... }' },

        'query-string' => { method      => 'http_query_string',
                            description => 'Converts the given map into an HTTP URI query string (excluding the leading question mark).',
                            usage       => '<map>',
                            example     => '{ :id 123 :foo ["bar", "baz"] }',
                            result      => '"id=123&foo=bar&foo=baz"' },
    }},
);

has 'ua' => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    default => sub { my $ua = LWP::UserAgent->new(); $ua->timeout(3); $ua; },
);

sub http_get {
    my ($self, $message, $command, $rpl, $url) = @_;

    unless (defined $url && length($url) > 0) {
        $message->response->raise('Must provide a valid URL.');
        return;
    }

    my $response = $self->ua->get($url);

    if ($response->is_success) {
        return $response->decoded_content;
    }

    $message->response->raise("Could not GET %s: %s", $url, $response->status_line);
    return;
}

sub http_headers {
    my ($self, $message, $command, $rpl, $url) = @_;

    unless (defined $url && length($url) > 0) {
        $message->response->raise('Must provide a valid URL.');
        return;
    }

    my $response = $self->ua->head($url);

    if ($response->is_success) {
        my $h = $response->headers();

        my $headers = {};
        foreach my $name (sort { lc($a) cmp lc($b) } $h->header_field_names) {
            $headers->{$name} = "" . $h->header($name);
        }
        return $headers;
    }

    $message->response->raise("Could not HEAD %s: %s", $url, $response->status_line);
    return;
}

sub http_query_string {
    my ($self, $message, $command, $rpl, $params) = @_;

    unless (defined $params) {
        # Don't error out on empty params list, just return a blank query string
        return '';
    }

    unless (ref($params) eq 'HASH') {
        $message->response->raise('Must provide a balanced map (a valid set of key-value pairs).');
        return;
    }

    my $uri = URI->new('', 'http');

    foreach my $k (keys %{$params}) {
        $uri->query_param($k, $params->{$k});
    }

    return $uri->query;
}

__PACKAGE__->meta->make_immutable;

1;
