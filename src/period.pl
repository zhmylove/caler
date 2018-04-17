#!/usr/bin/perl
# made by: KorG

use Math::Trig qw(asin pi rad2deg);
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

      unless ($CFG{magic}) {
         calculate_period($normalized_count) if $normalized_count > 0;
         check_periods($normalized_count);
      }

      $normalized_count++;
   }
}

## Main routine
# parse arguments
while (defined ($_ = $ARGV[0])) {
   last if /^[^-]/ || (/^--$/ && shift);

   my $valid = 0;

   $valid++, $CFG{notime} = 1 if /^-notime$/ || /^-nt$/;
   $valid++, $CFG{fast}   = 1 if /^-fast$/   || /^-f$/;
   $valid++, $CFG{magic}  = 1 if /^-magic$/  || /^-m$/;

   die "Invalid key specified: $_\n" unless $valid;

   shift;
}

$corr_threshold = $ENV{_R} if $_DEBUG && defined $ENV{_R};

goto MAGIC2 if $CFG{magic};

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

unless ($CFG{magic}) {
   die "No data mined!\n" unless keys %PT;
}

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

unless ($CFG{magic}) {
# Off-line analysis: convolution of the results, if too many of them
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

} else {
   print STDERR "\nDoing magic! Period is HARD defined!\n\n";
}

sub get_indexes {
   map {$_[1]+$_} grep {!($_ % $_[0]) && $_ + $_[1] < $normalized_count} 
   (0..$normalized_count-1)
}

my @lambdas = ();
my $lambda_mean = 0;
my $avg = $sums->sum() / $normalized_count;
for my $i (0..$period) {
   $lambdas[$i] = 0;
   my @measurements = @normalized_data[get_indexes($period, $i)];
   $lambdas[$i] += $_ for @measurements;
   $lambdas[$i] /= @measurements;
   $lambda_mean += $lambdas[$i];
}
$lambda_mean /= @lambdas;

MAGIC2:

$period = 65; # TODO: DELETE, needed by approximation for accuracy

@lambdas = (
   9.38426527958388, 9.92457737321196, 10.5591677503251, 10.8289986996099, 11.5078023407022, 11.9297789336801, 12.2906371911573, 12.7100130039012, 13, 13.6521456436931, 13.9089726918075, 14.2275682704811, 14.3810143042913, 14.5975292587776, 14.8276983094928, 14.8335500650195, 14.9317295188557, 15.1573472041612, 14.7607282184655, 15.0305591677503, 14.7204161248375, 14.5819245773732, 14.7093628088427, 14.146944083225, 14.0650195058518, 13.8231469440832, 13.3771131339402, 12.9180754226268, 12.5682704811443, 12.0858257477243, 11.8218465539662, 11.2295188556567, 10.8283485045514, 10.3407022106632, 9.8667100130039, 9.06371911573472, 8.91807542262679, 8.39596879063719, 7.98308392973325, 7.37540663630449, 7.16785946649317, 6.75211450878334, 6.31880286271958, 5.96421600520494, 5.74300585556278, 5.57254391672088, 5.41574495770982, 5.19388418998048, 5.05465191932336, 4.95640858815875, 4.94274560832791, 5.09954456733897, 5.14638906961614, 5.20104098893949, 5.35328562134027, 5.44502277163305, 5.82498373454782, 6.03318152244632, 6.56408588158751, 6.82433311646064, 7.1665582303188, 7.54391672088484, 8.0793754066363, 8.54716981132075, 9.12947299934938
);

$lambda_mean = sub { my $sum = 0; $sum += $_ for @_; $sum /= @_; }->(@lambdas);


my $lambda_sq = 0;
$lambda_sq += ($_-$lambda_mean)**2 for @lambdas;
my $A  = sqrt(2/$#lambdas * $lambda_sq); # Sine amplitude

# Sine phase
my $fi1 = ($lambdas[0] - $lambda_mean) / $A;
$fi1 = 1 if $fi1 > 1;
$fi1 = -1 if $fi1 < -1;
$fi1 = asin($fi1);
my $fi2 = pi - $fi1;

sub check_sine_approximation($) {
   my $fi = $_[0];
   my $correlation = 0;
   my (@old_normalized_data, $old_normalized_count, $old_sums, $old_squares) = (
      @normalized_data, $normalized_count, $sums, $squares
   ); # Perl doesn't allow me to localize this variables : (

   ($sums, $squares) = (psum->new(), psum->new());
   @normalized_data = @lambdas;
   $normalized_count = 2 * @lambdas - 1;
   $normalized_data[$_+@lambdas] = $A * sin(
      $_*pi*2/$period + $fi) for 0..@lambdas-1;
   $sums->add($_) and $squares->add($_**2) for @normalized_data;
   $normalized_count = 2 * @lambdas - 1;

   $correlation = correlate_arrays(scalar @lambdas, 0, scalar @lambdas);
   (@normalized_data, $normalized_count, $sums, $squares) = (
      @old_normalized_data, $old_normalized_count, $old_sums, $old_squares
   );
   return $correlation;
}

my ($c1,$c2) = (check_sine_approximation($fi1),check_sine_approximation($fi2));
my ($correlation, $fi) = ($c1 > $c2) ? ($c1, $fi1) : ($c2, $fi2);

if ($_DEBUG > 0) {
   print STDERR "\@lambdas = (@lambdas)\n\n";
}

print "lambda(t) = $lambda_mean + $A * sin(t*2*3.14/$period + $fi)\n";
print "Correlation: $correlation\n";
