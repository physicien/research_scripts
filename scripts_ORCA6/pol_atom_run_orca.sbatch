#!/bin/bash

#SBATCH --job-name=c96-D2_R_p
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=32          # cpus, if whole node
#SBATCH --mem=512G                    # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-12:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file
##SBATCH --signal=B:USR1@300           # send the SIGUR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
file=C96-D2_R
xyzdir=xyz
xyzfile=$file.xyz
mofile=$file.gbw
storage=$SLURM_TMPDIR
dft_func=CAM-B3LYP
basis=def2-TZVPPD
ibasis=def2-TZVPP
max_mem=12000
grid=DefGrid3
scf=TightSCF
charge=0
mult=1
sthresh=1e-7    # Should be between 1e-5 and 1e-8
usesym=false
freq_i=0.00

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
POL_NAME=POL_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/$xyzdir/$ibasis
MODIR=$XYZDIR/MO
WORKDIR=$storage/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp $MODIR/$mofile $WORKDIR/$mofile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
# Setup of the ORCA Sym block
usesym_simple_setup $usesym

#Create the polarizability input file
cat << EOF > $POL_NAME.inp
! $dft_func $basis $grid $sym $scf
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$POL_NAME"
$sym_block
%scf
      Guess         MORead
      MOInp         "$mofile"
      sthresh       $sthresh    # Should be between 1e-5 and 1e-8
end
%elprop
      Dipole      True
      DipoleAtom  True
      Polar       True
      PolarAtom   True
      freq_i      $freq_i
end
*xyzfile $charge $mult $xyzfile
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
print_inp "XYZ file" $xyzfile
print_inp "DFT functional" $dft_func
print_inp "Basis set" $basis
print_inp "Initial basis set" $ibasis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "EV overlap threshold" $sthresh
print_inp "Imaginary frequency" $freq_i
print_inp "Charge" $charge
print_inp "Multiplicity" $mult
print_inp "Use Symmetry" $usesym
printf "\n"

run_orca $POL_NAME "POLARIZABILITY" "Polarizability calculation"
print_pol_output $POL_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
