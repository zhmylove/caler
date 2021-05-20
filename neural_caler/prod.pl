#!/usr/bin/perl
#made by: KorG
use strict;
use warnings;
use Storable qw( lock_nstore lock_retrieve );
use lib 'local/lib/perl5';

my $NN_FILE = "NN.dat";

# Storable will load the module by itself
my $net = lock_retrieve $NN_FILE or die "Unable to read NN!";

sub winner_to_number {
    $_[0] + 1
}

# Parse string of "prep_val prep_angle"
while(<>) {
    my ($prep_val, $prep_angle) = /(\d+)\s+(\d+)/ or last;
    my $input = [map int, split //, sprintf "%06b%03b", $prep_val, $prep_angle];
    printf "input: %5s | binary: @{$input} | result: %d\n", "$prep_val, $prep_angle", winner_to_number($net->winner($input));
}
