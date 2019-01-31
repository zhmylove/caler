#!/usr/bin/perl
# made by: KorG
#
package caler_fperiod;

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use lib '.';
use Exporter 'import';
our @EXPORT = qw( caler_fperiod );

our $DEBUG = 1;

use Data::Dumper;
sub _debug { print STDERR @_, "\n" if $DEBUG; }
use Memoize;
use POSIX;

our @ARR; # should be filled in reverse order to skip from the beginning

my @primes = (1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53,
   59, 61, 67, 71, 73, 79, 83, 89, 97);

# arg0: count of primes
# ret: sum
sub _get_prime_sum($);
sub _get_prime_sum($) {
   die "Invalid _get_prime_sum usage: $_[0]!" if ($_[0] || 0) < 1;
   if ($_[0] > @primes) {
      warn '_get_prime_sum arg0 exceeds @primes';
      return _get_prime_sum(0+@primes);
   }

   return $primes[0] if $_[0] == 1;
   return $primes[$_[0] - 1] + _get_prime_sum($_[0] - 1);
}
memoize('_get_prime_sum', LIST_CACHE => 'MERGE');

my $primes_to_use = 5;
my $min_period = _get_prime_sum($primes_to_use);

# arg0: period
# ret: LIST of primes
sub _get_deltas_by_period {
   my $period = $_[0];

   return if $period <= $min_period;

   my $step = floor($period / $min_period);

   map { ($_ - 1) * $step } @primes[0..$primes_to_use-1];
}

# arg0: offset
# arg@: LIST of deltas
# ret: LIST of ARR values
sub _get_values_by_offset_deltas {
   my $offset = shift;
   my @deltas = @_;

   my $index = 0;

   $ARR[$offset], map { $index += $_ + 1; $ARR[ $offset + $index] } @deltas;
}

# arg0: period
# ret: LIST: ($count, @sums), where count => number of additions per sum_i
sub _collect_periodic_sums {
   my $period = $_[0];

   my $count = floor(@ARR / $period);
   my @sums = (0) x (0+_get_deltas_by_period $period);
   print Dumper \@sums;
   my $i;

   for my $offset (map { $_ * $period } 0..$count-1) {
      $i = 0;
      $sums[ $i++ ] += $_ for (
         _get_values_by_offset_deltas $offset, _get_deltas_by_period $period
      );
   }

   return $count, @sums;
}

@ARR = (1..40);
#print "$_\n" for _get_deltas_by_period 36;
#print "$_\n" for _get_values_by_offset_deltas 20, _get_deltas_by_period 20;

print "$_\n" for _collect_periodic_sums 20;

# 0        1         2         3         4
# 1234567890123456789012345678901234567890
# ++  +    +        +            + | 36
# ++ +  +    +      + | 20
# ++ +  +    +      + ++ +  +    +      + | 20
