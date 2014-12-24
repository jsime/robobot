package RoboBot::Response;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

has 'content' => (
    is        => 'rw',
    isa       => 'ArrayRef[Str]',
    predicate => 'has_content',
    clearer   => 'clear_content',
);

has 'channel' => (
    is  => 'rw',
    isa => 'RoboBot::Channel',
);

has 'nick' => (
    is  => 'rw',
    isa => 'RoboBot::Nick',
);

has 'error' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_error',
    clearer   => 'clear_error',
);

has 'bot' => (
    is  => 'ro',
    isa => 'RoboBot',
);

sub raise {
    my ($self, $format, @args) = @_;

    if (@args && @args > 0) {
        # TODO: improve handling of sprintf errors (mismatched args, etc.)
        $self->error(sprintf($format, @args));
    } else {
        $self->error($format);
    }

    $self->push("Error: " . $self->error);
    $self->send;
}

sub send {
    my ($self) = @_;

    return unless $self->has_content;

    # TODO: move the max line count for output back into config like in previous robobot
    my $n = scalar(@{$self->content});

    if ($n > 10) {
        $self->content(
            @{$self->content}[0..3],
            '... Output Truncated (' . scalar(@{$self->content}) - 7 . ' lines removed) ...',
            @{$self->content}[($n-3)..($n-1)]
        );
    }

    if ($self->channel) {
        foreach my $line (@{$self->content}) {
            $self->bot->irc->yield(
                privmsg => '#' . $self->channel->channel,
                $line
            );
        }
    } elsif ($self->nick) {
        foreach my $line (@{$self->content}) {
            $self->bot->irc->yield(
                privmsg => $self->nick->nick,
                $line
            );
        }
    }

    # We clear content that has been sent, but we do not clear the error condition
    # (if there was one), as this allows us to continue to send new output if
    # absolutely necessary while still short-circuiting most remaining evaluations
    # with a quick $response->has_error
    $self->clear_content;
}

sub push {
    my ($self, @args) = @_;

    if (@args && @args > 0) {
        if ($self->has_content) {
            push(@{$self->content}, @args);
        } else {
            $self->content(\@args);
        }
    }
}

sub pop {
    my ($self) = @_;

    if ($self->has_content) {
        return pop(@{$self->content});
    }
}

sub shift {
    my ($self) = @_;

    if ($self->has_content) {
        return shift(@{$self->content});
    }
}

sub unshift {
    my ($self, @args) = @_;

    if (@args && @args > 0) {
        if ($self->has_content) {
            unshift(@{$self->content}, @args);
        } else {
            $self->content(\@args);
        }
    }
}

__PACKAGE__->meta->make_immutable;

1;
