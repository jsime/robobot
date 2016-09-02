package RoboBot::Plugin::Help;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Text::Wrap qw( wrap );

extends 'RoboBot::Plugin';

=head1 help

Provids access to documentation and help-related functions and information for
modules, functions, and macros.

=cut

has '+name' => (
    default => 'Help',
);

has '+description' => (
    default => 'Provides help and usage information for modules, functions, and macros.',
);

=head2 help

=head3 Description

With no arguments, displays general help information about the bot, including
instructions on how to access further help.

With the name of a function or a macro (only macros defined on the current
network), displays help tailored to the function or macro, including usage
details and links to more detailed documentation. In cases where a macro and a
function have the same name, the function will always take precedence.

Lastly, module-level help may be displayed by prefacing the name of the module
with the symbol ``:module``. Module help displays the full list of exported
functions for that module.

=head3 Usage

[ :module <name> | <function> | <macro> ]

=head3 Examples

    (help)
    (help apply)
    (help :module types.map)

=cut

has '+commands' => (
    default => sub {{
        'help' => { method  => 'help',
                    usage   => '[:module <module name> | <function> | <macro>]' },
    }},
);

sub help {
    my ($self, $message, $command, $rpl, $section, @args) = @_;

    if (defined $section && $section =~ m{\w+}o) {
        if ($section =~ m{^\:?(mod(ule)|plugin)?$}oi) {
            if (@args && defined $args[0] && $args[0] =~ m{\w+}o) {
                $self->plugin_help($message, $args[0]);
            } else {
                $self->general_help($message);
            }
        } elsif (exists $self->bot->commands->{$section}) {
            $self->command_help($message, $section);
        } elsif (exists $self->bot->macros->{$message->network->id}{lc($section)}) {
            $self->macro_help($message, $section);
        } elsif (grep { lc($section) eq $_->ns } @{$self->bot->plugins}) {
            $self->plugin_help($message, $section);
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

    my %plugins = (
        map { $_->ns => 1 }
        grep { ! exists $message->network->disabled_plugins->{lc($_->name)} }
        @{$self->bot->plugins}
    );

    $message->response->push(sprintf('RoboBot v%s', $self->bot->version));
    $message->response->push(sprintf('Documentation: https://robobot.automatomatromaton.com/'));
    $message->response->push(sprintf('For additional help, use (help <function>) or (help :module "<name>").'));
    $message->response->push(sprintf('Active modules: %s', join(', ', sort keys %plugins)));

    # Return before the function display for now.
    return;

    local $Text::Wrap::columns = 200;
    my @functions = split(
        /\n/o,
        wrap( 'Available functions: ',
              '',
              join(', ',
                  sort { lc($a) cmp lc($b) }
                  grep { $_ !~ m{\w+/[^/]+$}o && !exists $message->network->disabled_plugins->{lc($self->bot->commands->{$_}->name)} }
                  keys %{$self->bot->commands}
              )
        )
    );
    $message->response->push($_) for @functions;

    return;
}

sub plugin_help {
    my ($self, $message, $plugin_name) = @_;

    my ($plugin) = (grep { $_->ns eq lc($plugin_name) } @{$self->bot->plugins});

    if (defined $plugin) {
        $message->response->push(sprintf('RoboBot Module: %s', $plugin->ns));
        $message->response->push(sprintf('Documentation: https://robobot.automatomatromaton.com/modules/%s/index.html', $plugin->ns));
        $message->response->push($plugin->description) if $plugin->has_description;
        $message->response->push(sprintf('Exports functions: %s', join(', ', sort keys %{$plugin->commands})));
    } else {
        $message->response->push(sprintf('Unknown module: %s', $plugin_name));
    }

    return;
}

sub command_help {
    my ($self, $message, $command_name, $rpl) = @_;

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

        $message->response->push(sprintf('See also: %s', join(', ', @{$metadata->{'see_also'}})))
            if exists $metadata->{'see_also'};

        $message->response->push(sprintf('Documentation: https://robobot.automatomatromaton.com/modules/%s/index.html#%s', $plugin->ns, $command_name));
    } else {
        $message->response->push(sprintf('Unknown function: %s', $command_name));
    }

    return;
}

sub macro_help {
    my ($self, $message, $macro_name) = @_;

    if (exists $self->bot->macros->{$message->network->id}{lc($macro_name)}) {
        # TODO: Extend macros to support more useful/informative documentation,
        #       possibly through a docstring like syntax, and then make use of
        #       that here. For now about all we can do is show the signature.
        my $macro = $self->bot->macros->{$message->network->id}{lc($macro_name)};

        $message->response->push(sprintf('(%s%s)',
            $macro->name,
            (length($macro->signature) > 0 ? ' ' . $macro->signature : '')
        ));
        $message->response->push(sprintf('For the complete macro definition, use: (show-macro %s)', $macro->name));
    } else {
        $message->response->push(sprintf('Unknown macro: %s', $macro_name));
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
