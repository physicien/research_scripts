#!/bin/bash

#SBATCH --job-name=furan_vpt2
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=21          # cpus, if whole node
#SBATCH --mem=21G                     # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file
#SBATCH --signal=B:USR1@300           # send the SIGUR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
file=furan
xyzdir=xyz
t_c_dir=furan_vpt2_16760225
xyzfile=$file.xyz
dft_func=B3LYP/G
storage=$SLURM_TMPDIR
disp=
basis=def2-SVP
max_mem=750
grid=DefGrid3
scf=ExtremeSCF
opt=VeryTightOpt
dthresh=0.01
ngroup=1

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
OPT_NAME=OPT_$BASENAME
VPT2_NAME=VPT2_$BASENAME
pickettname=pickett_$VPT2_NAME.txt
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/$xyzdir
CONTINUEDIR=$LAUNCHDIR/TO_CONTINUE/$t_c_dir
WORKDIR=$storage/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR
cp $CONTINUEDIR/$OPT_NAME* $WORKDIR
cp $CONTINUEDIR/$VPT2_NAME*.hess $WORKDIR
vpt2_unfinished_delete $CONTINUEDIR $WORKDIR

cd $WORKDIR

#######################################
#Create the VPT2 input file
cat << EOF > $VPT2_NAME.inp
! $dft_func $basis $disp $grid $scf VPT2
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$VPT2_NAME"
%scf
      Guess         MORead
      MOInp         "$OPT_NAME.gbw"
end
%vpt2
    VPT2              On    # do a VPT2 analysis, same as !VPT2 (see above)
    AnharmDisp        0.05  # anharmonic displacement factor, default is 0.05
    HessianCutoff     1e-12 # cut-off for Hessian elements, default is 1e-11
    PrintLevel        4     # VPT2 print level [1, 2, 3, 4]
    MinimiseOrcaPrint False # Minimises the remaining ORCA output  
end
%method
      Z_Tol           1e-14 # Should be at least 1e-13 or smaller
end
#%output
#      Pickettname     "$pickettname"
#end
*xyzfile 0 1 $OPT_NAME.xyz
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
print_inp "Dispersion correction" $disp
print_inp "Basis set" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Opt level" $opt
print_inp "Degeneracy threshold" $dthresh
printf "\n"

run_orca $VPT2_NAME "VPT2" "VPT2 calculation"
print_frq_output $VPT2_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
