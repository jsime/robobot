package RoboBot::Plugin::Karma;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use RoboBot::Nick;

use Number::Format;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Karma',
);

has '+description' => (
    default => 'Modifies and displays karma/reputation points.',
);

has '+before_hook' => (
    default => 'update_karma',
);

has '+commands' => (
    default => sub {{
        'karma' => { method      => 'display_karma',
                     description => 'Displays current karma/reputation points for given nicks. Defaults to displaying karma of caller.',
                     usage       => '[<nick> ... <nick N>]' },

        '++karma' => { method      => 'add_karma',
                       description => "Explicitly adds to the given nick's karma rating.",
                       usage       => '<nick>' },

        '--karma' => { method      => 'subtract_karma',
                       description => "Explicitly subtracts from the given nick's karma rating.",
                       usage       => '<nick>' },
    }},
);

has 'nf' => (
    is      => 'ro',
    isa     => 'Number::Format',
    default => sub { Number::Format->new() }
);

sub add_karma {
    my ($self, $message, $command, $nick) = @_;

    $nick = RoboBot::Nick->new( config => $self->bot->config, name => "$nick" );

    if (defined $nick) {
        my $res = $self->bot->config->db->do(q{
            insert into karma_karma ???
        }, {
            nick_id      => $nick->id,
            karma        => 1,
            from_nick_id => $message->sender->id,
        });
    }

    return;
}

sub subtract_karma {
    my ($self, $message, $command, $nick) = @_;

    $nick = RoboBot::Nick->new( config => $self->bot->config, name => "$nick" );

    if (defined $nick) {
        my $res = $self->bot->config->db->do(q{
            insert into karma_karma ???
        }, {
            nick_id      => $nick->id,
            karma        => -1,
            from_nick_id => $message->sender->id,
        });
    }

    return;
}

sub update_karma {
    my ($self, $message) = @_;

    my %nicks = ($message->raw =~ m{([A-Za-z0-9_]+)([+-]{2})}ogs);

    return unless scalar(keys %nicks) > 0;

    foreach my $nick (keys %nicks) {
        my $karma_amount = $nicks{$nick} eq '++' ? 1 : -1;

        my $res = $self->bot->config->db->do(q{
            select id
            from nicks
            where lower(name) = lower(?)
        }, $nick);

        if ($res && $res->next) {
            my $nick_id = $res->{'id'};

            $self->bot->config->db->do(q{
                insert into karma_karma ???
            }, {
                nick_id      => $nick_id,
                karma        => $karma_amount,
                from_nick_id => $message->sender->id,
            });
        }
    }
}

sub display_karma {
    my ($self, $message, $command, @nicks) = @_;

    if (!@nicks || @nicks < 1) {
        @nicks = ($message->sender->name);
    }

    foreach my $nick (@nicks) {
        my $res = $self->bot->config->db->do(q{
            select id
            from nicks
            where lower(name) = lower(?)
        }, $nick);

        next unless $res && $res->next;

        my $nick_id = $res->{'id'};

        $res = $self->bot->config->db->do(q{
            select sum(d.karma) as karma
            from (
                select from_nick_id, log(sum(karma))
                from karma_karma
                where nick_id = ? and karma = 1
                group by from_nick_id

                union all

                select from_nick_id, log(sum(abs(karma))) * -1
                from karma_karma
                where nick_id = ? and karma = -1
                group by from_nick_id
            ) d(from_nick_id, karma)
        }, $nick_id, $nick_id);

        next unless $res && $res->next;

        $message->response->push(sprintf('%s currently has %s karma.', $nick, $self->nf->format_number($res->[0] || 0, 3, 1)));
    }
}

__PACKAGE__->meta->make_immutable;

1;
