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
use Data::Dumper; # debug?
use Memoize;
use POSIX;
use List::Util qw( sum max min );

use Exporter 'import';
our @EXPORT = qw( caler_fperiod );
our @EXPORT_OK = qw( _stddev _get_divisors );

our $DEBUG = $ENV{_DEBUG} // 1;
sub _debug { printf STDERR " * %s(%d%s\n",__PACKAGE__,time,"): @_" if $DEBUG; }

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

my $primes_to_use = 10; # number of primes to use from @primes
my $primes_to_use_initial = 10; # for multiple runs
my $min_period = _get_prime_sum($primes_to_use); # (lower bound)

# minimum number of pieces in period (upper bound)
# '6' looks quite good, due a week has 7 days and 6 is 7 - 1
my $min_pieces = 6;

# arg0: period
# ret: LIST of primes
sub _get_deltas_by_period {
   my $period = $_[0];

   die '_get_deltas_by_period: too short period' if $period <= $min_period;

   #TODO check both variants
   #v1# my $step = ($period / $min_period);
   my $step = ($period / $min_period);

   #v1# map { ($_ - 1) * $step } @primes[0..$primes_to_use-1];
   map { int(($_ - 1) * $step) } @primes[0..$primes_to_use-1];
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
   my @deltas = $_[1] ? (0) x ($period-1) : _get_deltas_by_period $period;

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
   max(@_) - min(@_);
}

# arg0: $period
# arg1: lower threshold
# ret: Boolean
sub _check_period {
   my $period = $_[0];
   my $lower_threshold = $_[1];

   my $height = _evaluate_height _average_periodic_sums _collect_periodic_sums(
      $period, 'check_full_period'
   );

   _debug "_check_period($period): h = $height >? t = $lower_threshold";
   return $height > $lower_threshold;
}

