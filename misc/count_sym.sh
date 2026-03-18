#!/bin/bash
# Count occurences of D symmetry in a database.

dbfile=$1
group=("D2 " "D2h" "D2d" "D3 " "D3h" "D3d" "D5 " "D5h" "D5d" "D6 " "D6h" "D6d")

for gr in "${group[@]}"
do
  printf "${gr}: "
#  grep "${gr}" $dbfile | tee /dev/tty | wc -l
  grep "${gr}" $dbfile | wc -l
done
