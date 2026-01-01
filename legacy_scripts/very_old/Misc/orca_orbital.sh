#!/bin/bash

FILE=$1
filename="${FILE%%.*}"

module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2

$EBROOTORCA/orca_2mkl $filename -molden
mv $filename.molden.input $filename.molden
#$EBROOTORCA/orca_plot $FILE -i
