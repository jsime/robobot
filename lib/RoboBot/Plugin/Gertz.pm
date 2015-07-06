package RoboBot::Plugin::Gertz;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

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

return; # no gertz alertz for the time being
    return if $message->has_expression;

    if ($message->raw =~ m{\b(gertz)\b}oi) {
        # do not respond if we matched on another bot's gertz alertz
        $message->response->unshift('GERTZ ALERTZ!')
            unless $message->raw =~ m{gertz\s+alertz}oi;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

1;
