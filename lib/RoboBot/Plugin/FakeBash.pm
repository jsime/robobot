package RoboBot::Plugin::FakeBash;

use strict;
use warnings;

sub commands { qw( * ) }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    if ($message =~ m{^\s*ls\s*$}oi) {
        return fake_ls();
    } elsif ($message =~ m{^\s*cd\s*([a-z0-9/_-]+)?}oi) {
        return fake_cd($1);
    }

    return -1;
}

sub fake_ls {
    return 'backups  cache  crash  lib  local  lock  log  mail  metrics  opt  run  spool  tmp';
}

sub fake_cd {
    my ($dir) = @_;

    $dir = defined $dir && length($dir) > 0 ? "$dir: " : '';

    return sprintf('bash: cd: %sNo such file or directory', $dir);
}

1;
