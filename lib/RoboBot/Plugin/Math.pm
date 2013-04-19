package RoboBot::Plugin::Math;

use strict;
use warnings;

use Math::BigFloat;
use Math::RPN qw( rpn );
use Number::Format qw( format_number );

sub commands { qw( math ) }
sub usage { "<RPN expression>" }

sub handle_message {
    my ($class, $bot, $sender, $channel, $command, $original, $timestamp, $message) = @_;

    my $nf = Number::Format->new;

    return unless defined $message && $message =~ m{\S+}o;

    my @list = grep { defined $_ && $_ =~ m{\S}o } split(/\s+/, $message);
    s{(^\s+|\s+$)}{}ogs for @list;

    my $value = eval {
        my $rpn_result = Math::BigFloat->new(rpn(@list));
        format_number($rpn_result, 4);
    };

    return sprintf('%s: %s', $sender, $value) if defined $value;
    return sprintf('Your expression could not be evaluated.');
}

1;
