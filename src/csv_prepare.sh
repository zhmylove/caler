#!/bin/sh
# Made by: KorG

# Just prepare CSV for interpolator2001.pl
perl -CSD -lne 's/[^\d,;]//g;s/;/ /;s/,/./g; print for /^(.*\d.*)$/' "$@"
