#!/bin/bash

#SBATCH --job-name=c100-D5d_a
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
#SBATCH --ntasks=64                   # cpus, if across several nodes
#SBATCH --mem-per-cpu=4G              # memory, if across several nodes
##SBATCH --nodes=1                     # nb of whole nodes
##SBATCH --ntasks-per-node=64          # cpus, if whole node
##SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=00-12:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
file=C100-D5d
xyzfile=$file.xyz
dft_func=B3LYP/G
basis=def2-SVP
max_mem=3000
grid=DefGrid3
scf=TightSCF
opt=TightOpt
nroots=400
nto=True
solv_epsilon=4.450    # o-xylene 2.568  # 2-chlorotoluene 4.450
solv_refrac=1.5268    # o-xylene 1.5058 # 2-chlorotoluene 1.5268

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
ABS_NAME=ABS_$BASENAME
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
! $dft_func $basis NoIter XYZfile
# DFT functional:   $dft_func
# Basis:            $inibasis
%pal nprocs 16
end
%base "$SYM_NAME"
%sym SymThresh 1.0e-1
end
*xyzfile 0 1 $xyzfile
EOF

#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $basis $grid UseSym $opt $scf PrintGap
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

#Create the absorption input file
cat << EOF > $ABS_NAME.inp
! $dft_func $basis $grid $scf 
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ABS_NAME"
%scf
      Guess         MORead
      MOInp         "$OPT_NAME.gbw"
      MaxIter       1000
      AutoTRAHIter  20
end
%cpcm
      epsilon $solv_epsilon
      refrac  $solv_refrac
end
%tddft
      TDA     True
      maxdim  10    # Davidson expansion space = MaxDim * nroots
                    # Use MaxDim 5-10 for favorable convergence
      nroots  $nroots # Setting the number of roots (transitions)
                      # to be calculated
      DoNTO   $nto
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
print_inp "Basis" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Opt level" $opt
print_inp "Number of roots (TD-DFT)" $nroots
print_inp "Dielec. Const. (CPCM)" $solv_epsilon
print_inp "Refrac. Index (CPCM)" $solv_refrac
print_inp "Do NTO" $nto
printf "\n"

run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
print_sym_output $SYM_NAME

run_orca $OPT_NAME "GEOMETRY OPTIMIZATION" "Geometry optimization"
print_opt_output $OPT_NAME

run_orca $ABS_NAME "ABSORPTION SPECTRUM" "TD-DFT calculation"
print_uv_output $ABS_NAME $nroots

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
