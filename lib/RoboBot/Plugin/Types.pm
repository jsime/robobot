package RoboBot::Plugin::Types;

use v5.20;

use namespace::autoclean;

use Moose;

use RoboBot::Type::String;

extends 'RoboBot::Plugin';

=head1 types

Provides common functions for interacting with types.

=cut

has '+name' => (
    default => 'Types',
);

has '+description' => (
    default => 'Provides common functions for interacting with types.',
);

=head2 typeof

=head3 Description

Returns a string containing the type name of ``value``.

=head3 Usage

<value>

=cut

has '+commands' => (
    default => sub {{
        'typeof' => { method      => 'types_typeof',
                      description => 'Returns a string containing the type name of <x>.',
                      usage       => '<x>',
                      example     => '"foo"',
                      result      => 'String', },
    }},
);

sub find_filter {
    my ($self, $message, $command, $rpl, $var) = @_;

    return unless defined $var;

    my $type;
    eval {
        $type = $var->type;
    };

    return if $@;
    return RoboBot::Type::String->new( value => $type );
}

__PACKAGE__->meta->make_immutable;

1;
