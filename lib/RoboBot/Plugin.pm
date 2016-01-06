package RoboBot::Plugin;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Data::Dumper;
use Scalar::Util qw( blessed );

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

sub ns {
    my ($self) = @_;

    my $ns = lc($self->name);
    $ns =~ s{::}{.}g;

    return $ns;
}

sub process {
    my ($self, $message, $command, $rpl, @args) = @_;

    # Remove namespace from command if present (by the time we reach this point, we
    # already know what plugin namespace we're in)
    if ($command =~ m{/(.*)$}) {
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
        # TODO: There are much better ways of deciding how to pass a symbol
        #       that happens to have the name of a function as a function, or
        #       as a string, than this.
        my $pass_funcs = exists $self->commands->{$command}{'take_funcs'} && $self->commands->{$command}{'take_funcs'} == 1 ? 1 : 0;

        my @new_args;

        foreach my $arg (@args) {
            if (blessed($arg) && $arg->can('evaluate')) {
                if (($arg->type eq 'Function' || $arg->type eq 'Macro') && !$pass_funcs) {
                    push(@new_args, $arg->value);
                } else {
                    push(@new_args, $arg->evaluate($message, $rpl));
                }
            } else {
                push(@new_args, $arg);
            }
        }

        @args = @new_args;
    }

    return $self->$method($message, $command, $rpl, @args);
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
