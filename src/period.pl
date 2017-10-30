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
my %PT; # period table

my $_DEBUG = 0;

# print debug message if $_DEBUG
sub debug {
   print STDERR Dumper(@_) if $_DEBUG;
}

# evaluate covariance for two parts of @normalized_data slice
#
# cov(X, Y) = E[(X - E(X)) * (Y - E(Y))] ,
#
# where E(X) is expected value of X.
#
# arg0: length
# arg1: index of the first subarray
# arg2: index of the second subarray
#
# rc: covariance
sub cov($$$) {
    my ($n, $idx1, $idx2) = @_;

    my ($meanx, $meany) = (0, 0);

    for (my $i = 0; $i < $n; ++$i) {
        my $x_idx = $idx1 + $i;
        my $y_idx = $idx2 + $i;

        $meanx += $normalized_data[$x_idx];
        $meany += $normalized_data[$y_idx];
    }
    $meanx /= $n;
    $meany /= $n;


    my $cv = 0;

    for (my $i = 0; $i < $n; ++$i) {
        my $x_idx = $idx1 + $i;
        my $y_idx = $idx2 + $i;

        $cv += (($normalized_data[$x_idx] - $meanx) *
            ($normalized_data[$y_idx] - $meany));
    }

    $cv /= $n;
}

# evaluate standard deviation for @normalized_data slice
#
# s = sqrt( E(X**2) - E(X)**2 ) ,
#
# where E(X) is expected value of X.
# 
# arg0: length
# arg1: index of the subarray
#
# rc: standard deviation
sub stddev($$) {
    my ($n, $idx) = @_;

    my ($meanx, $meanxx) = (0, 0);

    for (my $i = 0; $i < $n; ++$i) {
        my $x_idx = $idx + $i;

        $meanxx += $normalized_data[$x_idx] ** 2;
        $meanx  += $normalized_data[$x_idx];
    }

    $meanxx /= $n;
    $meanx  /= $n;

    sqrt( $meanxx - $meanx ** 2 );
}

# evaluate Pearson correlation coefficient for two parts of @normalized_data
#
#            cov(X, Y)
# r = ----------------------- ,
#      stddev(X) * stddev(Y)
#
# where cov(X, Y) is covariance, stddev(X) is standard deviation.
# 
# arg0: length
# arg1: index of the first subarray
# arg2: index of the second subarray
#
# rc: correlation coefficient
sub correlate_arrays($$$) {
   my ($n, $idx1, $idx2) = @_;

   print STDERR "correlate_arrays( $n, $idx1, $idx2 )\n" if $_DEBUG;

   my $stddev1 = stddev($n, $idx1);
   my $stddev2 = stddev($n, $idx2);

   return -0 if abs($stddev1 * $stddev2) < 0.00000001;

   return cov($n, $idx1, $idx2) / (
       $stddev1 * $stddev2
   );
}

# insert current period in the PT if it correlates
sub calculate_period($) {
   my ($time) = @_;

   $time++;
   return if $time % 2;
   print STDERR "calculate_period( $time )\n" if $_DEBUG;

   # calculate correlation for two parts
   my $r = correlate_arrays( $time / 2, 0, $time / 2 );
   # print "$r\n";

   $PT{ $time / 2 }++ if $r > 0.95;
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

$, = "\n";
print STDERR sort {$a <=> $b} keys %PT;
