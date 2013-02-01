package RoboBot;

use v5.10;
use strict;
use warnings;

use DBIx::DataStore config => 'yaml';
use Module::Pluggable require => 1;
use POE;
use POE::Component::IRC;
use Time::HiRes qw( usleep );

use RoboBot::Config;

=head1 NAME

RoboBot - An extensible IRC bot in Perl.

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

The RoboBot module is intended to be called by a daemonized script which
will manage running a process for each server connection defined in the
configuration.

Unless you are writing your own wrapper to replace the command-line C<robobot>
script, you should not need to worry about the details of the top-level
RoboBot module. Refer to RoboBot::Plugin if you are planning to write a new
plugin for the bot.

=head1 EXPORT

RoboBot does not provide any exportable functions.

=head1 SUBROUTINES/METHODS

=head2 new

Instantiate a new RoboBot object. Accepts a hash of options for the bot.

RoboBot will not begin processing messages until the run() method has
also been called. See below for notes on using multiple RoboBot objects.

=over 4

=item * config

Path to the YAML file containing all server, channel, plugin, etc. options.
Optional, and will default the following paths in order (only the first
one found will be used): C<~/.robobot.conf>, C<~/.robobot/robobot.conf>,
C</etc/robobot.conf>.

=item * server

Specify which server in the configuration you'd like to connect to. If your
configuration specifies either a default server, or only has a single
server (not counting a global section), then this parameter is optional.
However, if your configuration defines multiple servers and does not have
a default named, you must pass in the name of the server for which you
would like to create a RoboBot instance. Each RoboBot will connect to only
a single server at a time, though your wrapper code (including the default
C<robobot> script included in this distribution) may create as many RoboBot
objects as you like.

=back

=cut

sub new {
    my ($class, %args) = @_;

    my $self = { plugins => [] };

    $self->{'config'} = RoboBot::Config->new(
        path    => $args{'config'} || '',
        server  => $args{'server'} || ''
    );

    my $obj = bless $self, $class;

    return $obj unless $args{'server'};

    ($obj->{'irc'}) = POE::Component::IRC->spawn();

    push(@{$obj->{'plugins'}}, $_) for $obj->plugins;

    POE::Session->create(
        object_states => [
            $obj => {
                _start      => "on_start",
                irc_001     => "on_connect",
                irc_msg     => "on_message",
                irc_public  => "on_message",
            }
        ],
        options => { trace => 0, debug => 0 },
    );

    $obj->{'dbh'} = DBIx::DataStore->new('robobot');

    return $obj;
}

=head2 run

Begins running the POE kernel, which will cause the configured RoboBot object
to connect to the specified server and start processing messages.

Of special note here is that if you are creating multiple bot objects, so that
you can connect to multiple IRC servers, only one of those objects needs to
have its run() method called. Since there is only a single POE kernel, it just
happens to have multiple sessions (one for each RoboBot object), you only need
to start it once.

=cut

sub run {
    my ($self) = @_;

    $poe_kernel->run();
}

=head2 server

Sets the server for the RoboBot object. This will have no effect once the
object's run() method has been called.

=cut

sub server {
    my ($self, $server) = @_;

    die "No server name provided!\n" unless $server;

    return $self->{'config'}->server($server);
}

=head2 servers

Returns a list enumerating all of the servers defined in the configuration file.

=cut

sub servers {
    my ($self) = @_;

    return $self->{'config'}->servers();
}

=head2 config

Returns a reference to the current configuration object (RoboBot::Config).

=cut

sub config {
    my ($self) = @_;

    return unless exists $self->{'config'} && ref($self->{'config'}) eq 'RoboBot::Config';
    return $self->{'config'};
}

=head2 db

Returns a reference to the current database handler (DBIx::DataStore) object
used by the bot.

=cut

sub db {
    my ($self) = @_;

    return unless exists $self->{'dbh'} && ref($self->{'dbh'}) eq 'DBIx::DataStore';
    return $self->{'dbh'};
}

=head2 commands

Returns a sorted list of the commands supported by the bot.

=cut

sub commands {
    my ($self) = @_;

    return @{$self->{'commands'}} if exists $self->{'commands'} && ref($self->{'commands'}) eq 'ARRAY';

    my %cmds;

    foreach my $plugin ($self->plugins) {
        next unless $plugin->can('commands');
        $cmds{$_} = 1 for grep { $_ =~ m{\w+}o } $plugin->commands;
    }

    # remove the wildcard command
    delete $cmds{'*'} if exists $cmds{'*'};

    $self->{'commands'} = [sort keys %cmds];
    return @{$self->{'commands'}};
}

sub on_start {
    my ($self) = ($_[OBJECT]);

    $self->{'irc'}->yield( register => 'all' );

    $self->{'irc'}->yield(
        connect => {
            Nick     => $self->{'config'}->nick() || 'RoboBot',
            Username => $self->{'config'}->username() || 'robobot',
            Ircname  => "RoboBot (POE::Component::IRC) Bot v$VERSION",
            Server   => $self->{'config'}->host(),
            Port     => $self->{'config'}->port(),
            UseSSL   => $self->{'config'}->ssl() || 0,
            Flood    => 1, # can be dangerous, but we limit our output elsewhere
        }
    );
}

