#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
use utf8;
binmode STDOUT, ':utf8';

#####
# 
# This file can operate with MS Excel copied data to prepare it for period
# estimation:
# $ ./interpolator2001.pl excel_copy_paste | _D=1 _R=0 ./period.pl -f
#
#####

my $prev = 0;
my $sum = 0;
my $count = 0;

while (defined($_ = <>)) {
   # Prepare the string
   chomp;
   s/,/./g;
   /^\s*$/ && next;

   my @F = split /\s+/;

   # First-line case
   if ($count == 0) {
      $prev = int $F[0];
      $count++;
      next;
   }

   if (int($F[0]) == $prev) {
      $sum += $F[1];
      $count++;
   } else {
      print "$prev " . $sum / $count . "\n";
      $sum = $F[1];
      $count = 1;
      $prev = int $F[0];
   }
}
