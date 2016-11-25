package RoboBot::Plugin::Bot::Autoreply;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
use RoboBot::Parser;
use Scalar::Util qw( blessed );
use Try::Tiny;

extends 'RoboBot::Plugin';

=head1 bot.autoreply

Provides functions which allow the creation of rules to be evaluated against
incoming messages (and their metadata) and potentially trigger the execution of
expressions in response when those conditions are met.

=cut

has '+name' => (
    default => 'Bot::Autoreply',
);

has '+description' => (
    default => 'Provides functions which allow for conditionally evaluated expressions in response to incoming messages.',
);

has '+before_hook' => (
    default => 'autoreply_check',
);

has 'parser' => (
    is  => 'rw',
    isa => 'RoboBot::Parser',
);

has 'reply_cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

=head2 autoreply

=head3 Description

=head3 Usage

<name> (<condition expression>) (<response expression>)

=head3 Examples

    (autoreply "im-down" (match "qtiyd" (bot.messages/message)) (str "^"))

=cut

has '+commands' => (
    default => sub {{
        'autoreply' => { method          => 'autoreply_create',
                         preprocess_args => 0,
                         description     => 'Creates an autoreplier with the given condition and response expressions.',
                         usage           => '<name> (<condition expression>) (<response expression>)' },
    }},
);

sub post_init {
    my ($self, $bot) = @_;

    $self->parser( RoboBot::Parser->new( bot => $bot ) );

    my $res = $bot->config->db->do(q{
        select *
        from autoreply_autoreplies
    });

    while ($res->next) {
        try {
            $self->reply_cache->{$res->{'channel_id'}}{$res->{'name'}} = {
                condition   => $self->parser->parse($res->{'condition'}),
                response    => $self->parser->parse($res->{'response'}),
            };
        } catch {
            warn sprintf("Could not initialize autoreply %s: %s", $res->{'name'}, $_);
        }
    }
}

sub autoreply_check {
    my ($self, $message) = @_;

    return if $message->has_expression;

    return unless $message->has_channel;
    return unless exists $self->reply_cache->{$message->channel->id};

    my $raw_text = $message->raw;

    my $check_message = RoboBot::Message->new(
        bot     => $self->bot,
        raw     => $raw_text,
        network => $message->channel->network,
        sender  => $message->sender,
        channel => $message->channel,
    );

    foreach my $name (sort keys %{$self->reply_cache->{$message->channel->id}}) {
        my $reply = $self->reply_cache->{$message->channel->id}{$name};

        $check_message->raw($raw_text);
        $check_message->expression($reply->{'condition'});

        my $ret = $reply->{'condition'}->evaluate($check_message, {});

        if ($ret) {
            $message->response->push(
                $reply->{'response'}->evaluate($check_message, {})
            );
        }
    }
}

sub autoreply_create {
    my ($self, $message, $command, $rpl, $name, $condition, $response) = @_;

    unless (defined $name && defined $condition && defined $response) {
        $message->response->raise('Must provide an autoreplier name, condition expression, and response expression.');
        return;
    }

    if (blessed($name) && $name->can('evaluate')) {
        $name = $name->evaluate($message, $rpl);

        if (ref($name)) {
            $message->response->raise('Autoreplier name expression must evaluate to a string.');
            return;
        }
    } else {
        $name = "$name";
    }

    if (ref($name) || $name !~ m{\w+}) {
        $message->response->raise('Must provide an autoreplier name.');
        return;
    }

    unless (blessed($condition) && $condition->can('evaluate')) {
        $message->response->raise('Must provide an expression for the autoreply condition.');
        return;
    }

    unless (blessed($response) && $response->can('evaluate')) {
        $message->response->raise('Must provide an expression for the autoreply response.');
        return;
    }

    $condition->quoted(0);
    $response->quoted(0);

    my $res = $self->bot->config->db->do(q{
        update autoreply_autoreplies set ??? where channel_id = ? and name = ? returning *
    }, {
        condition  => $condition->flatten,
        response   => $response->flatten,
        created_by => $message->sender->id,
        created_at => 'now',
    }, $message->channel->id, $name);

    if ($res && $res->next) {
        $message->response->push(sprintf('Autoreply %s has been updated.', $name));
    } else {
        $res = $self->bot->config->db->do(q{
            insert into autoreply_autoreplies ??? returning *
        }, {
            channel_id  => $message->channel->id,
            name        => $name,
            condition   => $condition->flatten,
            response    => $response->flatten,
            created_by  => $message->sender->id,
        });

        if ($res && $res->next) {
            $message->response->push(sprintf('Autoreply %s has been added.', $name));
        } else {
            $message->response->raise('Could not create the autoresponse. Please check your arguments and try again.');
            return;
        }
    }

    $self->reply_cache->{$message->channel->id}{$name} = {
        condition   => $condition,
        response    => $response,
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;
