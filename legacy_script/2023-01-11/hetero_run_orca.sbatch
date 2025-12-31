#!/bin/bash

#SBATCH --job-name=c84-D2-22_c114-D3h
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=00-72:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
xyzfile=C84-D2-22_C114-D3h.xyz
dft_func=B3LYP/G
basis=def2-SVP
max_mem=3000
nroots=400
solv_epsilon=2.02     # c-hexane
solv_refrac=1.4266    # c-hexane

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
UV_NAME=UV_$BASENAME

#######################################
# Functions
source bash_functions.sh

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz/heterojunction/
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"

cd $WORKDIR

#######################################
#Create the UV-vis input file
cat << EOF > $UV_NAME.inp
! $dft_func $basis TightSCF #UseSym
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$UV_NAME"
%cpcm
        epsilon $solv_epsilon
        refrac  $solv_refrac
end
%tddft
        TDA     True
        maxdim  10   # Davidson expansion space = MaxDim * nroots
                     # Use MaxDim 5-10 for favorable convergence
        nroots  $nroots  # Setting the number of roots (transitions)
                     # to be calculated
end
*xyzfile 0 1 $xyzfile
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
print_inp "XYZ file" $xyzfile
print_inp "DFT functional" $dft_func
print_inp "Basis" $basis
print_inp "Number of roots (TD-DFT)" $nroots
print_inp "Dielec. Const. (CPCM)" $solv_epsilon
print_inp "Refrac. Index (CPCM)" $solv_refrac
printf "\n"

diuv=$(date +"%s.%3N")
section_title "UV-VIS"
printf '%-50s... ' "TD-DFT calculation"
$EBROOTORCA/orca $UV_NAME.inp > $UV_NAME.out
dfuv=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $diuv $dfuv)
$EBROOTORCA/orca_2mkl $UV_NAME -molden
mv $UV_NAME.molden.input $UV_NAME.molden
printf "\n"
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $UV_NAME.out | head -n 5 | \
  tail -n 2
printf "\n"
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $UV_NAME.out | tail -n $nroots | \
  awk ' function abs(x) {return x < 0.0 ? -x : x}
  {
    if ($5 >= 0.0001){
        if(abs($7) > abs($6) && abs($7) > abs($8)){
            print $0, " s";
        }
        else {
            print $0, " d";
        }
    }
  }'

print_output_file "$UV_NAME.out"

line_separator
df=$(date +"%s.%3N")
echo "Program finished with exit code $? at: $(date --date=@$df +"(%F)  %T")"
total_run_time $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
