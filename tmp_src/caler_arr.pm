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
carr_read
carr_dump
carr_inverse
carr_interpolate
carr_sine_approx
);

use POSIX;
use Math::Trig qw( asin pi rad2deg );

=head1 FUNCTIONS

=over 1

=item B<stub()>
-- just a stub function
=cut
sub stub {
   print 1;
}

=item B<carr_sine_approx($period, @arr)>
-- approx periodic I<@arr> with sine function.

`return ($mean, $A, $omega, $fi);'
is equivalent to SIN= $mean + $A * sin($omega * t + $fi)
=cut
sub carr_sine_approx {
   my $period = shift;
   my @arr = @_;

   my $mean = sub {
      my $sum = 0;
      $sum += $_ for @_;
      $sum /= @_;
   }->(@arr);

   my $arr_sq = 0;
   $arr_sq += ($_ - $mean)**2 for @arr;

   my $A = sqrt(2/$#arr * $arr_sq); # Sine amplitude

   # Sine phase
   my $fi1 = ($arr[0] - $mean) / $A;
   $fi1 = 1 if $fi1 > 1;
   $fi1 = -1 if $fi1 < -1;
   $fi1 = asin($fi1);
   my $fi2 = pi - $fi1;

   sub check_sine_approximation($) {
      return 0.9;
      ...
      #TODO fix
   }

   my ($c1, $c2) = (
      check_sine_approximation($fi1),
      check_sine_approximation($fi2)
   );

   my ($correlation, $fi) = ($c1 > $c2) ? ($c1, $fi1) : ($c2, $fi2);

   return ($mean, $A, (2 * pi / $period), $fi);
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

Input format: <index> <value>.  I<index> should increment every line.
=cut
sub carr_read {
   my $prev_index = 0;
   my @arr;
   my @line;
   while(defined($_ = <STDIN>) && (
         @line = /^\s*(\d+)\s+(\d+(?:\.\d+)?)\s*$/
      )) {
      die "carr_read: invalid index $line[0]\n" if $line[0] <= $prev_index;
      $arr[$line[0]] = $line[1]; # let autovivify holes w/ undef
      $prev_index = $line[0];
   }

   die "carr_read: invalid format: $_\n" if defined $_;

   return @arr; # explicit return
}

=back
=cut

1;
