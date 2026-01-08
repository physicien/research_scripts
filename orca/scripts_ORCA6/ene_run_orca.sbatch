#!/bin/bash

#SBATCH --job-name=c60-Ih_E
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
#SBATCH --ntasks=64                   # cpus, if across several nodes
#SBATCH --mem-per-cpu=4G              # memory, if across several nodes
##SBATCH --nodes=1                     # nb of whole nodes
##SBATCH --ntasks-per-node=64          # cpus, if whole node
##SBATCH --mem=0                       # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file
##SBATCH --signal=B:USR1@300           # send USR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
mol=C60-Ih
xyzdir=xyz
xyzfile=$mol.xyz
mofile=$mol.gbw
storage=$SLURM_TMPDIR
dft_func=B3LYP/G
disp=
basis=def2-SVPD
ibasis=def2-SVP
max_mem=3000
grid=DefGrid3
scf=TightSCF
sthresh=1e-7    # Should be between 1e-5 and 1e-8
dthresh=0.01
usesym=true
tcne=$(echo "TCNE_$dft_func" | tr / _)
tcnefile=$tcne.out

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
GS_NAME=GS_$BASENAME
CA_NAME=CA_$BASENAME
AN_NAME=AN_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/$xyzdir/$ibasis
MODIR=$XYZDIR/MO
TCNEDIR=$LAUNCHDIR/$xyzdir/TCNE/$basis
WORKDIR=$storage/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp $MODIR/$mofile $WORKDIR/$mofile
cp $TCNEDIR/$tcnefile $WORKDIR/$tcnefile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the symetrization input file
cat << EOF > $SYM_NAME.inp
! $dft_func $ibasis NoIter XYZfile
# DFT functional:   $dft_func
# Basis:            $ibasis
%pal nprocs $(sym_nprocs $SLURM_NTASKS)
end
%base "$SYM_NAME"
%sym SymThresh 1.0e-2
end
*xyzfile 0 1 $xyzfile
EOF

# Setup of the ORCA Sym block
usesym_simple_setup $usesym

#Create the ground state/polarizability input file
cat << EOF > $GS_NAME.inp
! $dft_func $basis $disp $grid $sym $scf
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$GS_NAME"
$sym_block
%scf
      Guess         MORead
      MOInp         "$mofile"
      sthresh       $sthresh    # Should be between 1e-5 and 1e-8
end
%elprop
      Polar   True
end
*xyzfile 0 1 $xyzfile
EOF

#Create the cation state input file
cat << EOF > $CA_NAME.inp
! $dft_func $basis $disp $grid $sym $scf
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$CA_NAME"
$sym_block
%scf
      Guess         MORead
      MOInp         "$mofile"
      sthresh       $sthresh    # Should be between 1e-5 and 1e-8
end
*xyzfile 1 2 $xyzfile
EOF

#Create the anion state input file
cat << EOF > $AN_NAME.inp
! $dft_func $basis $disp $grid $sym $scf
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$AN_NAME"
$sym_block
%scf
      Guess         MORead
      MOInp         "$mofile"
      sthresh       $sthresh    # Should be between 1e-5 and 1e-8
end
*xyzfile -1 2 $xyzfile
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
print_inp "EV overlap threshold" $sthresh
print_inp "Degeneracy threshold" $dthresh
print_inp "Use Symmetry" $usesym
printf "\n"

run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
print_sym_output $SYM_NAME

run_orca $GS_NAME "GROUND STATE" "Ground state energy calculation"
print_opt_output $GS_NAME $dthresh $disp

run_orca $CA_NAME "CATION STATE" "Cation state energy calculation"
print_scf_output $CA_NAME $disp

run_orca $AN_NAME "ANION STATE" "Anion state energy calculation"
print_scf_output $AN_NAME $disp

run_title "GLOBAL INDICES"
print_glo_output $GS_NAME $CA_NAME $AN_NAME $tcne

run_title "POLARIZABILITY"
print_pol_output $GS_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
