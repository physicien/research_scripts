#!/bin/bash

module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2

$EBROOTORCA/orca_mapspc c60.out RAMAN -x0200 -x11700 -w1.0
