#!/bin/bash

#SBATCH --job-name=CNT5_5-14_C70-D5h_d
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
#SBATCH --ntasks=100                  # cpus, if across several nodes
#SBATCH --mem-per-cpu=18G             # memory, if across several nodes
##SBATCH --nodes=8                     # nb of whole nodes
##SBATCH --ntasks-per-node=8           # cpus, if whole node
##SBATCH --mem=80G                     # memory, mem=0 for all memory of the node
#SBATCH --time=03-00:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
file=CNT5_5-14_C70-D5h
xyzfile=$file.xyz
mofile=$file.gbw
cntfile=$file"_cnt".xyz
fulfile=$file"_ful".xyz
dft_func=B3LYP/G
disp=D4
basis=def2-TZVPP
max_mem=13000
grid=DefGrid3
scf=TightSCF
dthresh=0.01
solvent=Water

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
HET_NAME=HET_$BASENAME
CNT_NAME=CNT_$BASENAME
FUL_NAME=FUL_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz/catalysis/edd
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp $XYZDIR/MO/$mofile $WORKDIR/$mofile
cp $XYZDIR/$cntfile $WORKDIR/$cntfile
cp $XYZDIR/$fulfile $WORKDIR/$fulfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the heterostructure input file
cat << EOF > $HET_NAME.inp
! $dft_func $basis $disp $grid $scf AIM CPCM($solvent)
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$HET_NAME"
%scf
      Guess         MORead
      MOInp         "$mofile"
end
*xyzfile 0 1 $xyzfile
EOF

#Create the cnt input file
cat << EOF > $CNT_NAME.inp
! $dft_func $basis $disp $grid $scf AIM CPCM($solvent)
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$CNT_NAME"
*xyzfile 0 1 $cntfile
EOF

#Create the fullerene input file
cat << EOF > $FUL_NAME.inp
! $dft_func $basis $disp $grid $scf AIM CPCM($solvent)
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$FUL_NAME"
*xyzfile 0 1 $fulfile
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
print_inp "Degeneracy threshold" $dthresh
print_inp "Solvent" $solvent
printf "\n"

run_orca $HET_NAME "HETEROSTRUCTURE" "SCF calculation"
print_opt_output $HET_NAME $dthresh

run_orca $CNT_NAME "CNT" "SCF calculation"
print_opt_output $CNT_NAME $dthresh

run_orca $FUL_NAME "FULLERENE" "SCF calculation"
print_opt_output $FUL_NAME $dthresh

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
