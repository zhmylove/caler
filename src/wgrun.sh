#!/bin/bash

PERIODS="1 2 3 4 5 6 8 10 12 120 121 122 140"
RANDOMS="0 0.3 0.7"
AMP_MULTIPLIERS="1 3 7"

WAVEGEN="./wavegen.pl"

export period rand mult

perl -0l12ne 'print for /#- Generates.*?sub ([^\s(]+)/gs' "$WAVEGEN" |
   while read sub ;do
      for period in $PERIODS ;do
         for rand in $RANDOMS ;do
            for mult in $AMP_MULTIPLIERS ;do
               printf " == %16s(%3d)(r:%3s)(m:%3s) ==> " \
                  "$sub" "$period" "$rand" "$mult"
               "$WAVEGEN" "$sub" "-p$((period/10)).$((period%10))" \
                  "-s1500" -r0 -a5 2>/dev/null |
                  perl -Mstrict -Mwarnings -alpe '
               $F[1] *= $ENV{mult};
               $F[1]+=rand($ENV{rand}); $F[1]-=$ENV{rand}/2; $_ = "$. $F[1]"' |
                  perl -Mcaler_fperiod -Mcaler_arr -Mstrict -le '
               my @arr = carr_interpolate(carr_read()); shift @arr;
               my $period = eval {caler_fperiod(@arr)}; print $period // 0'
            done
         done
      done
   done
