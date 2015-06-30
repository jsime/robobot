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

has 'name' => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_name',
);

has 'extradata' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
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

    unless ($self->has_id) {
        die "Invalid nick creation" unless $self->has_name;

        my $res = $self->config->db->do(q{
            select id
            from nicks
            where lower(name) = lower(?)
        }, $self->name);

        if ($res && $res->next) {
            $self->id($res->{'id'});
        } else {
            $res = $self->config->db->do(q{
                insert into nicks ??? returning id
            }, { name => $self->name });

            if ($res && $res->next) {
                $self->id($res->{'id'});
            }
        }

        die "Could not generate nick ID" unless $self->has_id;
    }

    # TODO basic normalization of nicks (removing trailing underscores and single
    # digits from automatic nick renames for dupe connections)

    # TODO: Restore old functionality of per-server permissions. Pre-AnyEvent
    #       the information to do so was missing, but now we have it back.
    my %denied;

    my $res = $self->config->db->do(q{
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

__PACKAGE__->meta->make_immutable;

1;
