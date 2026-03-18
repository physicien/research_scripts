#!/bin/bash

#SBATCH --job-name=c100-D5d_p
#SBATCH --array=300-305
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
#SBATCH --ntasks=1                    # cpus, if across several nodes
#SBATCH --mem-per-cpu=32G             # memory, if across several nodes
##SBATCH --nodes=1                     # nb of whole nodes
##SBATCH --ntasks-per-node=64          # cpus, if whole node
##SBATCH --mem=0                       # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%3a_%A.log        # output .log file
##SBATCH --error=%x_%3a_%A.err         # error .err file
##SBATCH --signal=B:USR1@300           # send the SIGUR1 signal before the time limit

#######################################
# Job variables and settings:
file=OPT_c100-D5d_f
fchdir=data/def2-SVP
fchfile=$file.fch
storage=$SLURM_TMPDIR
group=D5d

#######################################
# Files names
root=$(printf %03d $SLURM_ARRAY_TASK_ID)
BASENAME=$SLURM_JOB_NAME
BASHFCT=bash_functions.sh
PYFCT=elec_sym.py

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
FCHDIR=$LAUNCHDIR/$fchdir
WORKDIR=$storage/$BASENAME"_"$root"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $FCHDIR/$fchfile $WORKDIR/$fchfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR
cp $LAUNCHDIR/$PYFCT $WORKDIR

cd $WORKDIR

#######################################
# Setup of the module
module load scipy-stack
source /lustre09/project/6004866/$USER/virtualenv/SYM_ENV/bin/activate
orb=$SLURM_ARRAY_TASK_ID

#######################################
#               OUTPUT                #
#######################################
di=$(time_now)
print_start $di

#Start script
section_title "INPUT"
print_inp "Slurm Job ID" $SLURM_JOB_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "fch file" $fchfile
print_inp "Orbital" $orb
printf "\n"

python $PYFCT $fchfile -gr $group -orb0 $orb -orb1 $orb 2>&1

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$root"_"$SLURM_ARRAY_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$root"_"$SLURM_ARRAY_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
