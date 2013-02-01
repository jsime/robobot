package RoboBot::Plugin::Auth;

use strict;
use warnings;

sub commands { qw( auth ) }
sub usage { "[ <allow|deny|default> <command> <nick> | <command|nick> list ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    $sender =~ s{(^\s+|\s+$)}{}ogs;

    if ($message =~ m{^\s*(allow|deny|default)\s+(\w+)\s+(\w+)\s*$}o) {
        return update_permissions($bot, $1, $2, $3, $sender);
    } elsif ($message =~ m{^\s*(\w+)\s+list\s*$}o) {
        return show_permissions($bot, $1);
    }
}

sub has_permission {
    my ($bot, $command, $nick) = @_;

    my $res = $bot->db->do(q{
        select 'default' as name, ap.state
        from auth_permissions ap
            join servers s on (ap.server_id = s.id)
        where s.name = ? and ap.command = lower(?) and ap.nick_id is null
        union
        select 'user' as name, ap.state
        from auth_permissions ap
            join servers s on (ap.server_id = s.id)
            join nicks n on (ap.nick_id = n.id)
        where s.name = ? and ap.command = lower(?) and n.nick = lower(?)
    }, $bot->config->server, $command, $bot->config->server, $command, $nick);

    return 0 unless $res;

    my %perms;

    while ($res->next) {
        $perms{$res->{'name'}} = $res->{'state'};
    }

    if (exists $perms{'user'}) {
        return $perms{'user'} eq 'allow' ? 1 : 0;
    } elsif (exists $perms{'default'}) {
        return $perms{'default'} eq 'allow' ? 1 : 0;
    }

    # default permission to plugins is to allow their use
    return 1;
}

sub show_permissions {
    my ($bot, $cmd_or_nick) = @_;

    my $is_nick = is_nick($bot, $cmd_or_nick);
    my $is_cmd = is_command($bot, $cmd_or_nick);

    return sprintf('%s not recognized as a command or a nickname.', $cmd_or_nick)
        unless $is_nick || $is_cmd;

    my @r;

    # ... build permissions output list ...

    return @r;
}

sub update_permissions {
    my ($bot, $mode, $command, $nick, $granter) = @_;

    print STDERR "Args: @_\n";

    return 'Unrecognized command name.' unless is_cmd($bot, $command);
    return 'Unrecognized nickname.' unless is_nick($bot, $nick);

    $granter = $bot->db->do(q{
        select *
        from nicks
        where lower(nick) = lower(?) and can_grant
    }, $granter);

    return 'Unauthorized attempt to alter permissions.' unless $granter && $granter->next;

    my $res = $bot->db->do(q{
        select *
        from auth_permissions ap
            join servers s on (ap.server_id = s.id)
            join nicks n on (ap.nick_id = n.id)
        where s.name = ? and ap.command = lower(?) and lower(n.nick) = lower(?)
    }, $bot->config->server, $command, $nick);

    if ($res && $res->next) {
        if ($mode eq 'default') {
            $res = $bot->db->do(q{ delete from auth_permissions where permission_id = ? }, $res->{'permission_id'});

            return sprintf('Permissions for %s to use command %s have been returned to their default on this server.',
                    $nick, $command)
                if $res;
            return 'An error occurred when resetting permissions.';
        } elsif ($mode eq $res->{'state'}) {
            return sprintf('%s already has those permissions to the %s command. No changes made.',
                $nick, $command);
        } elsif ($mode eq 'allow' || $mode eq 'deny') {
            $res = $bot->db->do(q{
                update auth_permissions
                set state      = ?,
                    updated_at = now(),
                    granted_by = (select id from nicks where lower(nick) = lower(?))
                where permission_id = ?
            }, $mode, $granter, $res->{'permission_id'});

            return sprintf('%s is now %s access to the %s command.',
                    $nick, ( $mode eq 'allow' ? 'allowed' : 'denied' ), $command)
                if $res;
            return 'An error occurred when updating permissions.';
        }
    } else {
        return sprintf('%s already has default permissions to the %s command. No changes made.',
            $nick, $command) if $mode eq 'default';

        $res = $bot->db->do(q{
            insert into auth_permissions
                ( server_id, nick_id, command, state, granted_by )
            values (
                ( select id from servers where name = ? ),
                ( select id from nicks where lower(nick) = lower(?) ),
                ?, ?,
                ( select id from nicks where lower(nick) = lower(?) )
            )
        }, $bot->config->server, $nick, $command, $mode, $granter);

        return sprintf('%s is now %s access to the %s command.',
                $nick, ( $mode eq 'allow' ? 'allowed' : 'denied' ), $command)
            if $res;
        return 'An error occurred when adding permissions.';
    }

    return;
}

sub is_cmd {
    my ($bot, $name) = @_;

    return 1 if scalar(grep { $_ eq lc($name) } $bot->commands) > 0;
    return 0;
}

sub is_nick {
    my ($bot, $name) = @_;

    my $res = $bot->db->do(q{
        select * from nicks where lower(nick) = lower(?)
    }, $name);

    return 1 if $res && $res->next;
    return 0;
}

1;
