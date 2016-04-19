#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'App::Curator' ) || print "Bail out!\n";
}

diag( "Testing App::Curator $App::Curator::VERSION, Perl $], $^X" );
