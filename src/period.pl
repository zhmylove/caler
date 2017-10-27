#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use Data::Dumper;

my $count = 0;
my $normalized_count = 0; # same as normalized_time
my @data;
my @normalized_data;

my $_DEBUG = 1;

# print debug message if $_DEBUG
sub debug {
   print STDERR Dumper(@_) if $_DEBUG;
}

# evaluate correlation coefficient for two parts of @normalized_data
#                     n * sum(x*y) - sum(x) * sum(y)
# r = -------------------------------------------------------------
#     sqrt( (n * sum(x^2) - sum(x)^2) * (n * sum(y^2) - sum(y)^2) )
# 
# arg0: length
# arg1: index of the first subarray
# arg2: index of the second subarray
#
# rc: correlation coefficient
sub correlate_arrays($$$) {
   my ($n, $idx1, $idx2) = @_;

   print STDERR "correlate_arrays( $n, $idx1, $idx2 )\n";

   my ($sum_x, $sum_y, $sum_xy, $sum_x2, $sum_y2);

   for (my $i = 0; $i < $n; $i++) {
      my $x_idx = $idx1 + $i;
      my $y_idx = $idx2 + $i;

      $sum_x  += $normalized_data[$x_idx];
      $sum_y  += $normalized_data[$y_idx];
      $sum_xy += $normalized_data[$x_idx] * $normalized_data[$y_idx];
      $sum_x2 += $normalized_data[$x_idx] ** 2;
      $sum_y2 += $normalized_data[$y_idx] ** 2;

      debug("--");
      debug("n=");
      debug(\$n);
      debug("sum_x=");
      debug(\$sum_x);
      debug("sum_y=");
      debug(\$sum_y);
      debug("sum_xy=");
      debug(\$sum_xy);
      debug("sum_x2=");
      debug(\$sum_x2);
      debug("sum_y2=");
      debug(\$sum_y2);
   }

   return ($n * $sum_xy - $sum_x * $sum_y) / sqrt(
      ($n * $sum_x2 - $sum_x ** 2) * ($n * $sum_y2 - $sum_y ** 2)
   );
}

# insert current period in the PT if it correlates
sub calculate_period($) {
   my ($time) = @_;

   $time++;
   return if $time % 2;
   print STDERR "calculate_period( $time )\n" if $_DEBUG;

   # calculate correllation for two parts
   my $r = correlate_arrays( $time / 2, 0, $time / 2 );
   print "$r\n";
}

# iterate over the PT and check every periods
sub check_periods($) {
   my ($time) = @_;
}

# add new value to normalized table
sub add_normalized($$) { 
   my ($time, $value) = @_;

   my $previous = $normalized_data[$normalized_count - 1] // $value;

   my $step = (  $value - $previous ) / ( $time - $normalized_count + 1 );

   while ($normalized_count <= $time) {
      $normalized_data[$normalized_count] = (
         $normalized_data[$normalized_count - 1] || $value
      ) + $step;

      $normalized_count++;
   }

   calculate_period($time) if $time > 0;
}

# main routine
while (defined($_ = <>)) {
   chomp;

   my @line = split / /; 

   warn "Invalid format: [$_]\n" and next unless scalar @line == 2;

   my ($time, $value) = @line;

   warn "Time goes back: [$_]\n" and next if $time < $normalized_count;

   $data[$count++] = { $time => $value };
   add_normalized($time, $value);

   debug(\@data);
   debug(\@normalized_data);
}
