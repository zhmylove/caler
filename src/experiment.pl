#!/usr/bin/perl

use strict;
use warnings;
use feature 'signatures';
use List::Util qw( tail uniq );
use Storable;
use lib '.';
use caler_fperiod;

my $DB = "$0.db";
my $file = "$ENV{HOME}/Downloads/rkk3.csv";
my @lines = map /(\d+)$/g, do { local(@ARGV) = $file; <> };

my $db = eval { retrieve $DB } || {};
$\ = $/; # auto newline
$| = 1; # auto flush

sub period_to_str($period) {
    return "NOT FOUND" unless defined $period;

    # 5 minutes scale in the data
    my $minutes = $period * 5;

    return sprintf "[%d] %d days %d hours %d minutes", $period, $minutes / 1440, $minutes % 1440 / 60, $minutes % 1440 % 60 if $minutes > 24 * 60;
    return sprintf "[%d] %d hours %d minutes", $period, $minutes / 60, $minutes % 60 if $minutes > 60;
    return sprintf "[%d] %d minutes", $period, $minutes;
}

sub print_period_for_number_of_rows($number=$_) {
    my $period;
    $number = int($number);

    printf "Period for %6d last rows is ", $number;
    return print $db->{$number} if defined $db->{$number};

    eval { $period = caler_fperiod(tail($number, @lines)) };
    $period = period_to_str($period);

    $db->{$number} = $period;
    store $db, $DB;
    print $period;
}

print_period_for_number_of_rows for uniq sort { $b <=> $a }

# Some hardcoded numbers
10, 20, 30, 50, 100, 200, 300, 400, 1024,

# Several days
(map { 288 * $_ } map {; $_, $_ / 3, 2 * $_ / 3 } (1, 2, 4, 7, 8, 10, 50, 100)),

# Several weeks
(map { 2016 * $_ } map {; $_, $_ / 3, 2 * $_ / 3 } (1, 2, 4, 7, 8, 10, 50, 100)),

# Half a data
0+@lines / 2,

# All the data
0+@lines,

;

print "   Doubling the data...";

# Several times for 2x data
for (1..4) {
    @lines = (@lines) x 2;
    print_period_for_number_of_rows 0+ @lines;
}
