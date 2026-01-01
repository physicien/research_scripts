#!/bin/bash

#SBATCH --job-name=c70-D5h_esd
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=9G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=07-00:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
gsxyz=GS_c70-D5h_fc.xyz
gshess=GS_c70-D5h_fc.hess
eshess=ESF_c70-D5h_fc.hess
dft_func=B3LYP/G
basis=def2-SVP
max_mem=3000
nroots=60
solv_epsilon=2.02     # c-hexane
solv_refrac=1.4266    # c-hexane
doht=True           # consider Herzberg-Teller effect?
dodr=True           # consider Duschinsky rotations?
states=40
linew=75
specrange=10000,50000

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
ESD_NAME=ESD_$BASENAME

#######################################
# Functions
source bash_functions.sh

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/ESD_effect/data_input
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$gsxyz $WORKDIR/$gsxyz
cp $XYZDIR/$gshess $WORKDIR/$gshess
cp $XYZDIR/$eshess $WORKDIR/$eshess
cp "$(readlink -f $0)" "$WORKDIR"

cd $WORKDIR

#######################################
#Create the ESD input file
cat << EOF > $ESD_NAME.inp
! $dft_func $basis TightSCF ESD(ABS)
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ESD_NAME"
%tddft
        TDA     True
        maxdim  10
        nroots  $nroots
end
%ESD
        GSHessian   "$gshess"
        ESHessian   "$eshess"
        DOHT        $doht
        USEJ        $dodr
        STATES      $states
        LINEW       $linew
        SPECRANGE   $specrange
end
*xyzfile 0 1 $gsxyz
EOF

#######################################
#               OUTPUT                #
#######################################
di=$(date +"%s.%3N")
printf "Starting run at: $(date --date=@$di +"(%F)  %T")\n\n"

#Start ORCA
module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2
export RSH_COMMAND="/usr/bin/ssh -x"

section_title "INPUT"
print_inp "Slurm Job ID" $SLURM_JOB_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "XYZ file" $gsxyz
print_inp "GS hessian file" $gshess
print_inp "ES hessian file" $eshess
print_inp "DFT functional" $dft_func
print_inp "Basis" $basis
print_inp "Number of roots (TD-DFT)" $nroots
print_inp "Dielec. Const. (CPCM)" $solv_epsilon
print_inp "Refrac. Index (CPCM)" $solv_refrac
print_inp "Herzberg-Teller effect" $doht
print_inp "Duschinsky rotations" $dodr
print_inp "States" $states
printf "\n"

diesd=$(date +"%s.%3N");
section_title "EXCITED STATE DYNAMICS"
printf '%-50s... ' "HT/FC effect calculation"
$EBROOTORCA/orca $ESD_NAME.inp > $ESD_NAME.out
dfesd=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $diesd $dfesd)
printf "\n"
awk '/The sum of K*K/' $ESD_NAME.out
awk -v RS= -v OSR='\n\n' '/Homogeneous linewidth is:/' $ESD_NAME.out
awk '/The absorption spectrum/' $ESD_NAME.out
print_output_file "$ESD_NAME.out"

line_separator
df=$(date +"%s.%3N")
echo "Program finished with exit code $? at: $(date --date=@$df +"(%F)  %T")"
total_run_time $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
