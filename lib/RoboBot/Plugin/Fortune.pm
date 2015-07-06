package RoboBot::Plugin::Fortune;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Fortune',
);

has '+description' => (
    default => 'Exports functions for displaying various types of quotes and fortunes.',
);

has '+commands' => (
    default => sub {{
        'bofh' => { method      => 'bofh',
                    description => 'Returns a random BOFH quote.',
                    usage       => '' },

        'fortune' => { method      => 'fortune',
                       description => 'Returns a random fortune from one of several collections.',
                       usage       => '' },

        'startrek' => { method      => 'startrek',
                        description => 'Returns a random Star Trek quote.',
                        usage       => '' },

        'zippy' => { method      => 'zippy',
                     description => 'Returns a random Zippy the Pinhead quote.',
                     usage       => '' },
    }},
);

# TODO make this auto-discover path, or at least move it to a configuration option
has 'bin_path' => (
    is      => 'ro',
    isa     => 'Str',
    default => '/usr/games/fortune',
);

has 'max_len' => (
    is      => 'ro',
    isa     => 'Num',
    default => '200',
);

sub bofh {
    my ($self, $message, $command, @args) = @_;

    return $self->get_fortune($message, 'bofh-excuses');
}

sub fortune {
    my ($self, $message, $command, @args) = @_;

    return $self->get_fortune($message, qw( people miscellaneous wisdom paradoxum fortunes humorists computers cookie pets ));
}

sub startrek {
    my ($self, $message, $command, @args) = @_;

    return $self->get_fortune($message, 'startrek');
}

sub zippy {
    my ($self, $message, $command, @args) = @_;

    return $self->get_fortune($message, 'zippy');
}

sub get_fortune {
    my ($self, $message, @dicts) = @_;

    unless (-x $self->bin_path) {
        $message->response->raise('Fortune program is not installed.');
        return;
    }

    my $dictlist = lc(join(' ', @dicts));
    unless ($dictlist =~ m{^[a-z -]+$}o) {
        $message->response->raise('Invalid dictionary name provided.');
        return;
    }

    my $cmd = $self->bin_path . ' -n ' . $self->max_len . ' -s ' . $dictlist;

    return $self->cleanup_fortune($message, scalar(`$cmd`));
}

sub cleanup_fortune {
    my ($self, $message, $fortune) = @_;

    $fortune =~ s{\s+}{ }ogs;
    $fortune =~ s{(^\s+|\s+$)}{}ogs;

    return $fortune;
}

__PACKAGE__->meta->make_immutable;

1;
