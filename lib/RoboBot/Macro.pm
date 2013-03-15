package RoboBot::Macro;

use strict;
use warnings;

=head1 NAME

RoboBot::Macro - Management of user-defined command macros

=head1 SYNOPSIS

This modules provides for the creation, modification, and use of user-defined
command macros. These macros allow a user to combine pre-defined series of
other commands (any builtins or plugins), along with arguments, to be executed
any time the macro is sent to the channel.

Macros can be created or modified in an IRC channel with the following syntax:

    @+<macroname> <commands>

Deleted with:

    @-<macroname>

And run with:

    @<macroname> [arg1, ..., argN]

Arguments to macros are simple scalar values, and may be designated in the
macro definition using C<$$>. Any number may be used. Thus, if we want to create
a macro called C<bozo> which makes use of the Logger plugin's ability to recall
messages from a specific user (in our example "jon") that contain a particular
string, we can do so with:

    @+bozo !!$$ i'm.*bozo

After which we can run the macro, and (hypothetically) get back something like:

    <ournick> @bozo jon
    <RoboBot> <jon> i'm such a bozo, i just deleted my home directory

Macros may make use of multiple commands piped together, or even output
redirection. Macro processing (as you would expect) occurs prior to all other
message processing, and as such any pipes and redirects are saved as part of
the macro, not used to process the output of the macro management commands
themselves.

=cut

=head1 METHODS

=head2 new

=cut

sub new {
    my ($class, $bot, %args) = @_;
}

1;
