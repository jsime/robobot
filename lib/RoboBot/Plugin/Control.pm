package RoboBot::Plugin::Control;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Control',
);

has '+description' => (
    default => 'Provides a selection of control structure functions.',
);

has '+commands' => (
    default => sub {{
        'if' => { method          => 'control_if',
                  preprocess_args => 0,
                  description     => 'Conditionally evaluates an expression when the given condition is true.',
                  usage           => '(<boolean condition>) (<expression>)',
                  example         => '(> 1 5) ("One is somehow larger than five on this system.")',
                  result          => '' },

        'if-else' => { method          => 'control_ifelse',
                       preprocess_args => 0,
                       description     => 'Conditionally evaluates the first expression if the condition is true, otherwise evaluates the second expression.',
                       usage           => '(<boolean condition>) (<expression>) (<expression>)',
                       example         => '(> 1 5) ("One is somehow larger than five on this system.") ("Five is still larger than one.")',
                       result          => 'Five is still larger than one.' },

        'while' => { method          => 'control_while',
                     preprocess_args => 0,
                     description     => 'Repeatedly evaluates the expression for as long as the condition remains true.',
                     usage           => '(<boolean condition>) (<expression>)',
                     example         => '(== (roll 6 2) 2) ("Snake-eyes!")',
                     result          => 'Snake-eyes!' },
    }},
);

sub control_if {
    my ($self, $message, $command, $condition, $expr_if) = @_;

    my $res = $message->process_list($condition);

    if ($res) {
        return $message->process_list($expr_if);
    }

    return;
}

sub control_ifelse {
    my ($self, $message, $command, $condition, $expr_if, $expr_else) = @_;

    my $res = $message->process_list($condition);

    if ($res) {
        return $message->process_list($expr_if);
    } else {
        return $message->process_list($expr_else);
    }

    return;
}

sub control_while {
    my ($self, $message, $command, $condition, $expr_loop) = @_;

    my @res;

    # TODO make the loop-limit configurable
    my $i = 0;
    my $ret = $message->process_list($condition);

    while ($i < 100 && $ret) {
        @res = $message->process_list($expr_loop);
        $ret = $message->process_list($condition);
        $i++;
    }

    return @res;
}

__PACKAGE__->meta->make_immutable;

1;
