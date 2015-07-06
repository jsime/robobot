package RoboBot::Plugin::Filter;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use FileHandle;
use IPC::Open2;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Filter',
);

has '+description' => (
    default => 'Provides various text translation and munging filters. Mostly humorous.',
);

has '+commands' => (
    default => sub {
        my %h = map { $_ => { method      => 'filter_text',
                        description => 'Filters input argument text through the ' . $_ . ' program.',
                        usage       => '<text>' }
          } qw( b1ff chef cockney eleet fudd nethackify newspeak pirate scottish scramble uniencode );
        return \%h;
    },
);

has 'filter_paths' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub filter_text {
    my ($self, $message, $filter, @args) = @_;

    return unless exists $self->commands->{$filter};

    my $prog = $self->find_filter($message, $filter);
    return unless defined $prog;

    my $pid = open2(my $rfh, my $wfh, $prog) || return;
    print $wfh join("\n", @args);
    close($wfh);

    my $filtered = join("\n", <$rfh>);
    $filtered =~ s{[\n\r]+}{\n}ogs;

    return split(/\n/o, $filtered);
}

sub find_filter {
    my ($self, $message, $filter) = @_;

    return $self->filter_paths->{$filter} if exists $self->filter_paths->{$filter};

    return undef unless $filter =~ m{^[A-Za-z0-9]+$}o;

    my $path = `which $filter`;
    chomp($path);

    unless (-x $path) {
        $message->response->raise(sprintf('The filter %s appears to not be installed on this machine.', $filter));
        return undef;
    }

    $self->filter_paths->{$filter} = $path;
    return $path;
}

__PACKAGE__->meta->make_immutable;

1;
