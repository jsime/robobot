package RoboBot::Plugin::Help;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Text::Wrap qw( wrap );

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Help',
);

has '+description' => (
    default => 'Provides help and usage information for commands and plugins.',
);

has '+commands' => (
    default => sub {{
        'help' => { method  => 'help',
                    usage   => '[<plugin> | <command>]' },
    }},
);

sub help {
    my ($self, $message, $command, $section, @args) = @_;

    if (defined $section && $section =~ m{\w+}o) {
        if ($section =~ m{^\:?plugin$}oi) {
            if (@args && defined $args[0] && $args[0] =~ m{\w+}o) {
                $self->plugin_help($message, $args[0]);
            } else {
                $self->general_help($message);
            }
        } elsif (exists $self->bot->commands->{$section}) {
            $self->command_help($message, $section);
        } else {
            $message->response->push(sprintf('Unknown help section: %s', $section));
        }
    } else {
        $self->general_help($message);
    }

    return;
}

sub general_help {
    my ($self, $message) = @_;

    my %plugins = ( map { $_->name => 1 } @{$self->bot->plugins} );

    $message->response->push(sprintf('RoboBot v%s', $self->bot->version));
    $message->response->push(sprintf('For additional help, use (help <function>) or (help :plugin "<plugin>").'));
    $message->response->push(sprintf('Installed plugins: %s', join(', ', sort keys %plugins)));

    local $Text::Wrap::columns = 200;
    my @functions = split(/\n/o, wrap('Available functions: ','', join(', ', sort grep { $_ !~ m{\:\:}o } keys %{$self->bot->commands})));
    $message->response->push($_) for @functions;

    return;
}

sub plugin_help {
    my ($self, $message, $plugin_name) = @_;

    my ($plugin) = (grep { lc($_->name) eq lc($plugin_name) } @{$self->bot->plugins});

    if (defined $plugin) {
        $message->response->push(sprintf('RoboBot Plugin: %s', $plugin->name));
        $message->response->push($plugin->description) if $plugin->has_description;
        $message->response->push(sprintf('Exports functions: %s', join(', ', sort keys %{$plugin->commands})));
    } else {
        $message->response->push(sprintf('Unknown plugin: %s', $plugin_name));
    }

    return;
}

sub command_help {
    my ($self, $message, $command_name) = @_;

    if (exists $self->bot->commands->{$command_name}) {
        my $plugin = $self->bot->commands->{$command_name};
        my $metadata = $plugin->commands->{$command_name};

        if (exists $metadata->{'usage'} && $metadata->{'usage'} =~ m{\w+}o) {
            $message->response->push(sprintf('(%s %s)', $command_name, $metadata->{'usage'}));
        } else {
            $message->response->push(sprintf('(%s)', $command_name));
        }

        $message->response->push($metadata->{'description'}) if exists $metadata->{'description'};

        if (exists $metadata->{'example'} && exists $metadata->{'result'}) {
            $message->response->push(sprintf('Example: (%s %s) -> %s', $command_name, $metadata->{'example'}, $metadata->{'result'}));
        } elsif (exists $metadata->{'example'}) {
            $message->response->push(sprintf('Example: (%s %s)', $command_name, $metadata->{'example'}));
        }
    } else {
        $message->response->push(sprintf('Unknown function: %s', $command_name));
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
