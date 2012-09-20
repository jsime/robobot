package RoboBot;

use v5.10;
use strict;
use warnings;

use DBIx::DataStore config => 'yaml';
use Module::Pluggable require => 1;
use POE;
use POE::Component::IRC;

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

    print "Creating new POE session for $args{'server'}...\n";

    POE::Session->create(
        object_states => [
            $obj => {
                _start      => "on_start",
                irc_001     => "on_connect",
                irc_public  => "on_message",
            }
        ],
        options => { trace => 0, debug => 0 },
    );

    $obj->{'dbh'} = DBIx::DataStore->new('robobot');

    print "Done creating session.\n";

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

sub on_start {
    my ($self) = ($_[OBJECT]);

    print "Received on_start event, preparing to connect to server: " . $self->{'config'}->host() . "\n";

    $self->{'irc'}->yield( register => 'all' );

    $self->{'irc'}->yield(
        connect => {
            Nick     => $self->{'config'}->nick() || 'RoboBot',
            Username => $self->{'config'}->username() || 'robobot',
            Ircname  => "RoboBot (POE::Component::IRC) Bot v$VERSION",
            Server   => $self->{'config'}->host(),
            Port     => $self->{'config'}->port(),
            UseSSL   => $self->{'config'}->ssl() || 0,
        }
    );
}

sub on_connect {
    my ($self) = ($_[OBJECT]);

    my $res = $self->{'dbh'}->do(q{ select id from servers where name = ? }, $self->{'config'}->server());

    if ($res && $res->next) {
        $self->{'db'} = { server_id => $res->{'id'}, channels => {} };
    } else {
        $res = $self->{'dbh'}->do(q{ insert into servers (name) values (?) returning id }, $self->{'config'}->server());

        die "Could not create a DB record for server " . $self->{'config'}->server() unless $res && $res->next;

        $self->{'db'} = { server_id => $res->{'id'}, channels => {} };
    }

    foreach my $channel ($self->{'config'}->channels()) {
        $self->{'irc'}->yield( join => $channel );

        print "Joining $channel on " . $self->{'config'}->server() . "...\n";

        $res = $self->{'dbh'}->do(q{
            select id
            from channels
            where server_id = ? and name = ?
        }, $self->{'db'}->{'server_id'}, $channel);

        if ($res && $res->next) {
            $self->{'db'}->{'channels'}->{$channel} = $res->{'id'};
        } else {
            $res = $self->{'dbh'}->do(q{
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
    my $msg_time = time();

    print "Got message: $message\n  from: $sender_nick\n  channel: $channel\n";

    # skip if it's us -- we don't want robobot talking to itself
    return if lc($who) eq lc($self->{'config'}->nick());

    my $direct_to;

    # check if the output should be redirected to a specific nick (or list of nicks)
    if ($message =~ m{>\s*(\w+(?:[, ]+\w+)*)\s*$}o) {
        $direct_to = $1;
        $direct_to =~ s{[, ]+}{, }og;

        # and remove it from the message
        $message =~ s{>\s*(\w+(?:[, ]+\w+)*)\s*$}{}o;
    }

    my @parts = split(m{\|}o, $message);

    my @output;

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
        }

        PLUGIN:
        foreach my $plugin (@{$self->{'plugins'}}) {
            next PLUGIN unless $plugin->can('commands');
            next PLUGIN unless grep { $_ eq '*' || $command eq $_} $plugin->commands();

            next PLUGIN unless $plugin->can('handle_message');
            my @t_output = $plugin->handle_message($self, $sender_nick, $channel, $command, $message, $msg_time, $msg_part);

            # skip usage errors for plugins which don't produce output when using catch-all '*' commands
            next PLUGIN if scalar(@t_output) == 1 && $t_output[0] eq '-1';

            print "Got output from plugin $plugin:\n";
            print " => $_\n" for @t_output;

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

    if (@output && scalar(grep { $_ =~ m{\w+}o } @output) > 0) {
        $self->{'irc'}->yield(
            privmsg => $channel,
            ($direct_to && length($direct_to) > 0 ? "$direct_to: $_" : $_)
        ) for grep { $_ =~ m{\w+}o } @output;
    }
}

sub help {
    my ($self, $message) = @_;

    $message =~ s{(^\s+|\s+$)}{}og;
    $message =~ s{\!}{}og;

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
            return 'Use "!help <command>" for more help. Commands available: '
                . join(' ', sort keys %commands);
        } else {
            return "I don't seem to have any plugins loaded.";
        }
    }
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

Copyright 2012 Jon Sime.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of RoboBot
