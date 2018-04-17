#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

my $period = 0+($ARGV[0] // 0);
die "Invalid period specified!\n" unless $period;

print STDERR "Period: $period\n";

my @lambdas;
my $i = 0;

while (defined($_=<STDIN>)) {
   chomp;

   push @{$lambdas[ $i++ ]}, $_;

   $i = 0 if $i == $period;
}

sub avg {
   my $sum = 0;
   $sum += $_ for @_;
   $sum /= @_;
}

print "@{[map { avg @$_ } @lambdas]}\n";
