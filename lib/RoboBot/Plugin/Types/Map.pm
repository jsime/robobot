package RoboBot::Plugin::Types::Map;

use v5.20;

use namespace::autoclean;

use Moose;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Types::Map',
);

has '+description' => (
    default => 'Provides functions for creating and manipulating unordered maps.',
);

has '+commands' => (
    default => sub {{
        'keys' => { method      => 'map_keys',
                    description => 'Returns a list of keys from the given map, in no guaranteed order.',
                    usage       => '<map>',
                    example     => '{ :first-name "Bobby" :last-name "Sue" }',
                    result      => '[:first-name,:last-name]', },

        'values' => { method      => 'map_values',
                      description => 'Returns a list of values from the given map, in no guaranteed order.',
                      usage       => '<map>',
                      example     => '{ :first-name "Bobby" :last-name "Sue" }',
                      result      => '["Bobby","Sue"]', },

        'assoc' => { method      => 'map_assoc',
                     description => 'Returns a new map containing the existing keys and values, as well as any new key-value pairs provided. Values default to undefined, and key that already exist will have their values replaced. Multiple key-value pairs may be provided. Providing no new key-value pairs will simply return the existing map.',
                     usage       => '<map> [<key> [<value>]]',
                     example     => '{ :old-key "foo" } :new-key "bar"',
                     result      => '{ :old-key "foo" :new-key "bar" }', },
    }},
);

sub map_assoc {
    my ($self, $message, $command, $rpl, $map, @new_elements) = @_;

    unless (defined $map && ref($map) eq 'HASH') {
        $message->response->raise('Must provide a map.');
        return;
    }

    my $key;
    foreach my $el (@new_elements) {
        if (!ref($el) && substr($el, 0, 1) eq ':') {
            $key = $el;
            $map->{$key} = undef;
        } elsif (defined $key) {
            $map->{$key} = $el;
            $key = undef;
        } else {
            $message->response->raise('Invalid parameters supplied. Map keys must evaluate to scalar symbols. Was expecting a key name, but got: %s', $el);
            return;
        }
    }

    return $map;
}

sub map_keys {
    my ($self, $message, $command, $rpl, $map) = @_;

    unless (defined $map && ref($map) eq 'HASH') {
        $message->response->raise('Must supply a map.');
        return;
    }

    return keys %{$map};
}

sub map_values {
    my ($self, $message, $command, $rpl, $map) = @_;

    unless (defined $map && ref($map) eq 'HASH') {
        $message->response->raise('Must supply a map.');
        return;
    }

    return values %{$map};
}

__PACKAGE__->meta->make_immutable;

1;
