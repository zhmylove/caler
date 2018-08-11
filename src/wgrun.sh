#!/bin/sh

WAVEGEN="./wavegen.pl"
PERIOD="./period61.pl"
PERIODS="2 3 4 5 6 8 10 12"

perl -0l12ne 'print for /#- Generates.*?sub ([^\s(]+)/gs' "$WAVEGEN" |
while read sub ;do
   for period in $PERIODS ;do
      printf " == %16s(%2d) ==> " "$sub" "$period"
      "$WAVEGEN" "$sub" "-p$period" "-s50" -r0.5 2>/dev/null |
      cut -d' ' -f2 | sed \$d |
      "$PERIOD" -nt -f 2>/dev/null |
      awk '/True period/{print $3/10}' # > FILENAME_GOES_HERE
   done
done
