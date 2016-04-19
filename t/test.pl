#!/usr/bin/perl
# run the tests listed on the command line using make.
#
use strictures;

my @command = qw( make test );
my @tests;
for my $test_file (@ARGV) {
    next if $test_file =~ m/"/;
    push @tests, $test_file;
}

if (scalar @tests) {
    push @command, "TEST_FILES=" . join(" ", @tests);
}

printf("exec: %s\n", join(" ", @command));
exec(@command);
