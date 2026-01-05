#!/bin/bash

#SBATCH --job-name=c150-D5h_l
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
#SBATCH --ntasks=64                   # cpus, if across several nodes
#SBATCH --mem-per-cpu=7G              # memory, if across several nodes
##SBATCH --nodes=1                     # nb of whole nodes
##SBATCH --ntasks-per-node=64          # cpus, if whole node
##SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=00-24:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
xyzfile=C150-D5h.xyz
dft_func=B3LYP/G
basis="def2-TZVP(-f)"
max_mem=5000

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
IO_NAME=IO_$BASENAME

#######################################
# Functions
source bash_functions.sh

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/bash_functions.sh $WORKDIR

cd $WORKDIR

#######################################
#Create the symetrization input file
cat << EOF > $SYM_NAME.inp
! $dft_func $basis NoIter XYZfile
# DFT functional:   $dft_func
# Basis:            $basis
%pal nprocs 16
end
%base "$SYM_NAME"
%sym SymThresh 1.0e-1
end
*xyzfile 0 1 $xyzfile
EOF

#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $basis UseSym Opt TightSCF PrintGap
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$OPT_NAME"
%elprop
        Polar 1
end
*xyzfile 0 1 $SYM_NAME.xyz
EOF

#Create the ionization energy input file
cat << EOF > $IO_NAME.inp
! $dft_func $basis TightSCF
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$IO_NAME"
*xyzfile 1 2 $OPT_NAME.xyz
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
print_inp "XYZ file" $xyzfile
print_inp "DFT functional" $dft_func
print_inp "Basis" $basis
printf "\n"

run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
print_sym_output $SYM_NAME

run_orca $OPT_NAME "GEOMETRY OPTIMIZATION" "Geometry optimization"
print_lgt_output $OPT_NAME

run_orca $IO_NAME "IONIZATION ENERGY" "Ionization energy calculation"
print_io_output $IO_NAME $OPT_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
