#!/bin/bash

filename="${1##*/}"
filepref="${filename%%.*}"

sbatch --job-name=$filepref --export=All,FILE=$1 run_orca.sbatch
