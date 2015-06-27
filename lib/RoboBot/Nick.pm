package RoboBot::Nick;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

has 'id' => (
    is        => 'rw',
    isa       => 'Int',
    traits    => [qw( SetOnce )],
    predicate => 'has_id',
);

has 'nick' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_nick',
);

has 'alts' => (
    is  => 'rw',
    isa => 'ArrayRef[Str]',
);

has 'full_name' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_full_name',
);

has 'slack_id' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_slack_id',
);

has 'denied_functions' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
    writer  => '_set_denied_functions',
);

has 'config' => (
    is       => 'ro',
    isa      => 'RoboBot::Config',
    required => 1,
);

has 'network' => (
    is        => 'ro',
    isa       => 'RoboBot::Network',
    predicate => 'has_network',
);

sub BUILD {
    my ($self) = @_;

    # TODO basic normalization of nicks (removing trailing underscores and single
    # digits from automatic nick renames for dupe connections)

    my ($res, %new);
    my $found = 0;

    # TODO: This is just awful, so replace it. Still needs to do the retry with
    #       possible alternate values offered up by the Network plugin.
    if ($self->has_nick || $self->has_full_name || $self->has_slack_id) {
        my @where;
        my @binds;

        if ($self->has_nick) {
            push(@where, 'lower(nick) = lower(?)');
            push(@binds, $self->nick);
        }

        if ($self->has_full_name) {
            push(@where, 'lower(full_name) = lower(?)');
            push(@binds, $self->full_name);
        }

        if ($self->has_slack_id) {
            push(@where, 'slack_id = ?');
            push(@binds, $self->slack_id);
        }

        $res = $self->config->db->do(q{select id, nick, full_name, slack_id, can_grant from nicks where } . join(' and ', @where), @binds);

        if ($res && $res->next) {
            $found = 1;
        } elsif ($self->has_network) {
            $new{'nick'}      = $self->nick      if $self->has_nick;
            $new{'full_name'} = $self->full_name if $self->has_full_name;
            $new{'slack_id'}  = $self->slack_id  if $self->has_slack_id;

            %new = $self->network->get_nick_data(%new);

            if (%new && scalar(keys(%new)) > 0) {
                @where = ();
                @binds = ();

                if (exists $new{'nick'}) {
                    push(@where, 'lower(nick) = lower(?)');
                    push(@binds, $new{'nick'});
                }

                if (exists $new{'full_name'}) {
                    push(@where, 'lower(full_name) = lower(?)');
                    push(@binds, $new{'full_name'});
                }

                if (exists $new{'slack_id'}) {
                    push(@where, 'slack_id = ?');
                    push(@binds, $new{'slack_id'});
                }

                # Match on any of the values this time, instead of requiring them all as before.
                $res = $self->config->db->do(q{select id, nick, full_name, slack_id, can_grant from nicks where } . join(' or ', @where), @binds);

                if ($res && $res->next) {
                    $found = 1;
                }
            }
        }
    } else {
        warn "Cannot continue without something to use for a nick.";
        return;
    }

    if ($found) {
        foreach my $col (qw( id nick full_name slack_id )) {
            $self->$col($res->{$col}) if $res->{$col} && $res->{$col} =~ m{.+};
        }

        $self->config->db->do(q{
            update nicks
            set nick = ?, full_name = ?, slack_id = ?
            where id = ?
        }, $self->nick, ($self->full_name || undef), ($self->slack_id || undef), $self->id) if $self->has_full_name || $self->has_slack_id;
    } else {
        %new = ();
        foreach my $col (qw( nick full_name slack_id )) {
            $new{$col} = $self->$col || undef;
        }

        $res = $self->config->db->do(q{
            insert into nicks ??? returning id
        }, \%new);

        if ($res && $res->next) {
            $self->id($res->{'id'});
        }
    }

    # TODO: Restore old functionality of per-server permissions. Pre-AnyEvent
    #       the information to do so was missing, but now we have it back.
    my %denied;

    $res = $self->config->db->do(q{
        select command, granted_by
        from auth_permissions
        where nick_id is null and state = 'deny'
    });

    if ($res) {
        while ($res->next) {
            $denied{$res->{'command'}} = $res->{'granted_by'};
        }
    }

    $res = $self->config->db->do(q{
        select command, granted_by, state
        from auth_permissions
        where nick_id = ?
    }, $self->id);

    if ($res) {
        while ($res->next) {
            if ($res->{'state'} eq 'allow') {
                delete $denied{$res->{'command'}} if exists $denied{$res->{'command'}};
            } else {
                $denied{$res->{'command'}} = $res->{'granted_by'};
            }
        }
    }

    $self->_set_denied_functions(\%denied);
}

sub add_alt {
    my ($self, $nick) = @_;

    # TODO this add_alt method (need corresponding schema)
}

sub remove_alt {
    my ($self, $nick) = @_;

    # TODO this remove_alt method (and corresponding schema)
}

__PACKAGE__->meta->make_immutable;

1;
