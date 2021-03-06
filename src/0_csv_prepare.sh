#!/bin/sh
# Made by: KorG

# This script is a preparation tool for CSV files saved in AnyLogic.
# Usage: $0 file.csv

# IN format:
## count_log
## "x";"y"
## 0;0
## 1;5E-2
## ...

# OUT format: 
## 0 0
## 1 5E-2
## ...
perl -CSD -lne 's/[^\d,;E-]//g;s/;/ /;s/,/./g; print for /^(.*\d.*)$/' "$@"
