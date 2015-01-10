package RoboBot::Nick;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

has 'id' => (
    is     => 'rw',
    isa    => 'Int',
    traits => [qw( SetOnce )],
);

has 'nick' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    traits   => [qw( SetOnce )],
);

has 'alts' => (
    is  => 'rw',
    isa => 'ArrayRef[Str]',
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

sub BUILD {
    my ($self) = @_;

    # TODO basic normalization of nicks (removing trailing underscores and single
    # digits from automatic nick renames for dupe connections)

    my $res = $self->config->db->do(q{
        select id, nick, can_grant
        from nicks
        where lower(nick) = lower(?)
    }, $self->nick);

    if ($res && $res->next) {
        $self->id($res->{'id'});
    } else {
        $res = $self->config->db->do(q{
            insert into nicks ??? returning id
        }, { nick => $self->nick });

        if ($res && $res->next) {
            $self->id($res->{'id'});
        }
    }

    # TODO look into possibility of restoring the old style of per-server permission
    # lists (right now we don't have enough info in this method to know which server
    # we're loading permissions for)
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
