#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use Data::Dumper;

## User variables

my $corr_threshold = 0.9999;  # correlanion threshold
my $conv_threshold = 3;       # convolution_threshold

my $_DEBUG = 1;               # debug level

## System variables
my $count = 0;                # same as time
my $normalized_count = 0;     # same as normalized_time
my @data;                     # buf for input data
my @normalized_data;          # buf for normalized data
my %PT;                       # period table

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

   print STDERR "correlate_arrays( $n, $idx1, $idx2 )\n" if $_DEBUG > 5;

   my $stddev1 = stddev($n, $idx1);
   my $stddev2 = stddev($n, $idx2);
   print STDERR " stddev: ($stddev1) ($stddev2)\n" if $_DEBUG > 5;

   if ($stddev1 == 0 && $stddev2 == 0) {
      return 1 if $normalized_data[$idx1] == $normalized_data[$idx2];
   }

   return -0 if abs($stddev1 * $stddev2) < 0.00000001;

   return cov($n, $idx1, $idx2) / (
       $stddev1 * $stddev2
   );
}

# insert current period in the PT if it correlates
sub calculate_period($) {
   my ($time) = @_;

   return if $time % 2;
   print STDERR "calculate_period( $time )\n" if $_DEBUG > 4;

   # calculate correlation for two parts
   my $r = correlate_arrays( $time / 2, 1, 1 + $time / 2 );
   print "Correlation: $r\n" if $_DEBUG > 4;

   $PT{ $time / 2 }++ if $r > $corr_threshold;
}

# iterate over the PT and check every periods
sub check_periods($) {
   my ($time) = @_;

   print STDERR "check_periods( $time )\n" if $_DEBUG > 3;

   for my $key (keys %PT) {
      next if $time == 2 * $key;
      next if $time % $key;

      my $r = correlate_arrays( $key, 1 + $time - 2 * $key, 1 + $time - $key );
      print STDERR " check: time=$time key=$key r=$r\n" if $_DEBUG > 3;

      if ($r > $corr_threshold) {
         $PT{$key}++;
      } else {
         delete $PT{$key};
      }
   }
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

      calculate_period($normalized_count) if $normalized_count > 0;
      check_periods($normalized_count);

      $normalized_count++;
   }
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

   print STDERR Dumper(\@data) if $_DEBUG > 10;
   print STDERR Dumper(\@normalized_data) if $_DEBUG > 8;
   print STDERR Dumper(\%PT) if $_DEBUG > 7;
}

#$\ = "\n";
#print for sort {$a <=> $b} keys %PT;
#print $_ / 1 . " $PT{$_}" for sort {$a <=> $b} keys %PT;
print Dumper(\%PT);

my ($prev, $mean, $N, %periods) = (0);
for (sort {$a <=> $b} keys %PT) {
   if ($prev + $conv_threshold >= $_) { 
      $mean *= $N++;
      $mean += $_;
      $mean /= $N
   } else {
      $periods{$mean} = $N if defined $N;
      $mean = $_;
      $N = 1
   }

   $prev = $_
}

$periods{$mean}=$N;
print Dumper(\%periods);
