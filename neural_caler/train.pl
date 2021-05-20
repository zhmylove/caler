#!/usr/bin/perl
#made by: KorG
use v5.18;
use strict;
use warnings;
use Storable qw( lock_nstore lock_retrieve );
use lib 'local/lib/perl5';

my $NN_FILE = "NN.dat";
my $TRAIN_FILE = "data/5_prepVal_prepAngle_resultNumberVMs";

use AI::NeuralNet::Simple;

# Create the network
my $net = AI::NeuralNet::Simple->new(9, 2, 3);

sub number_of_vms_to_outputs {
    for ($_[0]) {
        $_ == 1 && return (1, 0, 0);
        $_ == 2 && return (0, 1, 0);
        $_ == 3 && return (0, 0, 1);
    }
    die "Unknown number of VMs!";
}

# Parse the file into @SET
my @SET;
open my $DATA, "<", $TRAIN_FILE or die $!;
while (my ($prep_val, $prep_angle, $num_vms) = ((<$DATA> // "") =~ /(\d+)\s+(\d+)\s+(\d+)/)) {
    # Here we have everything inside variables
    my $inputs = [map int, split //, sprintf "%06b%03b", $prep_val, $prep_angle];
    my $outputs = [number_of_vms_to_outputs $num_vms];
    push @SET, $inputs, $outputs;
}
close $DATA;

# Train the network
$net->train_set(\@SET, 10000, 0.001);

# Save the network
rename "$NN_FILE.new", $NN_FILE if lock_nstore $net, "$NN_FILE.new";
