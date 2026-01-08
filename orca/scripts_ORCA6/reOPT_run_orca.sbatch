#!/bin/bash

#SBATCH --job-name=c96-D2_R_o
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=256G                    # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file
##SBATCH --signal=B:USR1@300           # send USR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
file=C96-D2_R
xyzdir=xyz
xyzfile=$file.xyz
mofile=$file.gbw
storage=$SLURM_TMPDIR
dft_func=B3LYP/G
disp=
basis=def2-TZVPP
ibasis=def2-SVP
max_mem=3000
grid=DefGrid3
scf=TightSCF
opt=TightOpt
dthresh=0.01
charge=0
mult=1
solvent=
usesym=true

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
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
*xyzfile $charge $mult $xyzfile
EOF

# Setup of the ORCA Sym block
usesym_setup $usesym $SYM_NAME $xyzfile
opt_xyzfile=$xyzfile

#CPCM settings 
if [ -n "$solvent" ]; then
  cpcm="CPCM($solvent)"
fi

#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $basis $disp $grid $sym $opt $scf PrintGap $cpcm
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$OPT_NAME"
$sym_block
%scf
      Guess         MORead
      MOInp         "$mofile"
end
*xyzfile $charge $mult $opt_xyzfile
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
print_inp "Initial basis set" $ibasis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Opt level" $opt
print_inp "Degeneracy threshold" $dthresh
print_inp "Charge" $charge
print_inp "Multiplicity" $mult
print_inp "Solvent" $solvent
print_inp "Use Symmetry" $usesym
printf "\n"

if $usesym; then
  run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
  print_sym_output $SYM_NAME
fi

run_orca $OPT_NAME "GEOMETRY OPTIMIZATION" "Geometry optimization"
print_opt_output $OPT_NAME $dthresh $disp

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
