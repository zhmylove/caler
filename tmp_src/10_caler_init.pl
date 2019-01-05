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
use caler_period;

# This file MUST get IAT form 0_csv_prepare.sh on STDIN.

my @input = carr_read();

# compute lambdas
@input = carr_inverse(@input);

# perform really strange interpolation
@input = carr_interpolate(@input);

# output original array
carr_dump(@input);

die 'Too few elements in @arr' if @input < 3;

# calculate period
my $period;
$period = @input % 2 ?
caler_period(@input[2..$#input]) : caler_period(@input[1..$#input]);

# split @input to groups
my @groups = carr_periodize($period, @input[1..$#input]);

# estimate Mean for groups
my @lambdas = carr_average_groups(@groups);
carr_dump(0, @lambdas);

# SIN= $mean + $A * sin($w * t + $fi)
my ($mean, $A, $w, $fi) = carr_sine_approx($period, @lambdas);

#TODO check if Fast way is OK
# Expensive way:
# my $Nu = carr_stddev(@input[1..$#input]) / carr_mean(@input[1..$#input]);
# Fast way:
my $Nu = carr_stddev(@lambdas) / $mean, "\n";

print((join "\n", "Period= $period", "Mean= $mean", "Nu= $Nu",
      "lambda(t)= $mean + $A * sin($w * t + $fi)",
      "f(lambda(t), x)= ..."), "\n");
