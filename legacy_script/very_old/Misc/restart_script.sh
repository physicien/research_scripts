#!/bin/bash

#SBATCH --job-name=c96
#SBATCH --account=def-cotemich
#SBATCH --mail-type=END,FAIL            # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=32                     # cpus, if across several nodes
##SBATCH --mem-per-cpu=2G                # memory, if across several nodes
#SBATCH --nodes=1                       # nb of whole nodes
#SBATCH --ntasks-per-node=64            # cpus, if whole node
#SBATCH --mem=0                         # memory, mem=0 for all memory of the node
#SBATCH --time=00-03:00			# time (DD-HH:MM)
#SBATCH --output=%x.log 		# output .log file
##SBATCH --error=%x.err                  # error .err file

#######################################
# Job variables and settings:
xyzfile=C96-D3d.xyz
dft_func=B3LYP/G
basis=def2-TZVP
max_mem=2500

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
UV_NAME=UV_$BASENAME
NMR_NAME=NMR_$BASENAME
POL_NAME=POL_$BASENAME

#######################################
# Timing function
time_diff () {
    echo "scale=3; ($2-$1)/1" | bc -l
}

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;

#Copy the input file and the script to the local working directory
#######################################

#Start ORCA
module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2
export RSH_COMMAND="/usr/bin/ssh -x"

d1=$(date +%s.%N);
printf "\nStarting run at: $(date --date=@$d1)\n"
printf "Slurm Job ID: $SLURM_JOB_ID\n"
printf "DFT functional: $dft_func\n"
printf "Basis: $basis\n\n"

printf "Polarizability..."
$EBROOTORCA/orca $POL_NAME.inp > $POL_NAME.out
d4=$(date +%s.%N);
printf " Done\n"
printf "The polarizability calculation took `time_diff $d1 $d4` sec\n\n"

d7=$(date +%s.%N);
echo "Program finished with exit code $? at: $(date --date=@$d7)"
