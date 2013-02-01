package RoboBot::Plugin;

# This module does nothing. It is only a placeholder for the POD on how
# to write your own RoboBot plugins.

=head1 Writing RoboBot Plugins

Adding new functionality to RoboBot is (hopefully) quite easy. RoboBot uses
Module::Pluggable, and will automatically load anything in your library path
under the RoboBot::Plugin::* namespace.

=head1 Naming Your Plugin

It is recommended that you name the module after its primary command, though
that's only a general recommendation and flexibility is allowed for those
modules offering multiple commands.

=head1 Required Class Methods

Plugin modules are used by RoboBot by calling a defined set of class methods.
Your plugin must implement at least two of them, and it is strongly recommended
that it implements all three.

=head2 Method: commands

Required.

Arguments: None.

Returns: List of IRC !commands for which this plugin will be invoked.

Example:

    package RoboBot::Plugin::Quote;
    sub commands { qw( quote ) }

The commands are case-insensitive, but partial matches are not supported. There
is one special command '*' which is used to indicate your plugin should be
invoked for every IRC message (this can be useful for logging plugins).

=head2 Method: handle_message

Required.

Arguments:

=over 4

=item * Class

Your plugin's __PACKAGE__.

=item * Bot

Fully instantiated RoboBot object for the current context, with an active
DBIx::DataStore database handler returned by $bot->db().

=back

=head2 Method: usage

Optional.

Arguments: None.

Returns: Message line to be displayed in the same context in which a !help
command was issued. The message will be preceded by the specific command the
user requested help on (in case your plugin offers multiple commands).

Example:

    package RoboBot::Plugin::Fortune;
    sub commands { qw( fortune ) }
    sub usage { q{[ <category> ]} }

And the resulting exchange in an IRC channel might look like:

    #channel> !help fortune
    <RoboBot> Usage: !fortune [ <category> ]

=cut

1;
