#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'RoboBot' ) || print "Bail out!\n";
}

diag( "Testing RoboBot $RoboBot::VERSION, Perl $], $^X" );
