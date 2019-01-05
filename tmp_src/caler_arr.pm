#!/usr/bin/perl
# Made by: KorG

package caler_arr;

=head1 NAME

B<caler_arr.pm> is a module for simple array operations.

=cut 

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use Exporter 'import';
our @EXPORT = qw(
carr_read carr_dump carr_inverse carr_interpolate carr_sine_approx carr_mean
carr_stddev carr_periodize carr_average_groups
);

use POSIX;
use List::Util qw( sum );

=head1 FUNCTIONS

=over 1

=item B<stub()>
-- just a stub function
=cut
sub stub {
   print 1;
}

=item B<carr_average_groups()>
-- Take B<carr_periodize()> output and return B<carr_mean> for each group.
=cut
sub carr_average_groups {
   map { carr_mean(@{$_}) } @_;
}

=item B<carr_periodize($period, @arr)>
-- Extract values from I<@arr> on a I<$period> basis.

Returns I<$period> ARRAY references with extracted values.
For instance, carr_periodize(2, 1, 2, 3, 4) = ([1, 3], [2, 4]);
=cut
sub carr_periodize {
   my $period = shift;
   my @arr = @_;

   die "Invalid ARRAY for periodization" if @arr % $period;

   my @result;
   for my $offset (0..$period-1) {
      # Expensive trash
      push @result, [ @arr[grep { ! (($_ - $offset) % $period) } 0..$#arr] ];
   }

   return @result; # explicit return
}

=item B<carr_stddev(@arr)>
-- compute standard deviation for I<@arr>.

NOT OPTIMIZED! See B<psum.pm> for basic optimization.
=cut
sub carr_stddev {
   my @arr = @_;

   my $meanx = carr_mean(@arr);
   my $meanxx = sum (map $_**2, @arr) / @arr;

   sqrt( abs($meanxx - $meanx ** 2) );
}

=item B<carr_mean(@arr)>
-- compute mean for I<@arr>.
=cut
sub carr_mean {
   my $sum = 0;
   $sum += $_ for @_;
   $sum /= @_;
}

=item B<carr_sine_approx($period, @arr)>
-- approx periodic I<@arr> with sine function.

`return ($mean, $A, $omega, $fi);'
is equivalent to SIN= $mean + $A * sin($omega * t + $fi)
=cut
sub carr_sine_approx {
   my $period = shift;
   my @arr = @_;

   my $mean = carr_mean(@arr);

   my $arr_sq = 0;
   $arr_sq += ($_ - $mean)**2 for @arr;

   my $A = sqrt(2/$#arr * $arr_sq); # Sine amplitude
   my $w = 2 * M_PI / $period;

   # Sine phase
   my $fi1 = ($arr[0] - $mean) / $A;
   $fi1 = 1 if $fi1 > 1;
   $fi1 = -1 if $fi1 < -1;
   $fi1 = asin($fi1);
   my $fi2 = M_PI - $fi1;

   # Semi-period sum
   our $speriod = floor($period / 2);
   die "Too short period" if $speriod <= 1;

   our $speriod_sum = sum(@arr[0..$speriod]);

   # Internal function, use carefully
   # used vars: $mean $A $w $speriod $speriod_sum $fi
   # args: $fi
   sub _check_sine_approximation($$$$$$) {
      my ($C, $A, $W, $speriod, $sum, $fi) = @_;
      die unless defined $fi;

      # Compute sum for semi-period
      abs $sum - sum map { $C + $A * sin($_ * $W + $fi) } 0..$speriod;
   }

   my ($c1, $c2) = (
      _check_sine_approximation($mean, $A, $w, $speriod, $speriod_sum, $fi1),
      _check_sine_approximation($mean, $A, $w, $speriod, $speriod_sum, $fi2)
   );

   my ($correlation, $fi) = ($c1 < $c2) ? ($c1, $fi1) : ($c2, $fi2);

   return ($mean, $A, $w, $fi);
}

=item B<carr_interpolate(@arr)>
-- really strange interpolation.

This algorithm wents backwards through I<@arr> and fills any I<undef> with
a closest defined right-hand side value.
=cut
sub carr_interpolate {
   # An array should at least contain [0] and [1]
   die "carr_interpolate: empty array\n" if @_ <= 1;

   my $rvalue;
   my @arr;
   die "carr_interpolate: ivalid rvalue in array\n" unless defined $_[$#_];
   for (my $i = $#_; $i >= 1; $i--) {
      $rvalue = $_[$i] if defined $_[$i];
      $arr[$i] = $rvalue;
   }

   return @arr; # explicit return
}

=item B<carr_inverse()>
-- assuming values are IAT, produce array of lambdas = 1/IAT
=cut
sub carr_inverse {
   map { defined $_ ? 1 / $_ : undef } @_;
}

=item B<carr_dump(@arr)>
-- print the arr elements with corresponding indicies
=cut
sub carr_dump {
   if (isatty(\*STDOUT)) {
      local $\ = "";
      for (my $i = 1; $i < @_; $i++) {
         print "[$i]=\"" . ($_[$i] // '') . "\" ";
      }
      print "\n";
   } else { # dump in carr_read format
      local $\ = "\n";
      for (my $i = 1; $i < @_; $i++) {
         next unless defined $_[$i];
         print "$i $_[$i]";
      }
   }
}

=item B<carr_read()>
-- return readed from STDIN array.  

Input format: <index> <value>.  I<index> should start with 1 and increase
every line.
=cut
sub carr_read {
   my $prev_index = 1; # should start with 1
   my $prev_cnt = 0;
   my @arr;
   my @line;
   while(defined($_ = <STDIN>) && (
         @line = /^\s*(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$/
      )) {

      my $new_index = int($line[0] + 0.49999);
      die "carr_read: invalid index $line[0]\n" if $new_index < $prev_index;

      if ($new_index != $prev_index) {
         $arr[$new_index] = $line[1]; # let autovivify holes w/ undef
         $prev_cnt = 1;
         $prev_index = $new_index;
      } else {
         $arr[$new_index] = $arr[$new_index] * $prev_cnt + $line[1];
         $arr[$new_index] /= ++$prev_cnt;
      }
   }

   die "carr_read: invalid format: $_\n" if defined $_;

   return @arr; # explicit return
}

=back
=cut

# TODO list
# - optimize my @arr = ...
# - optimize functions w/ psum
# - memoize (?)

1;
