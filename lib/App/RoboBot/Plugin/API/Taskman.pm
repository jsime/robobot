package App::RoboBot::Plugin::API::Taskman;

use v5.20;

use namespace::autoclean;

use Moose;

use HTTP::Request;
use JSON;
use LWP::UserAgent;
use URI;

extends 'App::RoboBot::Plugin';

=head1 api.taskman

Provides functions for interacting with OmniTI's task tracking system.

In addition to exported functions, this module inserts a pre-hook into the
message processing pipeline which looks for any substrings matching the
regular expression ``tid(\d+)`` and automatically replies with a direct link to
the Taskman post(s) mentioned.

=cut

has '+name' => (
    default => 'API::Taskman',
);

has '+description' => (
    default => 'Provides functions for interacting with OmniTI\'s task tracking system.',
);

has '+before_hook' => (
    default => 'check_tids',
);

=head2 tid

=head3 Description

Displays task summary for the given ID.

=head3 Usage

<task ID>

=cut

has '+commands' => (
    default => sub {{
        'tid' => { method      => 'show_tid',
                   description => 'Displays task summary for the given ID.',
                   usage       => '<task id>' },
    }},
);

has 'ua' => (
    is      => 'rw',
    isa     => 'LWP::UserAgent',
    default => sub {
        my $ua = LWP::UserAgent->new;
        $ua->agent('App::RoboBot');
        $ua->timeout(5);
        return $ua;
    },
);

has 'valid_config' => (
    is  => 'rw',
    isa => 'Bool',
);

has 'api_host' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'taskman.omniti.com',
);

has 'api_user' => (
    is  => 'rw',
    isa => 'Str',
);

has 'api_password' => (
    is  => 'rw',
    isa => 'Str',
);

has 'allowed_networks' => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);

sub init {
    my ($self, $bot) = @_;

    if (exists $self->bot->config->plugins->{'taskman'}{'host'}
            && exists $self->bot->config->plugins->{'taskman'}{'user'}
            && exists $self->bot->config->plugins->{'taskman'}{'password'}) {
        $self->valid_config(1);

        $self->api_user($self->bot->config->plugins->{'taskman'}{'user'});
        $self->api_password($self->bot->config->plugins->{'taskman'}{'password'});
    } else {
        $self->valid_config(0);
    }

    if (exists $self->bot->config->plugins->{'taskman'}{'network'}) {
        if (ref($self->bot->config->plugins->{'taskman'}{'network'}) eq 'ARRAY') {
            foreach my $n (@{$self->bot->config->plugins->{'taskman'}{'network'}}) {
                push(@{$self->allowed_networks}, $n);
            }
        } else {
            $self->allowed_networks([$self->bot->config->plugins->{'taskman'}{'network'}]);
        }
    }

    $self->api_host($self->bot->config->plugins->{'taskman'}{'host'})
        if exists $self->bot->config->plugins->{'taskman'}{'host'};
}

sub show_tid {
    my ($self, $message, $command, $rpl, $tid) = @_;

    return unless defined $tid && $tid =~ m{^\d+$}o;

    # Prevent leakage of internal task details to networks that aren't privy to them.
    return unless grep { lc($_) eq lc($message->network->name) } @{$self->allowed_networks};

    $message->response->push(sprintf('[%d] https://%s/task/%d',
        $tid,
        $self->api_host,
        $tid));

    # Short circuit if we don't have a valid API configuration to get task details.
    return unless $self->valid_config;

    my $uri = URI->new;
    $uri->scheme('https');
    $uri->host($self->api_host);
    $uri->path_segments(qw( rest api ));

    $uri->query_form({
        action => 'get_task',
        tid    => $tid,
    });

    my $req = HTTP::Request->new( GET => $uri->as_string );
    $req->authorization_basic($self->api_user, $self->api_password);

    my $response = $self->ua->request($req);
    return unless $response->is_success;

    my $json;
    eval {
        $json = decode_json($response->decoded_content);
    };
    return if $@;
    return unless defined $json && ref($json) eq 'HASH';
    return unless exists $json->{'status'} && $json->{'status'} eq 'success';

    $message->response->push(sprintf('*Name*: %s', $json->{'data'}{'name'}));
    $message->response->push(sprintf('*Client*: %s', $json->{'data'}{'client_name'}))
        if exists $json->{'data'}{'client_name'};
    $message->response->push(sprintf('*Contract*: %s', $json->{'data'}{'default_contract'}))
        if exists $json->{'data'}{'default_contract'};

    return;
}

sub check_tids {
    my ($self, $message) = @_;

    return if $message->has_expression;

    # Try to avoid duplicating links. If a TID appears to be present, but the message
    # already included a taskman URL, keep quiet.
    return if $message->raw =~ m{https?://taskman};

    my $msg = $message->raw;

    while ($msg =~ m{tid\s*(\d+)}gi) {
        $self->show_tid($message, 'tid', $1);
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
