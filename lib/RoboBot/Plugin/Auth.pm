package RoboBot::Plugin::Auth;

use strict;
use warnings;

sub commands { qw( auth ) }
sub usage { "[ <allow|deny|default> <command> <nick> | <command> default <allow|deny> | <command|nick> list ]" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    $sender =~ s{(^\s+|\s+$)}{}ogs;

    if ($message =~ m{^\s*(allow|deny|default)\s+(\w+)\s+(\w+)\s*$}o) {
        return update_permissions($bot, $1, $2, $3, $sender);
    } elsif ($message =~ m{^\s*(\w+)\s+list\s*$}o) {
        return show_permissions($bot, $1);
    } elsif ($message =~ m{^\s*(\w+)\s+default\s+(allow|deny)\s*$}o) {
        return set_default_permissions($bot, $1, $2, $sender);
    }

    return;
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
        where s.name = ? and ap.command = lower(?) and ap.nick_id = ?
    }, $bot->config->server, $command, $bot->config->server, $command, $nick->id);

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

sub set_default_permissions {
    my ($bot, $command, $mode, $granter) = @_;
}

sub show_permissions {
    my ($bot, $cmd_or_nick) = @_;

    my $is_nick = is_nick($bot, $cmd_or_nick);
    my $is_cmd = is_cmd($bot, $cmd_or_nick);

    return sprintf('%s not recognized as a command or a nickname.', $cmd_or_nick)
        unless $is_nick || $is_cmd;

    my ($res, @r);

    # ... build permissions output list ...
    if ($is_nick) {
        $res = $bot->db->do(q{
            select ap.command, ap.state
            from auth_permissions ap
                join nicks n on (n.id = ap.nick_id)
                join servers s on (s.id = ap.server_id)
            where s.name = ? and lower(n.nick) = lower(?)
        }, $bot->config->server, $cmd_or_nick);

        my %perms;

        if ($res) {
            while ($res->next) {
                $perms{$res->{'command'}} = $res->{'state'};
            }
        }

        if (scalar(keys(%perms)) > 0) {
            push(@r, sprintf('%s has been granted the following specific permissions:', $cmd_or_nick));

            my @allow = map { "!$_" } sort grep { $perms{$_} eq 'allow' } keys %perms;
            my @deny  = map { "!$_" } sort grep { $perms{$_} eq 'deny' }  keys %perms;

            push(@r, sprintf('  Allowed: %s', join(', ', @allow))) if scalar(@allow) > 0;
            push(@r, sprintf('  Denied: %s', join(', ', @deny))) if scalar(@deny) > 0;
        } else {
            push(@r, sprintf('%s has not been granted any specific permissions.', $cmd_or_nick));
        }
    }

    if ($is_cmd) {
        $res = $bot->db->do(q{
            select ap.state
            from auth_permissions ap
                join servers s on (s.id = ap.server_id)
            where s.name = ? and ap.command = lower(?) and ap.nick_id is null
        }, $bot->config->server, $cmd_or_nick);

        my $mode = 'allow';

        if ($res && $res->next) {
            $mode = $res->{'state'};
        }

        push(@r, sprintf('Default permission for the command !%s is %s%s.', $cmd_or_nick,
            uc(substr($mode, 0, 1)), substr($mode, 1)));
    }

    return @r if scalar(@r) > 0;
    return sprintf('No relevant permissions found for %s.', $cmd_or_nick);
}

sub update_permissions {
    my ($bot, $mode, $command, $nick, $granter) = @_;

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

            return sprintf('Permissions for %s to use command !%s have been returned to their default on this server.',
                    $nick, $command)
                if $res;
            return 'An error occurred when resetting permissions.';
        } elsif ($mode eq $res->{'state'}) {
            return sprintf('%s already has those permissions to the !%s command. No changes made.',
                $nick, $command);
        } elsif ($mode eq 'allow' || $mode eq 'deny') {
            $res = $bot->db->do(q{
                update auth_permissions
                set state      = ?,
                    updated_at = now(),
                    granted_by = ?
                where permission_id = ?
            }, $mode, $granter->{'id'}, $res->{'permission_id'});

            return sprintf('%s is now %s access to the !%s command.',
                    $nick, ( $mode eq 'allow' ? 'allowed' : 'denied' ), $command)
                if $res;
            return 'An error occurred when updating permissions.';
        }
    } else {
        return sprintf('%s already has default permissions to the !%s command. No changes made.',
            $nick, $command) if $mode eq 'default';

        $res = $bot->db->do(q{
            insert into auth_permissions
                ( server_id, nick_id, command, state, granted_by )
            values (
                ( select id from servers where name = ? ),
                ( select id from nicks where lower(nick) = lower(?) ),
                ?, ?, ?
            )
        }, $bot->config->server, $nick, $command, $mode, $granter->{'id'});

        return sprintf('%s is now %s access to the !%s command.',
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
