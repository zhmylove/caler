#!/bin/bash

PERIODS="2 3 4 5 6 8 10 12"
RANDOMS="0 0.3 0.7"

WAVEGEN="./wavegen.pl"

perl -0l12ne 'print for /#- Generates.*?sub ([^\s(]+)/gs' "$WAVEGEN" |
   while read sub ;do
      for period in $PERIODS ;do
         for rand in $RANDOMS ;do
            printf " == %16s(%2d)(rand:%3s) ==> " "$sub" "$period" "$rand"
            "$WAVEGEN" "$sub" "-p$((period/10)).$((period%10))" "-s1500" -r0 \
               -a5 2>/dev/null | perl -alpe '
            $F[1]+=rand($ENV{rand}); $F[1]-=$ENV{rand}/2; $_ = "$. $F[1]"' |
               perl -Mcaler_fperiod -Mcaler_arr -Mstrict -le '
            my @arr = carr_interpolate(carr_read()); shift @arr;
            print caler_fperiod(@arr)'
         done
      done
   done
