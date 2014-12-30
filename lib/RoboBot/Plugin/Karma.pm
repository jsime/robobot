package RoboBot::Plugin::Karma;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

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
    }},
);

has 'nf' => (
    is      => 'ro',
    isa     => 'Number::Format',
    default => sub { Number::Format->new() }
);

sub update_karma {
    my ($self, $message) = @_;

    my %nicks = ($message->raw =~ m{([A-Za-z0-9_]+)([+-]{2})}ogs);

    return unless scalar(keys %nicks) > 0;

    foreach my $nick (keys %nicks) {
        my $karma_amount = $nicks{$nick} eq '++' ? 1 : -1;

        my $res = $self->bot->config->db->do(q{
            select id
            from nicks
            where lower(nick) = lower(?)
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
        @nicks = ($message->sender->nick);
    }

    foreach my $nick (@nicks) {
        my $res = $self->bot->config->db->do(q{
            select id
            from nicks
            where lower(nick) = lower(?)
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
