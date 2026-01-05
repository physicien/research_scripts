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
# Timing function
time_dif3 () {
echo "scale=3; (${2}-${1})/1" | bc -l | awk '{printf "%.3f", $0}'
}

time_dif1 () {
  echo "scale=3; (${2}-${1})/1" | bc -l | awk '{printf "%.1f", $0}'
}

total_run_time () {
  local sec=$(time_dif3 $1 $2)
  printf "TOTAL RUN TIME: "
  eval "echo $(date -ud "@$sec" +'$((%s/3600/24)) days %k hours %-M minutes\
      %-S seconds %3N msec')"
}

# Separator printing function
line_separator () {
  printf -- '-%.0s' {1..80}; printf "\n"
}

# Center printing function
center () {
  termwidth="80"
  padding="$(printf '%0.1s' \ {1..80})"
  printf '%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" \
      "$1" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

# Function to print the section title
section_title (){
  line_separator; center "$1"; line_separator
}

# Function to print the detailed output file
print_output_file () {
  printf '%57s:  %12s\n' "Detailed output" $1
}

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
printf '%-30s%s\n' "Slurm Job ID:" $SLURM_JOB_ID
printf '%-30s%s\n' "Slurm Ntasks:" $SLURM_NTASKS
printf '%-30s%s\n' "XYZ file:" $xyzfile
printf '%-30s%s\n' "DFT functional:" $dft_func
printf '%-30s%s\n' "Basis:" $basis
printf '%-30s%s\n' "Number of roots (TD-DFT):" $nroots
printf '%-30s%s\n' "Dielec. Const. (CPCM):" $solv_epsilon
printf '%-30s%s\n\n' "Refrac. Index (CPCM):" $solv_refrac

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

printf "\n"
print_output_file "$UV_NAME.out"

line_separator
df=$(date +"%s.%3N")
echo "Program finished with exit code $? at: $(date --date=@$df +"(%F)  %T")"
total_run_time $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
