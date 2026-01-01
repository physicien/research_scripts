#!/bin/bash

#SBATCH --job-name=c60-Ih_es
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file
##SBATCH --signal=B:USR1@300           # send the SIGUR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
file=C60-Ih
xyzdir=xyz
xyzfile=$file.xyz
storage=$SLURM_TMPDIR
dft_func=B3LYP/G
disp=
basis=def2-SVP
max_mem=3000
grid=DefGrid3
fgrid=DefGrid2
scf=TightSCF
opt=TightOpt
dthresh=0.01
usesym=true
nproots=5
nroots=25
esroots=25
iroot=1

#######################################
# Files names
root=$(printf %03d $iroot)
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
GS_NAME=GS_$BASENAME
PES_NAME=PES_$BASENAME$root
ES_NAME=ES_$BASENAME$root
ESF_NAME=ESF_$BASENAME$root
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

#Create the ground state input file
cat << EOF > $GS_NAME.inp
! $dft_func $basis $disp $grid $sym $opt $scf PrintGap
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$GS_NAME"
*xyzfile 0 1 $opt_xyzfile
EOF

#Create the pre-excited state input file
cat << EOF > $PES_NAME.inp
! $dft_func $basis $disp $grid $sym $opt $scf
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$PES_NAME"
%scf
      Guess         MORead
      MOInp         "$GS_NAME.gbw"
end
%Sym
        CleanUpGradient False
end
%geom
        MaxIter 500
end
%tddft
        TDA     True
        maxdim  10    # Davidson expansion space = MaxDim * nroots
                      # Use MaxDim 5-10 for favorable convergence
        nroots  $nproots  # Setting the number of roots (transitions)
                          # to be calculated
        iroot   $iroot
        Followiroot True
end
*xyzfile 0 1 $GS_NAME.xyz
EOF

#Create the excited state input file
cat << EOF > $ES_NAME.inp
! $dft_func $basis $disp $grid $sym $opt $scf
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ES_NAME"
%scf
      Guess         MORead
      MOInp         "$PES_NAME.gbw"
end
%Sym
        CleanUpGradient False
end
%geom
        MaxIter 500
end
%tddft
        TDA     True
        maxdim  10   # Davidson expansion space = MaxDim * nroots
                     # Use MaxDim 5-10 for favorable convergence
        nroots  $esroots    # Setting the number of roots (transitions)
                            # to be calculated
        iroot   $iroot
        Followiroot True
end
*xyzfile 0 1 $PES_NAME.xyz
EOF

#Create the excited state frequencies input file
cat << EOF > $ESF_NAME.inp
! $dft_func $basis $disp $fgrid $sym $scf NumFreq
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ESF_NAME"
%scf
      Guess         MORead
      MOInp         "$ES_NAME.gbw"
end
%tddft
        TDA     True
        maxdim  10   # Davidson expansion space = MaxDim * nroots
                     # Use MaxDim 5-10 for favorable convergence
        nroots  $nroots  # Setting the number of roots (transitions)
                     # to be calculated
        iroot   $iroot
end
*xyzfile 0 1 $ES_NAME.xyz
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
print_inp "Frequency grid" $fgrid
print_inp "SCF level" $scf
print_inp "Opt level" $opt
print_inp "Degeneracy threshold" $dthresh
print_inp "Number of roots PES (TD-DFT)" $nproots
print_inp "Number of roots ES (TD-DFT)" $nroots
print_inp "ESroots (TD-DFT)" $esroots
print_inp "Iroot (TD-DFT)" $iroot
printf "\n"

if $usesym; then
  run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
  print_sym_output $SYM_NAME
fi

run_orca $GS_NAME "GROUND STATE" "Ground state calculation"
print_opt_output $GS_NAME $dthresh $disp

run_orca $PES_NAME "PRE-EXCITED STATE" "Pre-excited state calculation"
print_uv_output $PES_NAME 5

run_orca $ES_NAME "EXCITED STATE" "Excited state calculation"
print_uv_output $ES_NAME $esroots

run_orca $ESF_NAME "EXCITED STATE FREQUENCIES" \
  "Excited state frequencies calculation"
print_frq_output $ESF_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