# arg: --
# ret: HASHref( period => delta )
sub _run_with_periods {
   my $from = ($min_period + 1) * $min_pieces;
   my $to = @ARR / $min_pieces;

   #TODO check if it's OK
   # adjust values for small arrays
   while ($from > $to && $primes_to_use >= 4) {
      _debug "reducing primes...";
      $min_period = _get_prime_sum(--$primes_to_use);
      $from = ($min_period + 1) * $min_pieces;
   }
   _debug "primes to use: $primes_to_use";

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

# arg: LIST
# ret: stddev of LIST
sub _stddev {
   my $meanx = sum(@_) / @_;
   my $meanxx = sum(map $_**2, @_) / @_;

   sqrt abs($meanxx - $meanx ** 2);
}

# arg: $period
# ret: stddev
sub _get_period_stddev {
   my $curr_period = shift;
   my $count = floor(@ARR / $curr_period);
   my $rc = 0;
   for my $offset (0..$curr_period-1) {
      my @values = @ARR[map { $offset + $_ * $curr_period } (0..$count-1)];
      $rc += _stddev(@values);
   }

   return $rc;
}
memoize('_get_period_stddev', LIST_CACHE => 'MERGE');

# arg: _average_periodic_sums(...)
# ret: LIST: (abs(max(@_)-$avg), abs(min(@_)-$avg))
sub _evaluate_signed_height {
   my $avg = sum(@_) / @_;
   (abs(max(@_) - $avg), abs(min(@_) - $avg));
}

# arg: $period
# ret: Boolean if $period is period of @array
sub _check_period_sum;
sub _check_period_sum {
   my $period = $_[0];

   sub __run {
      _evaluate_signed_height _average_periodic_sums(
         _collect_periodic_sums($_[0], 'check_full_period')
      );
   }

   my ($pre_up, $pre_down) = __run($period - 1);
   my ($up, $down) = __run($period);
   my ($post_up, $post_down) = __run($period + 1);

   my $rc = (
      $up > $pre_up && $up > $post_up &&
      $down > $pre_down && $down > $post_down
   );
   _debug "_check_period_sum($period): " . ($rc ? "True" : "False");
   _debug "... $pre_up $up $post_up : $pre_down $down $post_down";

   return $rc;
}

# arg: $period
# ret: Boolean if $period is period of @array
sub _check_period_stddev;
sub _check_period_stddev {
   my $period = $_[0];
   _debug "CHECKING $period...";
   my @stddev = (
      _get_period_stddev($period - 1),
      _get_period_stddev($period),
      _get_period_stddev($period + 1),
   );

   _debug "CHECK RESULTS $period: @stddev";
   if( $stddev[1] < $stddev[0] && $stddev[1] < $stddev[2] ){
      _debug "CHECK_OK $period: @stddev";
   }
   return $stddev[1] < $stddev[0] && $stddev[1] < $stddev[2];
}


# arg: number
# ret: LIST of divisors of number, including number
sub _get_divisors($);
sub _get_divisors($) {
   my $number = $_[0];

   my %rc;
   my $curr;

   for my $div (2..$number) {
      if ($number >= $div) {
         if ($number % $div == 0) {
            $rc{$div} = undef;
            $rc{$number} = undef;
            $curr = $number / $div;
            last if $curr == 1;
            $rc{$curr} = undef;
            @rc{_get_divisors($curr)} = undef;
         }
      } else { last }
   }

   return keys %rc;
}
memoize('_get_divisors', LIST_CACHE => 'MERGE');

# arg: LIST of values
# ret: period
sub caler_fperiod {
   _debug "entry";
   my $debug_start = time;

   # reset variables
   $primes_to_use = $primes_to_use_initial;
   $min_period = _get_prime_sum($primes_to_use); # (lower bound)

   shift while @_ % $min_pieces;
   @ARR = reverse @_;

   my $period = -1;

   _debug "_run_with_periods()";

   #TODO check another algo for %deltas estimation, based on stddev
   my %deltas = %{_run_with_periods()};

   my %period_blacklist;
   my @sorted;

   _debug "full sorted top 10: ", join " ", map {"$_($deltas{$_})"} (
      sort {$deltas{$b} <=> $deltas{$a} || $a <=> $b} keys %deltas
   )[0..9];

   _debug "LOOP entry";
   my $debug_iters = 0;
   # LOOP:
   ROUGH_LOOP: while (1) {
      $debug_iters++;
      # - exclude keys from %period_blacklist
      delete @deltas{keys %period_blacklist};

      # - range remaining keys $hr->{} by values (deltas?)
      @sorted = sort {$deltas{$b} <=> $deltas{$a} || $a <=> $b} keys %deltas;

      # - if hash is empty: die with period unfound
      last unless @sorted;

      # - select the best key
      my $probe = $sorted[0];
      _debug "LOOP iternation with probe=$probe";

      # - check if it's a correct period
      if (_check_period_stddev($probe)) {
         # -- correct: return and end the algorithm
         $period = $probe;
         last;
      } else {
         # -- incorrect: it and it's divisors should be blacklisted

         @period_blacklist{_get_divisors($probe)} = ();
      }

      # - repeat LOOP
   }

   _debug "LOOP return with period $period after $debug_iters iterations";
   die 'caler_period unable to calculate' if $period < 0;

   # - try to reduce $period using _get_divisors
   my @final_check = sort {$a <=> $b} grep {not exists $period_blacklist{$_}} (
      _get_divisors $period
   );

   _debug "final_check";

   die 'caler_period unable to (re)calculate' unless defined $deltas{$period};
   my $not_modified = 1;

   #TODO perhaps implement binary-search? Current: left-to-right approach
   my $lower_threshold = $deltas{$period} / 2;
   for my $curr (@final_check) {
      last if $curr >= $period;
      if (_check_period_stddev($curr) && _check_period_sum($curr)) {
         $period = $curr;
         $not_modified = 0;
      }
   }

   if ($not_modified && ! _check_period_sum($period)) {
      @period_blacklist{_get_divisors($period)} = ();
      _debug 'Returning to LOOP';
      goto 'ROUGH_LOOP';
   }

   _debug sprintf "return, spent: %.2f min", ((time - $debug_start) / 60);
   return $period;
}

1;
#TODO
#- use local-averaged function values instead of exact
#- use stddev for first stage
#- fix P/2 detection for even period
#- fix heartbeat
