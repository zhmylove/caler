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

   my ($time, $value) = split/\s+/;

   push @{$lambdas[ (int($time + 0.5) % $period) ]}, $value;
}

sub avg {
   my $sum = 0;
   $sum += $_ for @_;
   $sum /= @_;
}

# use Data::Dumper;
# print Dumper(\@lambdas);

print "@{[map { avg @$_ } grep { defined } @lambdas]}\n";
