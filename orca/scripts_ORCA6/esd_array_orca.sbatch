#!/bin/bash

#SBATCH --job-name=c60-Ih_esd
#SBATCH --array=1-20
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=256G                    # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # storage
#SBATCH --time=00-12:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%A_%3a.log 	      # output .log file
##SBATCH --error=%x_%A_%3a.err         # error .err file
##SBATCH --signal=B:USR1@300           # send USR1 signal before the time limit

#######################################
# Job variables and settings:
orca_version=6.1.1
mol=C60-Ih
spectrum=ABS
hessflag=AH
replot=false          # replot spectrum from previous calculations
xyzdir=ESD_effect
storage=$SLURM_TMPDIR
dft_func=B3LYP/G
disp=
basis=def2-SVP
max_mem=3000
grid=DefGrid3
scf=TightSCF
nroots=400
solvent=o-chlorotoluene
temp=298.15
doht=True             # consider Herzberg-Teller effect?
dodr=True             # consider Duschinsky rotations?
state=$SLURM_ARRAY_TASK_ID
lineshape=GAUSS
specres=1.0           # 10  (default)
linew=50
inlinew=250
specrange=10000,70000

#######################################
# Files names
root=$(printf %03d $state)
gsxyz=GS_$mol"_"gs.xyz
gshess=GS_$mol"_"gs.hess
if $replot; then
  eshess=$spectrum"_"$mol"_"esd.ES.hess.root$state
  eslog=$mol"_esd_*_"$root.log
else
  eshess=ESF_$mol"_"es"-"$root.hess
fi
BASENAME=$SLURM_JOB_NAME
ESD_NAME=$spectrum"_"$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/$xyzdir
GSDIR=$XYZDIR/GS
ESDIR=$XYZDIR/ES
SPECDIR=$XYZDIR/$spectrum/$hessflag
WORKDIR=$storage/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $GSDIR/$gsxyz $WORKDIR/$gsxyz
cp $GSDIR/$gshess $WORKDIR/$gshess
if $replot ; then
  cp $SPECDIR/$eshess $WORKDIR/$eshess
  cp $SPECDIR/$eslog  $WORKDIR/oldES.log
  eshess1='ESHessian'
  eshess2='"'$eshess'"'
elif [ "$hessflag" == "AH" ]; then
  cp $ESDIR/$eshess $WORKDIR/$eshess
  eshess1='ESHessian'
  eshess2='"'$eshess'"'
else
  eshess=
fi
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

if $replot ; then
  noiter=NOITER
  DELE=DELE
  dele=$(dele_extract_func oldES.log)
  TDIP=TDIP
  tdip=$(tdip_extract_func oldES.log)
fi

if [ -n "$solvent" ]; then
  cpcm="CPCM($solvent)"
fi
#######################################
#Create the ESD input file
cat << EOF > $ESD_NAME.inp
! $dft_func $basis $disp $noiter $grid $scf ESD($spectrum) $cpcm
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ESD_NAME"
%tddft
        TDA     True
        maxdim  10   # Davidson expansion space = MaxDim * nroots
                     # Use MaxDim 5-10 for favorable convergence
        nroots  $nroots     # Setting the number of roots (transitions)
                            # to be calculated
        Followiroot True
end
%ESD
        GSHessian   "$gshess"
        $eshess1   $eshess2
        HESSFLAG    $hessflag
        DOHT        $doht
        USEJ        $dodr
        STATES      $state
        TEMP        $temp
        $DELE      $dele
        $TDIP      $tdip
        LINES       $lineshape
        LINEW       $linew
        INLINEW     $inlinew
        SPECRES     $specres
        SPECRANGE   $specrange
        PRINTLEVEL  4
end
*xyzfile 0 1 $gsxyz
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
print_inp "Slurm Array ID" $SLURM_ARRAY_JOB_ID"_"$SLURM_ARRAY_TASK_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "ORCA version" $orca_version
print_inp "XYZ file" $gsxyz
print_inp "GS hessian file" $gshess
print_inp "ES hessian file" $eshess
print_inp "DFT functional" $dft_func
print_inp "Dispersion correction" $disp
print_inp "Basis set" $basis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Number of roots (TD-DFT)" $nroots
print_inp "Solvent (CPCM)" $solvent
print_inp "Temperature (K)" $temp
print_inp "Type of spectrum" $spectrum
print_inp "ESD model" $hessflag
print_inp "Herzberg-Teller effect" $doht
print_inp "Duschinsky rotations" $dodr
print_inp "State" $state
printf "\n"

run_orca $ESD_NAME "EXCITED STATE DYNAMICS" "Vibronic coupling calculation"
print_esd_output $ESD_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_ARRAY_JOB_ID"_"$root.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_ARRAY_JOB_ID"_"$root.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
