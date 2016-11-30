package App::RoboBot;

# ABSTRACT: Extensible multi-protocol S-Expression chatbot.

use v5.18;

use namespace::autoclean;

use Moose;
use MooseX::ClassAttribute;
use MooseX::SetOnce;

use AnyEvent;
use App::Sqitch;
use Data::Dumper;
use File::ShareDir qw( dist_dir );
use Module::Pluggable::Object;

use App::RoboBot::Config;
use App::RoboBot::Message;
use App::RoboBot::Plugin;

use App::RoboBot::Doc;

has 'config_paths' => (
    is        => 'ro',
    isa       => 'ArrayRef[Str]',
    predicate => 'has_config_paths',
);

has 'config' => (
    is        => 'rw',
    isa       => 'App::RoboBot::Config',
    traits    => [qw( SetOnce )],
    predicate => 'has_config',
);

has 'raw_config' => (
    is        => 'ro',
    isa       => 'HashRef',
    predicate => 'has_raw_config',
);

has 'plugins' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has 'doc' => (
    is     => 'rw',
    isa    => 'App::RoboBot::Doc',
    traits => [qw( SetOnce )],
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
    isa     => 'ArrayRef[App::RoboBot::Network]',
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

    $self->doc(App::RoboBot::Doc->new( bot => $self ));

    if ($self->has_raw_config) {
        $self->config(App::RoboBot::Config->new( bot => $self, config => $self->raw_config ));
    } else {
        if ($self->has_config_paths) {
            $self->config(App::RoboBot::Config->new( bot => $self, config_paths => $self->config_paths ));
        } else {
            $self->config(App::RoboBot::Config->new( bot => $self ));
        }
    }

    $self->config->load_config;

    # Gather list of supported plugin commands (naming conflicts are considered
    # warnable offenses, not fatal errors).
    my $finder = Module::Pluggable::Object->new( search_path => 'App::RoboBot::Plugin', instantiate => 'new' );

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

    # Two-phase plugin initialization's second phase now called, so that plugins
    # which require knowledge of the existence of commands/macros/etc. can see
    # that (it having been done already in the first phase). This is critical
    # for plugins which use things like App::RoboBot::Parser to parse stored
    # expressions.
    foreach my $plugin (@{$self->plugins}) {
        $plugin->post_init($self);
    }

    # Pre-load all saved macros
    $self->macros({ App::RoboBot::Macro->load_all($self) });
    # TODO: This is an awful hack around the fact that nested macros get parsed incorrectly
    #       the first time around, depending on their load order out of the database. The
    #       Parser module doesn't know about their name yet, so it parses them as a String
    #       instead of a Macro object. That should get fixed in a cleaner way, but for now
    #       we can just load them a second time. All their names will be available for the
    #       Parser and we'll just overwrite their definitions with the correct versions.
    $self->macros({ App::RoboBot::Macro->load_all($self) });
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

    use vars qw( $VERSION );

    return $VERSION // "*-devel";
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
        my $macro = App::RoboBot::Macro->new(
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

sub migrate_database {
    my ($self) = @_;

    my $migrations_dir = dist_dir('App-RoboBot') . '/migrations';
    die "Could not locate database migrations (remember to use `dzil run` during development)!"
        unless -d $migrations_dir;

    my $cfg = $self->config->config->{'database'}{'primary'};

    my $db_uri = 'db:pg://';
    $db_uri .= $cfg->{'user'} . '@' if $cfg->{'user'};
    $db_uri .= $cfg->{'host'} if $cfg->{'host'};
    $db_uri .= ':' . $cfg->{'port'} if $cfg->{'port'};
    $db_uri .= '/' . $cfg->{'database'} if $cfg->{'database'};

    chdir($migrations_dir) or die "Could not chdir() $migrations_dir: $!";

    open(my $status_fh, '-|', 'sqitch', 'status', $db_uri) or die "Could not check database status: $!";
    while (my $l = <$status_fh>) {
        return if $l =~ m{up-to-date};
    }
    close($status_fh);

    open(my $deploy_fh, '-|', 'sqitch', 'deploy', '--verify', $db_uri) or die "Could not begin database migrations: $!";
    while (my $l = <$deploy_fh>) {
        if ($l =~ m{^\s*\+\s*(.+)\s+\.\.\s+(.*)$}) {
            die "Failed during database migration $1.\n" if lc($2) ne 'ok';
        }
    }
    close($deploy_fh);
}

__PACKAGE__->meta->make_immutable;

1;
