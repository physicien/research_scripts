#!/bin/bash

#Change the number of procs
sed -i "/nprocs/ s/[0-9]\+/$SLURM_NTASKS/" $WORKDIR/$JOB.inp

BASENAME=`ls *.inp | awk -F '.' '{print $1}`

for file in *.txt; do bash peaks_splitting.sh $file; done
