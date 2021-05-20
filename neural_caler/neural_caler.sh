#!/bin/bash
#made by: KorG

# Input sream lines consist of time, workload, optional number of vms
# While the number_of_vms present, the NN will be trained
# Later on it will give its recommendation
INPUT_STREAM="data/1_time_workload_vms"

FIFO_TRAIN="NN.fifo.train"

die(){
    echo "$*" >&2
    exit 2
}

rm -f "$FIFO_TRAIN" && mkfifo "$FIFO_TRAIN" || die "Unable to create fifo: $FIFO_TRAIN"
perl train.pl < "$FIFO_TRAIN" & 

fuser "$FIFO_TRAIN"
exec 13> "$FIFO_TRAIN"

TRAINING=true

# In a real production we have to replace this with pipe
perl prepare.pl < "$INPUT_STREAM" |
while read time p_workload p_angle vms ;do
    if test -n "$vms" ;then
        echo "$p_workload $p_angle $vms" >&13
        continue
    elif $TRAINING ;then
        echo END >&13
        exec 13>&-
        # Give train.pl some time to process END and save NN
        sleep 1
        TRAINING=false
    fi

    echo "$p_workload $p_angle"
done | perl prod.pl
