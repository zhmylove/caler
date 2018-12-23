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

# This file MUST get IAT form 0_csv_prepare.sh on STDIN.

my @input = carr_read();

# compute lambdas
@input = carr_inverse(@input);

# perform really strange interpolation
@input = carr_interpolate(@input);

carr_dump(@input);
