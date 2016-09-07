package RoboBot::Plugin::Translate;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
use JSON;
use LWP::UserAgent;
use URI;
use XML::LibXML;

extends 'RoboBot::Plugin';

=head1 translate

Provides functions for interacting with the Microsoft Translate API. These
functions all require that the bot's configuration include proper authentication
details for the Azure Marketplace, with an active Translate API subscription.

=cut

has '+name' => (
    default => 'translate',
);

has '+description' => (
    default => 'Provides functions for interacting with the Microsoft Translate API.',
);

=head2 translate

=head3 Description

Translates the given text from the source language to the destination language.
Both the source and destination languages must be supported by the Microsoft
Translate API.

=head3 Usage

<from> <to> <text>

=head3 Examples

    :emphasize-lines: 2

    (translate "en" "de" "Good Morning!")
    Guten Morgen!

=cut

has '+commands' => (
    default => sub {{
        'translate' => { method      => 'translate_text',
                         description => 'Translates the given text from the source language to the destination language',
                         usage       => '<from> <to> <text>',
                         example     => 'en de "Good morning!"',
                         result      => '"Guten Morgen!"', },
    }},
);

has 'token' => (
    is  => 'rw',
    isa => 'Str',
);

has 'last_authed' => (
    is      => 'rw',
    isa     => 'Num',
    default => 0,
);

has 'ua' => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    default => sub {
        my $ua = LWP::UserAgent->new;
        $ua->agent('RoboBot/'.$RoboBot::VERSION.' ');
        $ua->timeout(3);
        return $ua;
    },
);

has 'valid_config' => (
    is      => 'rw',
    isa     => 'Bool',
    traits  => [qw( SetOnce )],
);

has 'cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub init {
    my ($self, $bot) = @_;

    if (exists $self->bot->config->plugins->{'translate'}{'client'}
            && exists $self->bot->config->plugins->{'translate'}{'secret'}) {
        if ($self->update_token) {
            $self->valid_config(1);
        } else {
            $self->valid_config(0);
        }
    } else {
        $self->valid_config(0);
    }
}

sub update_token {
    my ($self) = @_;

    # last_authed only changes when it was successful, so if we have a current
    # one, skip all the work ahead
    return 1 if $self->last_authed > time() - 590;

    my $client = $self->bot->config->plugins->{'translate'}{'client'};
    my $secret = $self->bot->config->plugins->{'translate'}{'secret'};

    my $response = $self->ua->post('https://datamarket.accesscontrol.windows.net/v2/OAuth2-13',
        { grant_type    => 'client_credentials',
          client_id     => $client,
          client_secret => $secret,
          scope         => 'http://api.microsofttranslator.com' });

    return 0 unless $response->is_success;

    my $json;
    eval {
        $json = decode_json($response->decoded_content);
    };
    return 0 if $@;
    return 0 unless ref($json) eq 'HASH' && exists $json->{'access_token'} && $json->{'access_token'} =~ m{HMACSHA256};

    $self->token($json->{'access_token'});
    $self->last_authed(time() +0);

    return 1;
}

sub translate_text {
    my ($self, $message, $command, $rpl, $from, $to, @args) = @_;

    unless ($self->valid_config) {
        $message->response->raise('This bot instance does not have a valid Microsoft Translate API configuration. No translations will be possible.');
        return;
    }

    unless (defined $from && defined $to && length($from) > 1 && length($to) > 1) {
        $message->response->raise('Must provide a source and destination language for translation.');
        return;
    }

    my $text = join(' ', @args);

    unless (defined $text && length($text) > 1) {
        $message->response->raise('Must provide text to translate.');
        return;
    }

    my $translation = $self->_do_translate($from, $to, $text);

    return $translation if defined $translation;

    $message->response->raise('Could not translate your phrase. Please check your source and destination languages.');
    $message->response->raise('Valid language codes are listed at https://msdn.microsoft.com/en-us/library/hh456380.aspx');
    return;
}

sub _do_translate {
    my ($self, $from, $to, $text) = @_;

    $from = lc($from);
    $to   = lc($to);
    my $key = lc($text);

    return $self->cache->{$from}{$to}{$key}
        if exists $self->cache->{$from}{$to}{$key};

    return unless $self->update_token;

    my $uri = URI->new;
    $uri->scheme('http');
    $uri->host('api.microsofttranslator.com');
    $uri->path('/v2/Http.svc/Translate');

    $uri->query_form({
        from => $from,
        to   => $to,
        text => $text,
    });

    my $req = HTTP::Request->new( GET => $uri->as_string );
    $req->header('Authorization' => sprintf('Bearer %s', $self->token));

    my $res = $self->ua->request($req);

    return unless $res->is_success;

    my $translation;

    eval {
        $translation = XML::LibXML->load_xml(
            string => $res->decoded_content
        )->getElementsByTagName("string") . "";
    };

    return if $@ || !defined $translation || length($translation) < 1;

    # TODO: This should eventually have some sort of garbage collection to keep
    #       the translation cache from growing out of control on long running
    #       bot processes.
    $self->cache->{$from}{$to}{$key} = $translation;
    return $translation;
}

__PACKAGE__->meta->make_immutable;

1;
