package RoboBot::Plugin::Core::Control;

use v5.20;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Scalar::Util qw( blessed );

extends 'RoboBot::Plugin';

has '+name' => (
    default => 'Core::Control',
);

has '+description' => (
    default => 'Provides a selection of control structure functions.',
);

has '+commands' => (
    default => sub {{
        'if' => { method          => 'control_if',
                  preprocess_args => 0,
                  description     => 'Conditionally evaluates an expression when the given condition is true. If the condition is not true, and a third argument is provided, then it is evaluated and its result is returned instead.',
                  usage           => '(<boolean condition>) (<expression>) [(<else>)]',
                  example         => '(> 1 5) ("One is somehow larger than five on this system.")',
                  result          => '' },

        'while' => { method          => 'control_while',
                     preprocess_args => 0,
                     description     => 'Repeatedly evaluates the expression for as long as the condition remains true.',
                     usage           => '(<boolean condition>) (<expression>)',
                     example         => '(== (roll 6 2) 2) ("Snake-eyes!")',
                     result          => 'Snake-eyes!' },

        'cond' => { method          => 'control_cond',
                    preprocess_args => 0,
                    description     => 'Accepts pairs of expressions, where the first of each pair is a condition that if true in its evaluation leads to the second expression being evaluated and its value returned. The first condition-expression pair to evaluate will terminate the (cond) function\'s evaluation. If the argument list ends with a single, un-paired fallback expression, that will be evaluated in the event none of the preceding conditions were true.',
                    usage           => '(<condition>) (<expression>) [(<condition>) (<expression>) [...]] [(<fallback>)]',
                    example         => '(> 1 5) (format "%d is somehow greater than %d" 1 5) (eq "foo" "bar") (format "%s somehow matches %s" "foo" "bar") "Nothing is true."',
                    result          => '"Nothing is true."' },

        'apply' => { method          => 'control_apply',
                     preprocess_args => 0,
                     description     => 'Accepts a function name as its first argument and passes all remaining list elements one-by-one as arguments to the supplied expression.',
                     usage           => '<function to apply> <list(s) of elements>',
                     example         => '+ (seq 1 5)',
                     result          => '2 3 4 5 6' },

        'repeat' => { method          => 'control_repeat',
                      preprocess_args => 0,
                      description     => 'Repeats <n> times the evaluation of <list>. Returns a list containing the return values of every evaluation.',
                      usage           => '<n> <list>',
                      example         => '3 (upper "foo")',
                      result          => 'FOO FOO FOO', },
    }},
);

sub control_repeat {
    my ($self, $message, $command, $rpl, $num, $list) = @_;

    if (defined $num && blessed($num) && $num->can('evaluate')) {
        $num = $num->evaluate($message, $rpl);
    }

    unless (defined $num && $num =~ m{^\d+$}) {
        $message->response->raise('First argument must be the number of times to repeat list evaluation.');
        return;
    }

    unless (defined $list && blessed($list) && $list->can('evaluate')) {
        $message->response->raise('Must provide a list or expression to repeatedly evaluate.');
        return;
    }

    # Even this is probably ripe for abuse, but at least it's not unlimited.
    $num = 100 if $num > 100;

    my @ret;

    while ($num--) {
        push(@ret, $list->evaluate($message, $rpl));
    }

    return @ret;
}

sub control_if {
    my ($self, $message, $command, $rpl, $condition, $expr_if, $expr_else) = @_;

    if (defined $condition && blessed($condition) && $condition->can('evaluate')) {
        $condition = $condition->evaluate($message, $rpl);
    }

    unless (defined $expr_if && blessed($expr_if) && $expr_if->can('evaluate')) {
        $message->response->raise('Second argument must be a list or expression to evaluate when condition is truthy.');
        return;
    }

    if ($condition) {
        return $expr_if->evaluate($message, $rpl);
    } elsif (defined $expr_else && blessed($expr_else) && $expr_else->can('evaluate')) {
        return $expr_else->evaluate($message, $rpl);
    }

    return;
}

sub control_while {
    my ($self, $message, $command, $rpl, $condition, $expr_loop) = @_;

    my @res;

    # TODO make the loop-limit configurable
    my $i = 0;

    unless (defined $condition && blessed($condition) && $condition->can('evaluate')) {
        $message->response->raise('First argument must be a list or expression which will evaluate to a truthy/falsey value.');
        return;
    }

    my $ret = $condition->evaluate($message, $rpl);

    while ($i < 100 && $ret) {
        @res = $expr_loop->evaluate($message, $rpl);
        $ret = $condition->evaluate($message, $rpl);
        $i++;
    }

    return @res;
}

sub control_cond {
    my ($self, $message, $command, $rpl, @pairs) = @_;

    unless (@pairs && @pairs >= 2) {
        $message->response->raise('You must supply at least one condition and action.');
        return;
    }

    my $fallback = pop @pairs if scalar(@pairs) % 2 == 1;

    while (my $cond = shift @pairs) {
        my $action = shift @pairs;
        if ($cond->evaluate($message, $rpl)) {
            return $action->evaluate($message, $rpl)
        }
    }

    if (defined $fallback) {
        return $fallback->evaluate($message, $rpl);
    }

    return;
}

sub control_apply {
    my ($self, $message, $command, $rpl, $func, @args) = @_;

    unless (defined $func && blessed($func) =~ m{^RoboBot::Type::(Function|Macro)}) {
        $message->response->raise('You must provide a function or macro to apply to your arguments.');
        return;
    }

    unless (@args) {
        $message->response->raise('You cannot apply a function or macro to a non-existent list of arguments.');
        return;
    }

    # it's not an error to have no arguments, but we can at least short-circuit.
    return unless @args > 0;

    my @collect;

    foreach my $arg (@args) {
        my @res = $arg->evaluate($message, $rpl);
        push(@collect, $func->evaluate($message, $rpl, $_)) foreach @res;
    }

    return @collect;
}

__PACKAGE__->meta->make_immutable;

1;
