package App::RoboBot::TypeFactory;

use v5.20;

use namespace::autoclean;

use Moose;

use Module::Loaded;

use App::RoboBot::Type::Expression;
use App::RoboBot::Type::Function;
use App::RoboBot::Type::List;
use App::RoboBot::Type::Macro;
use App::RoboBot::Type::Map;
use App::RoboBot::Type::Number;
use App::RoboBot::Type::Set;
use App::RoboBot::Type::String;
use App::RoboBot::Type::Symbol;
use App::RoboBot::Type::Vector;

has 'bot' => (
    is       => 'ro',
    isa      => 'App::RoboBot',
    required => 1,
);

sub build {
    my ($self, $type, $val) = @_;

    my $type_class = 'App::RoboBot::Type::' . $type;

    unless (is_loaded($type_class)) {
        warn sprintf('Invalid type "%s" requested.', $type);
        return;
    }

    return $type_class->build_from_val($self->bot, $val);
}

__PACKAGE__->meta->make_immutable;

1;
