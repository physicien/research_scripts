#!/bin/bash

#SBATCH --job-name=c100-D5d_esd
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=07-00:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err            # error .err file

#######################################
# Job variables and settings:
mol=c100-D5d
spectrum=FLUOR
gsxyz=GS_$mol"_"gs.xyz
gshess=GS_$mol"_"gs.hess
eshess=ESF_$mol"_"es.hess
dft_func=B3LYP/G
basis=def2-SVP
max_mem=3000
grid=DefGrid2
scf=TightSCF
nroots=25
solv_epsilon=2.02     # c-hexane
solv_refrac=1.4266    # c-hexane
temp=298.15
hessflag=AH
doht=True             # consider Herzberg-Teller effect?
dodr=True             # consider Duschinsky rotations?
iroot=1
lineshape=GAUSS
specres=1.0           # 10  (default)
linew=50
inlinew=50
specrange=10000,70000

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
ESD_NAME=$spectrum"_"$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/ESD_effect/$spectrum/data_input
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$gsxyz $WORKDIR/$gsxyz
cp $XYZDIR/$gshess $WORKDIR/$gshess
cp $XYZDIR/$eshess $WORKDIR/$eshess
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the ESD input file
cat << EOF > $ESD_NAME.inp
! $dft_func $basis $grid $scf ESD($spectrum)
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ESD_NAME"
%cpcm
        epsilon $solv_epsilon
        refrac  $solv_refrac
end
%tddft
        TDA     True
        maxdim  10
        nroots  $nroots
        iroot   $iroot
end
%ESD
        GSHessian   "$gshess"
        ESHessian   "$eshess"
        HESSFLAG    $hessflag
        DOHT        $doht
        USEJ        $dodr
        TEMP        $temp
        LINES       $lineshape
        LINEW       $linew
        INLINEW     $inlinew
        SPECRES     $specres
        SPECRANGE   $specrange
end
*xyzfile 0 1 $gsxyz
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
print_inp "XYZ file" $gsxyz
print_inp "GS hessian file" $gshess
print_inp "ES hessian file" $eshess
print_inp "DFT functional" $dft_func
print_inp "Basis" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Number of roots (TD-DFT)" $nroots
print_inp "Dielec. Const. (CPCM)" $solv_epsilon
print_inp "Refrac. Index (CPCM)" $solv_refrac
print_inp "Temperature (K)" $temp
print_inp "Type of spectrum" $spectrum
print_inp "ESD model" $hessflag
print_inp "Herzberg-Teller effect" $doht
print_inp "Duschinsky rotations" $dodr
print_inp "Iroot" $iroot
printf "\n"

run_orca $ESD_NAME "EXCITED STATE DYNAMICS" "Vibronic coupling calculation"
print_esd_output $ESD_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_ARRAY_JOB_ID"_"$TASK_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
