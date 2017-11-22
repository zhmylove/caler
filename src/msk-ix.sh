#!/bin/sh

period=$1
case $period in
   monthly|yearly|weekly)
      :
   ;;
   *)
      echo "$0 <monthly|yearly|weekly>" >&2
      exit 2
   ;;
esac

URL="https://www.msk-ix.ru/data/json/traffic/ix.all/$period/"


curl -s "$URL" |tr -d '[]' |perl -F'[][,.]' -alne '
next unless $F[3];
$p = $F[1] unless defined $p;
print((($F[1] - $p) / 100000) . " $F[2]")'
