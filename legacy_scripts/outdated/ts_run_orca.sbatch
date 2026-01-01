#!/bin/bash

#SBATCH --job-name=c70-D5h_25_ts
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
xyzfile=C70-D5h.xyz
dft_func=B3LYP/G
basis=def2-SVP
max_mem=3000
nroots=60
esroots=25
iroot=TRIPLET
solv_epsilon=2.02     # c-hexane
solv_refrac=1.4266    # c-hexane

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
GS_NAME=GS_$BASENAME
TS_NAME=TS_$BASENAME
TSF_NAME=TSF_$BASENAME

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

# Total energy extraction function
etot_extract_func() {
  local a=$(awk '/Total Energy/ {a=$0} END{print a}' $1 | awk '{print $6}')
  echo "$a"
}

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp "$(readlink -f $0)" "$WORKDIR"

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

#Create the ground state input file
cat << EOF > $GS_NAME.inp
! $dft_func $basis UseSym Opt TightSCF PrintGap
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$GS_NAME"
*xyzfile 0 1 $SYM_NAME.xyz
EOF

#Create the triplet state input file
cat << EOF > $TS_NAME.inp
! $dft_func $basis TightOpt TightSCF
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$TS_NAME"
%geom
        MaxIter 500
end
%cpcm
        epsilon $solv_epsilon
        refrac  $solv_refrac
end
%tddft
        TDA     True
        maxdim  10   # Davidson expansion space = MaxDim * nroots
                     # Use MaxDim 5-10 for favorable convergence
        nroots  $esroots    # Setting the number of roots (transitions)
                     # to be calculated
        irootmult   $iroot
end
*xyzfile 0 1 $GS_NAME.xyz
EOF

#Create the triplet state frequencies input file
cat << EOF > $TSF_NAME.inp
! $dft_func $basis TightSCF NumFreq
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$TSF_NAME"
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
        irootmult   $iroot
end
*xyzfile 0 1 $TS_NAME.xyz
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
printf '%-30s%s\n' "ESroots (TD-DFT):" $esroots
printf '%-30s%s\n' "Iroot (TD-DFT):" $iroot
printf '%-30s%s\n' "Dielec. Const. (CPCM):" $solv_epsilon
printf '%-30s%s\n\n' "Refrac. Index (CPCM):" $solv_refrac

disym=$(date +"%s.%3N")
section_title "SYMMETRIZATION"
printf '%-50s... ' "Symmetrization of the structure"
$EBROOTORCA/orca $SYM_NAME.inp > $SYM_NAME.out
dfsym=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $disym $dfsym)
awk '/This point group/{c=2}c&&c--' $SYM_NAME.out
printf "\n"
print_output_file "$SYM_NAME.out"

digs=$(date +"%s.%3N")
section_title "GROUND STATE"
printf '%-50s... ' "Ground state calculation"
$EBROOTORCA/orca $GS_NAME.inp > $GS_NAME.out
dfgs=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $digs $dfgs)
$EBROOTORCA/orca_2mkl $GS_NAME -molden
mv $GS_NAME.molden.input $GS_NAME.molden
printf "\n"
awk -v RS= -n -v OSR='\n\n' '/NO   OCC/ {a=$0} END{print a}' $GS_NAME.out | \
  awk '/2.0000/{x=NR+1}(NR<=x){print}' | tail -2 | \
  awk '{printf "%s\t",$4}' | awk \
  '{print "HOMO=",$1,"eV     LUMO=",$2,"eV     gap=",$2-$1,"eV\n"}'
awk '/Total Energy/{
        inside = 1
        text = ""
      }
    inside {text = text $0 RS} /DFET/ {inside = 0}
    END {printf "%s\n", text}' < $GS_NAME.out

printf "\n"
print_output_file "$GS_NAME.out"

dies=$(date +"%s.%3N")
section_title "TRIPLET STATE"
printf '%-50s... ' "Triplet state calculation"
$EBROOTORCA/orca $TS_NAME.inp > $TS_NAME.out
dfes=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $dies $dfes)
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $TS_NAME.out | head -n 5 | \
  tail -n 2
printf "\n"
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $TS_NAME.out | tail -n $esroots | \
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
print_output_file "$TS_NAME.out"

diesf=$(date +"%s.%3N")
section_title "TRIPLET STATE FREQUENCIES"
printf '%-50s... ' "Triplet state frequencies calculation"
$EBROOTORCA/orca $TSF_NAME.inp > $TSF_NAME.out
dfesf=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $diesf $dfesf)
printf "\n"
awk -v RS= -v OSR='\n\n' '/Mode   freq/' $TSF_NAME.out

printf "\n"
print_output_file "$TSF_NAME.out"

line_separator
df=$(date +"%s.%3N")
echo "Program finished with exit code $? at: $(date --date=@$df +"(%F)  %T")"
total_run_time $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
