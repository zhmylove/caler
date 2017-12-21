#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use lib '.';
use psum;

use Data::Dumper;

## User variables

my $corr_threshold = 0.8;     # correlanion threshold
my $conv_threshold = 3;       # convolution_threshold

my $_DEBUG = $ENV{_D} // 0;   # debug level

## System variables
my $count = 0;                # same as time
my $normalized_count = 0;     # same as normalized_time
my @data;                     # buf for input data
my @normalized_data;          # buf for normalized data
my @time;                     # buf for actual time (see notime)
my %PT;                       # period table
my %CFG;                      # parameters of the script
my $period = 0;               # evaluated period
my $sums = psum->new();       # prefix sums for just sum
my $squares = psum->new();    # prefix sums for sums of squares

# evaluate covariance for two parts of @normalized_data slice
#
# cov(N, X, Y) = sum[(X - E(X)) * (Y - E(Y))] / N,
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

    my ($sumx, $sumy) = (
      $sums->sum($idx1 + $n - 1, $idx1 - 1),
      $sums->sum($idx2 + $n - 1, $idx2 - 1),
    );

    my ($meanx, $meany) = (
      $sumx / $n,
      $sumy / $n,
    );

    my $cov = 0;

    for (my $i = 0; $i < $n; ++$i) {
        $cov += $normalized_data[$idx1++] *
            $normalized_data[$idx2++];
    }

    $cov += $meanx * $meany * $n - $meany * $sumx - $meanx * $sumy;

    $cov /= $n;
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

    my ($meanxx, $meanx) = (
      $squares->sum($idx + $n - 1, $idx - 1) / $n,
      $sums->sum($idx + $n - 1, $idx - 1) / $n,
    );

    sqrt( abs($meanxx - $meanx ** 2) );
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
   print STDERR "Correlation: $r\n" if $_DEBUG > 4;

   $PT{ $time / 2 } += $r if $r > $corr_threshold;
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
         $PT{$key} += $r;
      } else {
         delete $PT{$key};
      }
   }
}

# add new value to normalized table
sub add_normalized($$) { 
   my ($time, $value) = @_;

   my $previous = $normalized_data[$normalized_count - 1] // $value;

   my $step = ( $value - $previous ) / ( $time - $normalized_count + 1 );
  
   while ($normalized_count <= $time) {
      $normalized_data[$normalized_count] = (
         $normalized_data[$normalized_count - 1] || $value
      ) + $step;

      $sums->add($normalized_data[$normalized_count]);
      $squares->add($normalized_data[$normalized_count]**2);
      if ($normalized_count > 2 && $normalized_count % 2 == 0) {
        # TODO: check, delete #, recount indexes above
        #$sums->shift;
        #$squares->shift;
        # perform shift every even time and use $arr[0] and $arr[$#arr]
      }

      calculate_period($normalized_count) if $normalized_count > 0;
      check_periods($normalized_count);

      $normalized_count++;
   }
}

## Main routine
# parse arguments
while (defined ($_ = $ARGV[0])) {
   last if /^[^-]/ || (/^--$/ && shift);

   my $valid = 0;

   $valid++, $CFG{notime} = 1 if /^-notime$/ || /^-nt$/;
   $valid++, $CFG{fast}   = 1 if /^-fast$/ || /^-f$/;

   die "Invalid key specified: $_\n" unless $valid;

   shift;
}

# slurp stdin
while (defined($_ = <>)) {
   chomp;

   my @line = split / /; 

   warn "Invalid format: [$_]\n" and next unless scalar @line == 2;

   my ($time, $value) = @line;

   if ($CFG{notime}) {
      push @time, $time;
      $time = +@time;
   }

   warn "Time goes back: [$_]\n" and next if $time < $normalized_count;

   $data[$count++] = { $time => $value };
   add_normalized($time, $value);

   # just skip period estimation until the end of stdin
   next if ($CFG{fast});

   # period estimation at the current time
   my $max = $PT{ (sort { $PT{$b} <=> $PT{$a} } keys %PT)[0] // 0 };
   if (defined $max) {
      my @max = sort { $a <=> $b } grep { $PT{$_} == $max } keys %PT;

      print "median: {@max}\n" if $_DEBUG > 1;

      $period = $max[$#max / 2] // 0; # median
      #TODO wrap around even median (@max) number of elements
   }

   print STDERR Dumper(\@data) if $_DEBUG > 10;
   print STDERR Dumper(\@normalized_data) if $_DEBUG > 8;
   print STDERR Dumper(\%PT) if $_DEBUG > 7;
   print STDERR "= [$time] period = $period\n" if $_DEBUG > 2;
}

if ($CFG{fast}) {
   my $max = $PT{ (sort { $PT{$b} <=> $PT{$a} } keys %PT)[0] // 0 };
   if (defined $max) {
      my @max = sort { $a <=> $b } grep { $PT{$_} == $max } keys %PT;

      print "median: {@max}\n" if $_DEBUG > 1;

      $period = $max[$#max / 2] // 0; # median
      #TODO wrap around even median (@max) number of elements
   }

   print STDERR Dumper(\@data) if $_DEBUG > 10;
   print STDERR Dumper(\@normalized_data) if $_DEBUG > 8;
   print STDERR Dumper(\%PT) if $_DEBUG > 7;
   print STDERR "= [END] period = $period\n" if $_DEBUG > 2;
}

die "No data mined!\n" unless keys %PT;

if ($_DEBUG > 0) {
   for ((sort { $PT{$b} <=> $PT{$a} } keys %PT)[0..30]) {
      if ($CFG{notime}) {
         print STDERR
         "($time[$_ - 1]) (($time[$_])) ($time[$_ + 1]) $_ => $PT{$_}\n";
      } else {
         print STDERR "$_ => $PT{$_}\n";
      }
   }
}

# Off-line analysis: convolution of the results, in case of too many of them
my ($prev, $mean, $N, %periods) = (0, 0);
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
print STDERR Dumper(\%periods) if $_DEBUG > 0;

my $offline_max = (sort { $b <=> $a } values %periods)[0] // 0;
my $period_offline = (
   sort { $a <=> $b } grep { $periods{$_} == $offline_max } keys %periods
)[0] // 0;

# results
$period = $time[$period - 1] if $CFG{notime};
$period_offline = $time[$period_offline - 1] if $CFG{notime};

print "On-line: $period\n";
printf "Rounded On-line: %.0f\n", $period;
print "Off-line: $period_offline\n";
