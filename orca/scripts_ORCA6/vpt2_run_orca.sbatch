#!/bin/bash

#SBATCH --job-name=c60-Ih_vpt2
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=87          # cpus, if whole node
#SBATCH --mem=435G                    # memory, mem=0 for all memory of the node
#SBATCH --tmp=2000G                   # storage
#SBATCH --time=07-00:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file
#SBATCH --signal=B:USR1@300           # send USR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
file=C60-Ih
xyzdir=xyz
xyzfile=$file.xyz
dft_func=PBE
storage=$SLURM_TMPDIR
disp=
basis=def2-SVP
max_mem=3750
grid=DefGrid3
scf=ExtremeSCF
opt=VeryTightOpt
dthresh=0.01
usesym=false
ngroup=1

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
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
WORKDIR=$storage/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the symetrization input file
cat << EOF > $SYM_NAME.inp
! $dft_func $basis NoIter XYZfile
# DFT functional:   $dft_func
# Basis:            $basis
%pal nprocs $(sym_nprocs $SLURM_NTASKS)
end
%base "$SYM_NAME"
%sym SymThresh 1.0e-2
end
*xyzfile 0 1 $xyzfile
EOF

# Setup of the ORCA Sym block
usesym_setup $usesym $SYM_NAME $xyzfile

#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $basis $disp $grid $sym $opt $scf PrintGap
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal  nprocs        $SLURM_NTASKS
      nprocs_group  $ngroup
end
%base "$OPT_NAME"
$sym_block
*xyzfile 0 1 $opt_xyzfile
EOF

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
print_inp "Use Symmetry" $usesym
printf "\n"

if $usesym; then
  run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
  print_sym_output $SYM_NAME
fi

run_orca $OPT_NAME "GEOMETRY OPTIMIZATION" "Geometry optimization"
print_opt_output $OPT_NAME $dthresh $disp

run_orca $VPT2_NAME "VPT2" "VPT2 calculation"
print_frq_output $VPT2_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
