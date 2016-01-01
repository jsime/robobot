package RoboBot::TypeFactory;

use v5.20;

use namespace::autoclean;

use Moose;

use Module::Loaded;

use RoboBot::Type::Expression;
use RoboBot::Type::Function;
use RoboBot::Type::List;
use RoboBot::Type::Macro;
use RoboBot::Type::Map;
use RoboBot::Type::Number;
use RoboBot::Type::Set;
use RoboBot::Type::String;
use RoboBot::Type::Symbol;
use RoboBot::Type::Vector;

has 'bot' => (
    is       => 'ro',
    isa      => 'RoboBot',
    required => 1,
);

sub build {
    my ($self, $type, $val) = @_;

    my $type_class = 'RoboBot::Type::' . $type;

    unless (is_loaded($type_class)) {
        warn sprintf('Invalid type "%s" requested.', $type);
        return;
    }

    return $type_class->build_from_val($self->bot, $val);
}

__PACKAGE__->meta->make_immutable;

1;
