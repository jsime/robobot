package RoboBot::Plugin;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

has 'name' => (
    is  => 'ro',
    isa => 'Str',
);

has 'description' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_description',
);

has 'commands' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { return {} },
);

has 'before_hook' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_before_hook',
);

has 'after_hook' => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_after_hook',
);

has 'bot' => (
    is     => 'rw',
    isa    => 'RoboBot',
    traits => [qw( SetOnce )],
);

sub init {
    my ($self, $bot) = @_;
}

sub process {
    my ($self, $message, $command, @args) = @_;

    # Remove namespace from command if present (by the time we reach this point, we
    # already know what plugin namespace we're in)
    if ($command =~ m{\:\:(.*)$}) {
        $command = $1;
    }

    return $message->response->raise("Invalid command processor executed.")
        unless exists $self->commands->{$command};

    my $method = $self->commands->{$command}{'method'};

    # Ensure that the nick is permitted to call the function.
    if (exists $message->sender->denied_functions->{$command}) {
        return $message->response->raise('You are not permitted to call the function (%s).', $command);
    }

    # By default, we pre-process all arguments, but some plugins can opt out
    # of this to handle things like conditional evaluations or loops
    unless (exists $self->commands->{$command}{'preprocess_args'} && $self->commands->{$command}{'preprocess_args'} == 0) {
        my @processed_args;

        # TODO this duplicates code from RoboBot.pm in process_list (which this even
        # calls) -- they should be get refactored to use a common set of list
        # processing code instead (especially for clean handling of variables)
        foreach my $arg (@args) {
            if (ref($arg) eq 'ARRAY') {
                push(@processed_args, $message->process_list($arg));
            } else {
                if (exists $message->vars->{$arg}) {
                    if (ref($message->vars->{$arg}) eq 'ARRAY') {
                        push(@processed_args, $message->process_list($arg));
                    } else {
                        push(@processed_args, $message->vars->{$arg});
                    }
                } else {
                    push(@processed_args, $arg);
                }
            }
        }

        @args = @processed_args;
    }

    return $self->$method($message, $command, @args);
}

sub hook_before {
    my ($self, $message) = @_;

    return $message unless $self->has_before_hook;

    my $hook = $self->before_hook;
    return $self->$hook($message);
}

sub hook_after {
    my ($self, $message) = @_;

    return $message unless $self->has_after_hook;

    my $hook = $self->after_hook;
    return $self->$hook($message);
}

sub extract_keyed_args {
    my ($self, @args) = @_;

    my %keyed = ();
    my @remaining;

    while (@args) {
        my $k = shift(@args);
        if (substr($k, 0, 1) eq ':') {
            $keyed{substr($k, 1)}
                = @args && substr($args[0], 0, 1) ne ':'
                ? shift(@args)
                : 1;
        } else {
            push(@remaining, $k);
        }
    }

    return (\%keyed, @remaining);
}

__PACKAGE__->meta->make_immutable;

1;
