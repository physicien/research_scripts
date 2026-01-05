#!/bin/bash

FILE=$1

module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2

$EBROOTORCA/orca_mapspc $FILE Abs -x07500 -x134000 -w500 -n5000
#$EBROOTORCA/orca_mapspc $FILE Abs -eV -x00 -x110 -w0.01
