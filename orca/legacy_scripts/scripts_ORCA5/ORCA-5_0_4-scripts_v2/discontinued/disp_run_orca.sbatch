#!/bin/bash

#SBATCH --job-name=CNT5_5-14_C100-D5d_d
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=4                     # nb of whole nodes
#SBATCH --ntasks-per-node=16          # cpus, if whole node
#SBATCH --mem=96G                     # memory, mem=0 for all memory of the node
#SBATCH --time=01-00:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
file=CNT5_5-14_C100-D5d
xyzfile=$file.xyz
dft_func=B3LYP/G
disp=D4
basis=def2-SVP
max_mem=4500
grid=DefGrid3
scf=TightSCF
opt=TightOpt
dthresh=0.01

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
OPT_NAME=OPT_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz/catalysis
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $basis $disp $grid $opt $scf PrintGap
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$OPT_NAME"
*xyzfile 0 1 $xyzfile
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
print_inp "DFT functional" $dft_func
print_inp "Dispersion correction" $disp
print_inp "Basis" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Opt level" $opt
print_inp "Degeneracy threshold" $dthresh
printf "\n"

run_orca $OPT_NAME "GEOMETRY OPTIMIZATION" "Geometry optimization"
print_opt_output $OPT_NAME $dthresh

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
