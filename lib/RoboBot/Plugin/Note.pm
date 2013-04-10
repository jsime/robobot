package RoboBot::Plugin::Note;

use strict;
use warnings;

sub commands { qw( note ) }
sub usage { '[[<id> ] | list | add <text> | delete <id> | update <id> <text> ]' }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return update_note($bot, $sender, $1, $2) if $message =~ m{^\s*update\s+(\d+)\s+(.+)}oi;
    return delete_note($bot, $sender, $1) if $message =~ m{^\s*delete\s+(\d+)}oi;
    return add_note($bot, $sender, $1) if $message =~ m{^\s*add\s+(.+)}oi;
    return list_notes($bot, $sender) if $message =~ m{^\s*list}oi;
    return show_note($bot, $sender, $1) if $message =~ m{^\s*(\d+)}oi;

    return;
}

sub list_notes {
    my ($bot, $nick) = @_;

    my $res = $bot->db->do(q{
}

1;
