#/bin/sh -e
# Made by kk

funcs=$(
  perl -lne 's/.{4}//, y/ /_/, print if /^#-- /' ./wavegen.pl
  ) || exit 13

for f in $funcs
do
  echo $f
  # TODO: call wavegen with $f as an argument, pass period also.
done
