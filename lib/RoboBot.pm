package RoboBot;

use v5.18;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use AnyEvent;
use Data::Dumper;
use Module::Pluggable::Object;

use RoboBot::Config;
use RoboBot::Message;
use RoboBot::Plugin;

our $VERSION = '2.001001';

has 'config' => (
    is     => 'rw',
    isa    => 'RoboBot::Config',
    traits => [qw( SetOnce )],
);

has 'plugins' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has 'commands' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'macros' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has 'before_hooks' => (
    is        => 'rw',
    isa       => 'ArrayRef',
    predicate => 'run_before_hooks',
    default   => sub { [] },
);

has 'after_hooks' => (
    is        => 'rw',
    isa       => 'ArrayRef',
    predicate => 'run_after_hooks',
    default   => sub { [] },
);

has 'networks' => (
    is      => 'rw',
    isa     => 'ArrayRef[RoboBot::Network]',
    default => sub { [] },
);

sub BUILD {
    my ($self) = @_;

    $self->config(RoboBot::Config->new( bot => $self ))->load_config;

    # Gather list of supported plugin commands (naming conflicts are considered
    # warnable offenses, not fatal errors).
    my $finder = Module::Pluggable::Object->new( search_path => 'RoboBot::Plugin', instantiate => 'new' );

    foreach my $plugin ($finder->plugins) {
        push(@{$self->plugins}, $plugin);
        $plugin->bot($self);
        $plugin->init($self);

        foreach my $command (keys %{$plugin->commands}) {
            warn sprintf("Command name collision: %s::%s superseded by %s::%s",
                         $self->commands->{$command}->name, $command, $plugin->name, $command)
                if exists $self->commands->{$command};

            # Offer both plain and namespaced access to individual functions
            $self->commands->{$command} = $plugin;
            $self->commands->{sprintf('%s::%s', lc($plugin->name), $command)} = $plugin;
        }

        # Gather list of plugins which have before/after hooks.
        push(@{$self->before_hooks}, $plugin) if $plugin->has_before_hook;
        push(@{$self->after_hooks}, $plugin) if $plugin->has_after_hook;
    }

    # Pre-load all saved macros
    $self->macros({ RoboBot::Macro->load_all($self->config) });
}

sub run {
    my ($self) = @_;

    my $c = AnyEvent->condvar;
    $_->connect for @{$self->networks};
    $c->recv;
    $_->disconnect for @{$self->networks};
}

sub version {
    my ($self) = @_;

    return $VERSION;
}

sub add_macro {
    my ($self, $nick, $macro_name, $args, $body) = @_;

    if (exists $self->macros->{$macro_name}) {
        $self->macros->{$macro_name}->name("$macro_name");
        $self->macros->{$macro_name}->arguments($args);
        $self->macros->{$macro_name}->definition($body);
        $self->macros->{$macro_name}->definer($nick);

        return unless $self->macros->{$macro_name}->save;
    } else {
        my $macro = RoboBot::Macro->new(
            config     => $self->config,
            name       => "$macro_name",
            arguments  => $args,
            definition => $body,
            definer    => $nick,
        );

        return unless $macro->save;

        $self->macros->{$macro->name} = $macro;
    }

    return 1;
}

sub remove_macro {
    my ($self, $macro_name) = @_;

    return unless exists $self->macros->{$macro_name};

    $self->macros->{$macro_name}->delete;
    delete $self->macros->{$macro_name};

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
