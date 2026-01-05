#!/bin/bash

FILE=$1
filename="${FILE%%.*}"
TMPF=$filename.tmp

module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2
module load gnuplot/5.2.8

$EBROOTORCA/orca_vib $FILE > $filename'.vib'