sub on_connect {
    my ($self) = ($_[OBJECT]);

    my $res = $self->db->do(q{ select id from servers where name = ? }, $self->{'config'}->server());

    if ($res && $res->next) {
        $self->{'db'} = { server_id => $res->{'id'}, channels => {} };
    } else {
        $res = $self->db->do(q{ insert into servers (name) values (?) returning id }, $self->{'config'}->server());

        die "Could not create a DB record for server " . $self->{'config'}->server() unless $res && $res->next;

        $self->{'db'} = { server_id => $res->{'id'}, channels => {} };
    }

    if ($self->{'config'}->username() && $self->{'config'}->password()) {
        $self->{'irc'}->yield(
            privmsg => 'userserv',
            sprintf('login %s %s', $self->{'config'}->username(), $self->{'config'}->password())
        );
    }

    foreach my $channel ($self->{'config'}->channels()) {
        $self->{'irc'}->yield( join => $channel );

        $res = $self->db->do(q{
            select id
            from channels
            where server_id = ? and name = ?
        }, $self->{'db'}->{'server_id'}, $channel);

        if ($res && $res->next) {
            $self->{'db'}->{'channels'}->{$channel} = $res->{'id'};
        } else {
            $res = $self->db->do(q{
                insert into channels ??? returning id
            }, { server_id => $self->{'db'}->{'server_id'},
                 name      => $channel,
            });

            die "Could not create a DB record for channel $channel on server " . $self->{'config'}->server()
                unless $res && $res->next;

            $self->{'db'}->{'channels'}->{$channel} = $res->{'id'};
        }
    }
}

