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

my $primes_to_use = 5; # number of primes to use from @primes
my $min_period = _get_prime_sum($primes_to_use); # (lower bound)
my $min_pieces = 8; # minimum number of pieces in period (upper bound)

# arg0: period
# ret: LIST of primes
sub _get_deltas_by_period {
   my $period = $_[0];

   die '_get_deltas_by_period: too short period' if $period <= $min_period;

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
# arg1: BOOL: False => use _get_deltas_by_period; True => use full period
# ret: LIST: ($count, @sums), where count => number of additions per sum_i
sub _collect_periodic_sums {
   my $period = $_[0];

   my $count = floor(@ARR / $period);
   # parse arg1. Defaults to _get_deltas_by_period
   # if defined arg1 && arg1 is True, then check use period
   my @deltas = $_[1] ? (0)x($period-1) : _get_deltas_by_period $period;
   my @sums = (0) x (0+@deltas);
   my $i;

   for my $offset (map { $_ * $period } 0..$count-1) {
      $i = 0;
      $sums[ $i++ ] += $_ for (
         _get_values_by_offset_deltas $offset, @deltas
      );
   }

   return $count, @sums;
}

# arg: _collect_periodic_sums(...)
# ret: LIST ($count-base averaged @sums)
sub _average_periodic_sums {
   my $count = shift;
   map { $_ / $count } @_;
}

# arg: _average_periodic_sums(...)
# ret: diff between max and min point
sub _evaluate_height {
   #TODO maybe re-implement with single pass
   use List::Util qw( max min );
   max(@_) - min(@_);
}

# arg0: $period
# arg1: lower threshold
# ret: Boolean
sub _check_period {
   my $period = $_[0];

   _evaluate_height _average_periodic_sums _collect_periodic_sums $period, 'full'

   #TODO how to check if period is correct...?
}

# arg: --
# ret: HASHref( period => delta )
sub _run_with_periods {
   my $from = ($min_period + 1) * 10;
   my $to = @ARR / $min_pieces;
   die "Too short ARR from=$from to=$to" unless $from < $to;
   die '$min_pieces logic is broken' unless floor($to) == $to;

   my %rc;

   for my $curr ($from..$to) {
      $rc{$curr} = _evaluate_height(
         _average_periodic_sums _collect_periodic_sums $curr
      );
   }

   \%rc;
}

# arg: LIST of values
# ret: period
sub caler_fperiod {
   shift while @_ % $min_pieces;
   @ARR = reverse @_;

   # TODO algorithm ?
   my $period = -1;
   my %deltas = %{_run_with_periods()};
   my %period_blacklist;
   my @sorted;

   # LOOP:
   while (1) {
      # - exclude keys from %period_blacklist
      delete @deltas{keys %period_blacklist};

      # - range remaining keys $hr->{} by values (deltas?)
      @sorted = sort {$deltas{$b} <=> $deltas{$a} || $a <=> $b} keys %deltas;

      # - if hash is empty: die with period unfound
      last unless @sorted;

      # - select the best key
      my $probe = $sorted[0];

      # - check if it's a correct period
      if (_check_period($probe)) {
         # -- correct: return and end the algorithm
         $period = $probe;
         last;
      } else {
         # -- incorrect: it and it's divisors should be blacklisted

         # TODO remove external dependency
         use caler_period '_get_divisors';

         @period_blacklist{_get_divisors($probe)} = ();
      }

      # - repeat LOOP
   }

   die 'caler_period unable to calculate' if $period < 0;

   #TODO
   # - try to reduce $period using _get_divisors

   return $period;
}

1;
