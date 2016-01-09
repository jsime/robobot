package RoboBot;

# ABSTRACT: Extensible multi-protocol S-Expression chatbot.

use v5.18;

use namespace::autoclean;

use Moose;
use MooseX::ClassAttribute;
use MooseX::SetOnce;

use AnyEvent;
use Data::Dumper;
use Module::Pluggable::Object;

use RoboBot::Config;
use RoboBot::Message;
use RoboBot::Plugin;

our $VERSION = '3.001001';

has 'config_paths' => (
    is        => 'ro',
    isa       => 'ArrayRef[Str]',
    predicate => 'has_config_paths',
);

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

class_has 'commands' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

class_has 'macros' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    if ($self->has_config_paths) {
        $self->config(RoboBot::Config->new( bot => $self, config_paths => $self->config_paths ));
    } else {
        $self->config(RoboBot::Config->new( bot => $self ));
    }

    $self->config->load_config;

    # Gather list of supported plugin commands (naming conflicts are considered
    # warnable offenses, not fatal errors).
    my $finder = Module::Pluggable::Object->new( search_path => 'RoboBot::Plugin', instantiate => 'new' );

    foreach my $plugin ($finder->plugins) {
        push(@{$self->plugins}, $plugin);
        $plugin->bot($self);
        $plugin->init($self);

        foreach my $command (keys %{$plugin->commands}) {
            warn sprintf("Command name collision: %s/%s superseded by %s/%s",
                         $self->commands->{$command}->ns, $command, $plugin->ns, $command)
                if exists $self->commands->{$command};

            # Offer both plain and namespaced access to individual functions
            $self->commands->{$command} = $plugin;
            $self->commands->{sprintf('%s/%s', $plugin->ns, $command)} = $plugin;
        }

        # Gather list of plugins which have before/after hooks.
        push(@{$self->before_hooks}, $plugin) if $plugin->has_before_hook;
        push(@{$self->after_hooks}, $plugin) if $plugin->has_after_hook;
    }

    # Pre-load all saved macros
    $self->macros({ RoboBot::Macro->load_all($self) });
    # TODO: This is an awful hack around the fact that nested macros get parsed incorrectly
    #       the first time around, depending on their load order out of the database. The
    #       Parser module doesn't know about their name yet, so it parses them as a String
    #       instead of a Macro object. That should get fixed in a cleaner way, but for now
    #       we can just load them a second time. All their names will be available for the
    #       Parser and we'll just overwrite their definitions with the correct versions.
    $self->macros({ RoboBot::Macro->load_all($self) });
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
    my ($self, $network, $nick, $macro_name, $args, $body) = @_;

    if (exists $self->macros->{$network->id}{$macro_name}) {
        $self->macros->{$network->id}{$macro_name}->name($macro_name);
        $self->macros->{$network->id}{$macro_name}->arguments($args);
        $self->macros->{$network->id}{$macro_name}->definition($body);
        $self->macros->{$network->id}{$macro_name}->definer($nick);

        return unless $self->macros->{$network->id}{$macro_name}->save;
    } else {
        my $macro = RoboBot::Macro->new(
            bot        => $self,
            network    => $network,
            name       => $macro_name,
            arguments  => $args,
            definition => $body,
            definer    => $nick,
        );

        return unless $macro->save;

        $self->macros->{$network->id} = {} unless exists $self->macros->{$network->id};
        $self->macros->{$network->id}{$macro->name} = $macro;
    }

    return 1;
}

sub remove_macro {
    my ($self, $network, $macro_name) = @_;

    return unless exists $self->macros->{$network->id}{$macro_name};

    $self->macros->{$network->id}{$macro_name}->delete;
    delete $self->macros->{$network->id}{$macro_name};

    return 1;
}

sub network_by_id {
    my ($self, $network_id) = @_;

    return undef unless defined $network_id && $network_id =~ m{^\d+$};
    return (grep { $_->id == $network_id } @{$self->networks})[0] || undef;
}

__PACKAGE__->meta->make_immutable;

1;
