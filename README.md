# NAME

RoboBot - An extensible IRC bot in Perl.

# VERSION

Version 0.099

# SYNOPSIS

The RoboBot module is intended to be called by a daemonized script which
will manage running a process for each server connection defined in the
configuration.

Unless you are writing your own wrapper to replace the command-line `robobot`
script, you should not need to worry about the details of the top-level
RoboBot module. Refer to RoboBot::Plugin if you are planning to write a new
plugin for the bot.

# EXPORT

RoboBot does not provide any exportable functions.

# SUBROUTINES/METHODS

## new

Instantiate a new RoboBot object. Accepts a hash of options for the bot.

RoboBot will not begin processing messages until the run() method has
also been called. See below for notes on using multiple RoboBot objects.

- config

    Path to the YAML file containing all server, channel, plugin, etc. options.
    Optional, and will default the following paths in order (only the first
    one found will be used): `~/.robobot.conf`, `~/.robobot/robobot.conf`,
    `/etc/robobot.conf`.

- server

    Specify which server in the configuration you'd like to connect to. If your
    configuration specifies either a default server, or only has a single
    server (not counting a global section), then this parameter is optional.
    However, if your configuration defines multiple servers and does not have
    a default named, you must pass in the name of the server for which you
    would like to create a RoboBot instance. Each RoboBot will connect to only
    a single server at a time, though your wrapper code (including the default
    `robobot` script included in this distribution) may create as many RoboBot
    objects as you like.

## run

Begins running the POE kernel, which will cause the configured RoboBot object
to connect to the specified server and start processing messages.

Of special note here is that if you are creating multiple bot objects, so that
you can connect to multiple IRC servers, only one of those objects needs to
have its run() method called. Since there is only a single POE kernel, it just
happens to have multiple sessions (one for each RoboBot object), you only need
to start it once.

## server

Sets the server for the RoboBot object. This will have no effect once the
object's run() method has been called.

## servers

Returns a list enumerating all of the servers defined in the configuration file.

## config

Returns a reference to the current configuration object (RoboBot::Config).

## db

Returns a reference to the current database handler (DBIx::DataStore) object
used by the bot.

## commands

Returns a sorted list of the commands supported by the bot.

# AUTHOR

Jon Sime, `<jonsime at gmail.com>`

# BUGS

Please report any bugs or feature requests to `bug-robobot at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RoboBot](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=RoboBot).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc RoboBot



You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=RoboBot](http://rt.cpan.org/NoAuth/Bugs.html?Dist=RoboBot)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/RoboBot](http://annocpan.org/dist/RoboBot)

- CPAN Ratings

    [http://cpanratings.perl.org/d/RoboBot](http://cpanratings.perl.org/d/RoboBot)

- Search CPAN

    [http://search.cpan.org/dist/RoboBot/](http://search.cpan.org/dist/RoboBot/)



# ACKNOWLEDGEMENTS



# LICENSE AND COPYRIGHT

Copyright 2013 Jon Sime.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


