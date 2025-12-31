#!/bin/bash

#SBATCH --job-name=CNT5_5-14_C100-D5d_O2-s4_x
#SBATCH --account=def-cotemich
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=10                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=1G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=20          # cpus, if whole node
#SBATCH --mem=20G                     # memory, mem=0 for all memory of the node
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
file=CNT5_5-14_C100-D5d_O2-s4
xyzfile=$file.xyz
method=XTB2
max_mem=750
charge=0
mult=1
solvent=Water

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
XTB_NAME=XTB_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz/catalysis/sites/ORR
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the XTB input file
cat << EOF > $XTB_NAME.inp
! $method NUMFREQ ALPB($solvent)
# Semiempirical method:   $method
# Basis:                  $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$XTB_NAME"
%xtb
      XTBINPUTSTRING  "--bhess"
end
*xyzfile $charge $mult $xyzfile
EOF

#######################################
#               OUTPUT                #
#######################################
di=$(time_now)
print_start $di

#Start ORCA
load_orca

section_title "INPUT"
print_inp "Slurm Job ID" $SLURM_JOB_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "XYZ file" $xyzfile
print_inp "Semiempirical method" $method
print_inp "Charge" $charge
print_inp "Multiplicity" $mult
print_inp "Solvent" $solvent
printf "\n"

run_orca $XTB_NAME "XTB CALCULATION" "Thermostatistical corrections"
print_xtb_output $XTB_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
