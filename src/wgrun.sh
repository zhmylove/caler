#/bin/sh -e
# Made by korg

WAVEGEN="wavegen.pl"
PERIODS="2 3 4 5 6 8 10 12"

perl -0l12ne 'print for /#- Generates.*?sub ([^\s(]+)/gs' "$WAVEGEN" |
while read sub ;do
   for PERIOD in $PERIODS ;do
      "$WAVEGEN" "-p$PERIOD" # > FILENAME_GOES_HERE
   done
done
