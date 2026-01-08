#!/bin/bash

#SBATCH --job-name=BDPA_LR_d
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=4           # cpus, if whole node
#SBATCH --mem=16G                     # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file
##SBATCH --signal=B:USR1@300           # send USR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
filehost=BDPA_L
fileguest=BDPA_R
xyzdir=xyz
xyzfilehost=$filehost.xyz
xyzfileguest=$fileguest.xyz
storage=$SLURM_TMPDIR
dft_func=XTB
basis=
max_mem=3000
grid=DefGrid3
scf=
fixhost=false
guestcharge=0
guestmult=2
nguest=1
charge=0
mult=2

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
DIM_NAME=DIM_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/$xyzdir
WORKDIR=$storage/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfilehost $WORKDIR/$xyzfilehost
cp $XYZDIR/$xyzfileguest $WORKDIR/$xyzfileguest
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################

#Create the DOCKER input file
cat << EOF > $DIM_NAME.inp
! $dft_func $basis $grid $sym $scf
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$DIM_NAME"
%DOCKER
      GUEST         "$xyzfileguest"
      DOCKLEVEL     normal
      NREPEATGUEST  $nguest
      FIXHOST       $fixhost
      GUESTCHARGE   $guestcharge
      GUESTMULT     $guestmult
      NOPT          32
end
*xyzfile $charge $mult $xyzfilehost
EOF

#######################################
#               OUTPUT                #
#######################################
di=$(time_now)
print_start $di

#Start ORCA
load_orca $orca_version

section_title "INPUT"
print_inp "Slurm Job ID" $SLURM_JOB_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "ORCA version" $orca_version
print_inp "Host XYZ file" $xyzfilehost
print_inp "Guest XYZ file" $xyzfileguest
print_inp "DFT functional" $dft_func
print_inp "Basis set" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "EV overlap threshold" $sthresh
print_inp "Fix host coordinates" $fixhost
print_inp "Number of guest" $nguest
print_inp "Guest charge" $guestcharge
print_inp "Guest multiplicity" $guestmult
print_inp "Charge" $charge
print_inp "Multiplicity" $mult
printf "\n"

run_orca $DIM_NAME "DIMERIZATION" "DOCKER calculation"
print_opt_output $DIM_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
