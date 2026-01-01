#!/bin/bash

#SBATCH --job-name=C16H10_esd
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=9G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=07-00:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
gsxyz=GS_C16H10_gs.xyz
gshess=GS_C16H10_gs.hess
eshess=ESF_C16H10_es.hess
dft_func=B3LYP/G
basis="def2-TZVP(-f)"
max_mem=3000
grid=DefGrid3
scf=TightSCF
nroots=20
hessflag=AH
doht=True             # consider Herzberg-Teller effect?
dodr=True             # consider Duschinsky rotations?
states=1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20
linew=50
specrange=10000,50000

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
ESD_NAME=ESD_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/ESD_effect/data_input
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$gsxyz $WORKDIR/$gsxyz
cp $XYZDIR/$gshess $WORKDIR/$gshess
cp $XYZDIR/$eshess $WORKDIR/$eshess
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the ESD input file
cat << EOF > $ESD_NAME.inp
! $dft_func $basis $grid $scf ESD(ABS)
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ESD_NAME"
%tddft
        TDA     True
        maxdim  10
        nroots  $nroots
end
%ESD
        GSHessian   "$gshess"
        ESHessian   "$eshess"
        HESSFLAG    $hessflag
        DOHT        $doht
        USEJ        $dodr
        STATES      $states
        LINEW       $linew
        SPECRANGE   $specrange
end
*xyzfile 0 1 $gsxyz
EOF

#######################################
#               OUTPUT                #
#######################################
di=$(time_now)
print_start $di

#Start ORCA
module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2
export RSH_COMMAND="/usr/bin/ssh -x"

section_title "INPUT"
print_inp "Slurm Job ID" $SLURM_JOB_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "XYZ file" $gsxyz
print_inp "GS hessian file" $gshess
print_inp "ES hessian file" $eshess
print_inp "DFT functional" $dft_func
print_inp "Basis" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Number of roots (TD-DFT)" $nroots
print_inp "ESD model" $hessflag
print_inp "Herzberg-Teller effect" $doht
print_inp "Duschinsky rotations" $dodr
print_inp "States" $states
printf "\n"

run_orca $ESD_NAME "EXCITED STATE DYNAMICS" "Vibronic coupling calculation"
print_esd_output $ESD_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
