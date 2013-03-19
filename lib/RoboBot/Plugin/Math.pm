package RoboBot::Plugin::Math;

use strict;
use warnings;

use Math::RPN qw( rpn );

sub commands { qw( math ) }
sub usage { "<RPN expression>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    return unless defined $message && $message =~ m{\S+}o;

    my @list = grep { defined $_ && $_ =~ m{\S}o } split(/\s+/, $message);
    s{(^\s+|\s+$)}{}ogs for @list;

    my $value = rpn(@list);

    return sprintf('%s: %s', $sender, $value) if defined $value;
    return sprintf('Your expression could not be evaluated.');
}

1;
