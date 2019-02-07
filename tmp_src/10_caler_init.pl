#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';

use lib '.';
use caler_arr;
use caler_fperiod;

# This file MUST get IAT form 0_csv_prepare.sh on STDIN.

sub _ttyerr { POSIX::isatty STDERR and print STDERR "* " . time . " @_" }
sub _ttyerrs { POSIX::isatty STDERR and print STDERR " @_\n" }

_ttyerr "Analysis begin...\n";

_ttyerr "Reading...";
my @input = carr_read();
_ttyerrs "Got " . @input . " records.";

# compute lambdas
_ttyerr "Inversion";
@input = carr_inverse(@input);
_ttyerrs "complete...";

# perform really strange interpolation
_ttyerr "Interpolation";
@input = carr_interpolate(@input);
_ttyerrs "complete...";

# output original array
#carr_dump(@input);

die 'Too few elements in @arr' if @input < 3;

# calculate period
my $period;
_ttyerr "Period estimation...";
$period = caler_fperiod(@input[1..$#input]);
_ttyerrs "Got P= $period";

# split @input to groups
_ttyerr "Group splitting";
my $pad = @input % $period;
my @groups = carr_periodize($period, @input[$pad..$#input]);
_ttyerrs "complete...";

# estimate Mean for groups
_ttyerr "Lambdas preparation";
my @lambdas = carr_average_groups(@groups);
_ttyerrs "complete...";
carr_dump(0, @lambdas);

# SIN= $mean + $A * sin($w * t + $fi)
_ttyerr "Lambdas sine approximation";
my ($mean, $A, $w, $fi) = carr_sine_approx($period, @lambdas);
_ttyerrs "complete...";

#TODO check if Fast way is OK
# Expensive way:
# my $Nu = carr_stddev(@input[1..$#input]) / carr_mean(@input[1..$#input]);
# Fast way:
_ttyerr "Nu calculation";
my $Nu = carr_stddev(@lambdas) / $mean;
_ttyerrs "complete...";

print((join "\n", "Period= $period", "Mean= $mean", "Nu= $Nu",
      "lambda(t)= $mean + $A * sin($w * t + $fi)",
      "f(lambda(t), x)= ..."), "\n");

_ttyerr "Analysis end.\n";
