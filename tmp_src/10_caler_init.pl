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

#TODO debug: how does caler_period() return different values on the same input
# calculate period
my $period;
$period = @input % 2 ?
caler_period(@input[2..$#input]) : caler_period(@input[1..$#input]);

# split @input to groups
my @groups = carr_periodize($period, @input[1..$#input]);

#TODO estimate Nu for groups
# estimate Mean from groups
my @lambdas = carr_average_groups(@groups);

# SIN= $mean + $A * sin($w * t + $fi)
my ($mean, $A, $w, $fi) = carr_sine_approx($period, @lambdas);

print((join "\n", "Period= $period", "Mean= ...", "Nu= ...",
      "lambda(t)= $mean + $A * sin($w * t + $fi)",
      "f(lambda(t), x)= ..."), "\n");
