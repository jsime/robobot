package App::RoboBot::Plugin::Bot::Message;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

extends 'App::RoboBot::Plugin';

=head1 bot.message

Provides functions to access details and metadata for the current message
context.

=cut

has '+name' => (
    default => 'Bot::Message',
);

has '+description' => (
    default => 'Provides functions to access details and metadata for the current message context.',
);

=head2 msg-channel

=head3 Description

Returns the name of the channel for the current message context. If the message
was sent via direct message or does not have a channel for any other reason,
this function will return nil.

=head2 msg-text

=head3 Description

Returns the contents of the message context in which the function is evaluated.
This is useful within features such as auto-repliers, which are evaluated in
the context of the incoming message, as it allows matching functions to look
for relevant keywords, for example.

=head3 Usage

=head3 Examples

=head2 msg-sender

Returns the name of the sender for the message context in which the function is
evaluated. In situations where (msg-sender) is used as part of an auto-replier,
this function provides access to the name of the person who sent the message
currently being processed.

=cut

has '+commands' => (
    default => sub {{
        'msg-channel' => { method => 'message_channel' },
        'msg-text'    => { method => 'message_message' },
        'msg-sender'  => { method => 'message_sender' },
    }},
);

sub message_channel {
    my ($self, $message, $comman, $rpl) = @_;

    return $message->channel->name if $message->has_channel;
    return;
}

sub message_message {
    my ($self, $message, $command, $rpl) = @_;

    return $message->raw;
}

sub message_sender {
    my ($self, $message, $command, $rpl) = @_;

    return $message->sender->name;
}

__PACKAGE__->meta->make_immutable;

1;
