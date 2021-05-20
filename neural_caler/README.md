# How to run neural caler

`neural_caler.sh` is a shell script, which automates all the stuff for you.
In production you maybe want to replace somewhere around 25 line:

    perl prepare.pl < "$INPUT_STREAM" |

with a FIFO stream to make it work as a service.

In order to run testing build, please ensure you have
`data/1_time_workload_vms` with 110 lines and simply execute:

    $ ./neural_caler.sh

As a result you'll see 55 lines of predictions. Quite simple, huh?

This script will firstly train neural network (NN) while there are vms
are supplied (see "Input of the model").
And after training it will use it for predictions.
Neural network will be saved inside "NN.dat" file.

# Output of the model

The model can predict how many VMs do we need in order to avoid overload.
Prediction range is 1..3 VMs.
There are three neurons on the outer layer and the winner represents
the number of VMs as an index:
Winner of 0 means 1 VM requred, winner of 1 means 2 VMs required,
winner of 2 means 3 VMs required.

# Workload function

I've took a simple workload sine function:
Workload(t) = A * sin(B * t) + C.
Currently my coefficients are:

    A = 1.3
    B = 0.17
    C = 3

I've created a set of data from t = 1 up to t = 55.

# Input of the model

Obviously I can not use float numbers as the model's direct input.
Thus I have created prepare.pl, which takes:
 
    time workload optional_number_of_vms

and produces:

    time prepared_workload prepared_angle optional_number_of_vms

Please see how I am training the model in train.pl

# How to run manually

Firstly create NN.dat using train.pl
It will read the source file above and train the network.
After that you can run prod.pl and pass something on its stdin,
for example the test set:

    $ perl prod.pl < data/10_prepVal_prepAngle

As you can see, the lines of this file with PrepAngle value of 1 are:

    20  1
    21  1
    23  1
    25  1
    27  1
    33  1
    35  1
    37  1
    38  1
    40  1

If you specify now "39 1" on stdin, then NN will predict that you need 2 VMs:
    
    $ echo 39 1 | perl prod.pl
    Input: (39, 1) | binary: 1 0 0 1 1 1 0 0 1 | result: 2

# Deprecated 

There are some deprecated documentation, which I have to refactor and delete. I'll do it later.
Just do not read below this line. Thanks!

In order to make the model aware of the workload trend, I'm doing a 7 values averaging over the whole sequence:

    Average(t) = \fraq{\sum_{i=t-3}^{t+3} Workload(i)}{7}

As so for any t in [4, 52] I have average value. 
With the coefficients in question those belong to a range of [1.77, 4.23].

For each average value I've also computed an angle coefficient:

    Angle(t) = \sum_{i=t-3}^{t-1} Workload(i) - \sum_{i=t+1}^{t+3} Workload(i)

Those values are in a range of [-2.57, 2.57].

===

This I have to prepare Average(t) and Angle(t) to use it in the model as a binary values.

    PreparedAngle(t) = integer_round( 3 + Angle(t) )

This will produce a numbers in a range of [0, 6] so I'll use 3 neurons to represent it.

    PreparedValue(t) = integer_round( 10 * Average(t) )

This will produce a numbers in a range of [18, 42] so I'll use 6 neurons to represent it.

I've stored PreparedValue(t), PreparedAngle(t) and DesignatedNumberOfVMs(t) into

    data/5_prepVal_prepAngle_resultNumberVMs

