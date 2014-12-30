package RoboBot::Plugin::Gertz;

use strict;
use warnings FATAL => 'all';

use Moose;
use MooseX::SetOnce;
use namespace::autoclean;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Gertz',
);

has '+description' => (
    default => 'Gertz Alertz!',
);

has '+before_hook' => (
    default => 'gertz_alert',
);

sub gertz_alert {
    my ($self, $message) = @_;

    if ($message->raw =~ m{\b(gertz)\b}oi) {
        $message->response->unshift('GERTZ ALERTZ!');
    }
}

__PACKAGE__->meta->make_immutable;

1;
