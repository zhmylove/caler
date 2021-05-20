#!/usr/bin/perl
#made by: KorG
use v5.18;
use strict;
use warnings;

use Math::LinearApprox "linear_approx";

# This script just reads time, load and optional number of vms and produces valid output for the NN

# We have to optimize the angle to make it as compact as to fit into 3 bits
# 3 bits = 0..7
sub optimize_angle {
    my $sign = 4;

    # Process negative
    if ($_[0] < 0) {
        $sign = 0;
        $_[0] *= -1;
    }

    # Maybe we want to optimize it later on !!! TODO
    my $sector = 0;
    if ($_[0] >= 1) { # 45 degrees
        $sector = 3;
    } elsif ($_[0] >= 0.5) { # ~30 degrees
        $sector = 2;
    } elsif ($_[0] >= 0.1) { # ~6 degrees
        $sector = 1;
    }

    return $sign + $sector;
}

my @prev_load;

while (defined($_ = <>)) {
    my ($time, $load, $vms) = /(\d+)\s+([\d.]+)\s*(\d*)/ or die "Unknown format!";

    push @prev_load, $load;
    shift @prev_load if @prev_load > 4;

    # Here we'll skip first 3 lines to gather info
    next unless @prev_load == 4;

    my $i = 1;
    my $angle = (linear_approx([map { $i++, $_ ;} @prev_load]))[0];
    my $p_angle = optimize_angle $angle;

    my $p_load = sprintf "%d", (0.5 + $load * 10);

    print "$time $p_load $p_angle" . (length $vms ? " $vms" : "") . $/;
}
