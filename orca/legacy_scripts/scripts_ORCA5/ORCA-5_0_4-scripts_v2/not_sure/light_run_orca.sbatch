#!/bin/bash

#SBATCH --job-name=c60-Ih_l
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
file=C60-Ih
xyzfile=$file.xyz
dft_func=B3LYP/G
inibasis=def2-SVP
basis=def2-SVPD
max_mem=3000
grid=DefGrid3
scf=TightSCF
opt=TightOpt
dthresh=0.01

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
IE_NAME=IE_$BASENAME
POL_NAME=POL_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the symetrization input file
cat << EOF > $SYM_NAME.inp
! $dft_func $inibasis NoIter XYZfile
# DFT functional:   $dft_func
# Basis:            $inibasis
%pal nprocs $(sym_nprocs $SLURM_NTASKS)
end
%base "$SYM_NAME"
%sym SymThresh 1.0e-1
end
*xyzfile 0 1 $xyzfile
EOF

#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $inibasis $grid UseSym $opt $scf PrintGap
# DFT functional:   $dft_func
# Basis:            $inibasis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$OPT_NAME"
%scf
      MaxIter       1000
      AutoTRAHIter  20
end
*xyzfile 0 1 $SYM_NAME.xyz
EOF

#Create the ionization energy input file
cat << EOF > $IE_NAME.inp
! $dft_func $inibasis $grid $scf 
# DFT functional:   $dft_func
# Basis:            $inibasis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$IE_NAME"
%scf
      Guess         MORead
      MOInp         "$OPT_NAME.gbw"
      MaxIter       1000
      AutoTRAHIter  20
end
*xyzfile 1 2 $OPT_NAME.xyz
EOF

#Create the polarizability input file
cat << EOF > $POL_NAME.inp
! $dft_func $basis $grid $scf 
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$POL_NAME"
%scf
      Guess         MORead
      MOInp         "$OPT_NAME.gbw"
      sthresh       1e-6
      MaxIter       1000
      AutoTRAHIter  20
end
%elprop
        Polar 1
end
*xyzfile 0 1 $OPT_NAME.xyz
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
print_inp "Initial basis" $inibasis
print_inp "Basis" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Opt level" $opt
print_inp "Degeneracy threshold" $dthresh
printf "\n"

run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
print_sym_output $SYM_NAME

run_orca $OPT_NAME "GEOMETRY OPTIMIZATION" "Geometry optimization"
print_opt_output $OPT_NAME $dthresh

run_orca $IE_NAME "IONIZATION ENERGY" "Ionization energy calculation"
print_ie_output $OPT_NAME $IE_NAME

run_orca $POL_NAME "POLARIZABILITY" "Polarizability calculation"
print_pol_output $POL_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