sub on_message {
    my ($self, $kernel, $who, $where, $message) = @_[OBJECT, KERNEL, ARG0, ARG1, ARG2];

    my $sender_nick = (split(/!/, $who))[0];
    my $channel = $where->[0];

    $message =~ s{(^\s+|\s+$)}{}ogs;

    my $msg_time = time();
    my $msg_time_date = sprintf('%d-%02d-%02d', (localtime($msg_time))[5] + 1900, (localtime($msg_time))[4,3]);
    my $msg_time_time = sprintf('%02d:%02d:%02d', (localtime($msg_time))[2,1,0]);

    printf("%s %s [%s] <%s> %s\n", $msg_time_date, $msg_time_time, $channel, $sender_nick, $message);

    # set up skeleton of output options, with defaults
    my %options = (
        to          => $channel,
        msg_limit   => $self->{'config'}->msglimit(),
        msg_per_sec => $self->{'config'}->msgrate(),
    );

    # skip if it's us -- we don't want robobot talking to itself
    return if lc($who) eq lc($self->{'config'}->nick());

    # skip if it's GitHub, since we don't want to spam the channel with URLs and misspellings
    return if $who =~ m{GitHub\d+}o;

    my $direct_to;

    # check if the output should be redirected to a specific nick (or list of nicks)
    if ($message =~ m{>\s*(\#?\w+(?:[, ]+\#?\w+)*)\s*$}o) {
        $direct_to = $1;
        $direct_to =~ s{[, ]+}{, }og;

        # and remove it from the message
        $message =~ s{>\s*(\#?\w+(?:[, ]+\#?\w+)*)\s*$}{}o;
    }

    my @parts = split(m{\|}o, $message);
    my (@output, @output_opts);

    MESSAGE_PART:
    foreach my $msg_part (@parts) {
        $msg_part =~ s{(^\s+|\s+$)}{}ogs;
        $msg_part = join(' ', grep { $_ =~ m{\w+}o } ($msg_part, @output)) if scalar(@output) > 0;

        my $command;

        if ($msg_part =~ m{^\s*\!(\w+)(.*)}o) {
            ($command, $msg_part) = (lc($1), $2);
        } else {
            $command = '';
        }

        $msg_part =~ s{(^\s+|\s+$)}{}ogs;
        $command =~ s{(^\s+|\s+$)}{}ogs;

        # short circuit if "!help <plugin>" was issued in any message part
        if ($command && $command eq 'help') {
            @output = $self->help($msg_part);
            last MESSAGE_PART;
        } elsif ($command) {
            # make sure the nick sending the message has permission to use it
            unless (RoboBot::Plugin::Auth::has_permission($self, $command, $sender_nick)) {
                @output = (sprintf('You do not have permission to use the !%s command. Self-destruct initiated...',
                    $command));
                last MESSAGE_PART;
            }
        }

        PLUGIN:
        foreach my $plugin (@{$self->{'plugins'}}) {
            next PLUGIN unless $plugin->can('commands');
            next PLUGIN unless grep { $_ eq '*' || $command eq $_} $plugin->commands();

            next PLUGIN unless $plugin->can('handle_message');
            my @t_output = $plugin->handle_message($self, $sender_nick, $channel, $command, $message, $msg_time, $msg_part);

            # skip usage errors for plugins which don't produce output when using catch-all '*' commands
            next PLUGIN if scalar(@t_output) == 1 && $t_output[0] eq '-1';

            # if the first element of the plugin's output array is a hashref,
            # shift it from the list and keep it for later merging as options
            push(@output_opts, shift @t_output)
                if scalar(@t_output) > 0 && ref($t_output[0]) eq 'HASH';

            unless (@t_output && scalar(grep { $_ =~ m{\w+}o } @t_output) > 0) {
                if ($plugin->can('usage')) {
                    @output = ("Usage: \!$command " . $plugin->usage());
                } else {
                    @output = ("Unknown command error, and plugin provided no usage information.");
                }
                last MESSAGE_PART;
            }

            @output = @t_output;
        }
    }

    # iterate through the returned options from each plugin, in order, with
    # the most recent taking precedence (i.e. if two plugins both returned
    # the "to" option to override normal output destination, then the second
    # one to do so is the one whose destination is used).
    foreach my $optset (@output_opts) {
        foreach my $opt (keys %{$optset}) {
            $options{$opt} = $optset->{$opt};
        }
    }

    # check first if a plugin has overridden the default recipient (which would be
    # the current channel), then check if this was a private message to us. if it
    # is a private message to the bot, and there is no direct_to then we send the
    # output back to the sender, otherwise we send it to direct_to -- and if this
    # wasn't a private message to us, it just goes back to the channel we
    # received it in.
    if ($options{'to'} && $options{'to'} ne $channel) {
        $channel = $options{'to'};
        $direct_to = '';
    } elsif (lc($channel) eq lc($self->{'config'}->nick())) {
        $channel = $direct_to && length($direct_to) > 0 ? $direct_to : $sender_nick;
        $direct_to = '';
    } else {
        $direct_to = "$direct_to: " if $direct_to && length($direct_to) > 0;
    }

    if (@output && scalar(grep { $_ =~ m{\w+}o } @output) > 0) {
        my $resp_time = time();
        my $resp_time_date = sprintf('%d-%02d-%02d', (localtime($resp_time))[5] + 1900, (localtime($resp_time))[4,3]);
        my $resp_time_time = sprintf('%02d:%02d:%02d', (localtime($resp_time))[2,1,0]);

        printf("%s %s [%s] <%s> %s\n",
            $resp_time_date, $resp_time_time,
            $channel, $self->{'config'}->nick(),
            ($direct_to && length($direct_to) > 0 ? "$direct_to$_" : $_)
        ) for grep { $_ =~ m{\w+}o } @output;

        # honor the message limit option, and append a message indicating that the
        # output has been truncated if it exceeds that limit
        @output = (@output[0..($options{'msg_limit'} - 1)], '... Output truncated ...')
            if scalar(@output) > $options{'msg_limit'};

        foreach my $line (@output) {
            $self->{'irc'}->yield(
                privmsg => $channel,
                ($direct_to && length($direct_to) > 0 ? "$direct_to$line" : $line)
            );

            # sleep appropriate number of microseconds in a minor attempt at not
            # flooding the channel/recipient, based on the messages-per-second
            # option
            usleep(1 / $options{'msg_per_sec'} * 1_000_000);
        }
    }
}

sub help {
    my ($self, $message) = @_;

    $message =~ s{(^\s+|\s+$)}{}og;
    $message =~ s{\!}{}og;

    my @output = ();

    if ($message && $message =~ /\w+/o) {
        foreach my $plugin (@{$self->{'plugins'}}) {
            if ($plugin->can('commands') && $plugin->can('usage')) {
                if (grep { lc($message) eq $_ } $plugin->commands()) {
                    return "Usage: \!$message " . $plugin->usage();
                }
            }
        }

        return "No help found for command: $message";
    } else {
        my %commands;

        foreach my $plugin (@{$self->{'plugins'}}) {
            if ($plugin->can('commands')) {
                $commands{lc($_)} = $plugin for grep { $_ ne '*' } $plugin->commands();
            }
        }

        if (scalar(keys(%commands)) > 0) {
            push(@output, 'Use "!help <command>" for more help. Commands available: '
                . join(' ', sort keys %commands));
        } else {
            return "I don't seem to have any plugins loaded.";
        }
    }

    push(@output, q{Commands may be chained together, each passing on their output to the next, by } .
        q{separating each command with a "|" character (much like Bash). This has no effect for } .
        q{commands which don't operate on input.});
    push(@output, q{The final output of your command may also be addressed to individuals in the } .
        q{channel by appending the entire command sequence with "> nick[, nick, ...]" so that } .
        q{their clients may highlight the messages for easier recognition.});

    return @output;
}

=head1 AUTHOR

Jon Sime, C<< <jonsime at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-robobot at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RoboBot>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RoboBot


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=RoboBot>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/RoboBot>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/RoboBot>

=item * Search CPAN

L<http://search.cpan.org/dist/RoboBot/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Jon Sime.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of RoboBot
