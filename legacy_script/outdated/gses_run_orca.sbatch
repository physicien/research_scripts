#!/bin/bash

#SBATCH --job-name=c70-D5h_gses
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
nroots=200
esroots=200
iroot=1

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
GS_NAME=GS_$BASENAME
PES_NAME=PES_$BASENAME
ES_NAME=ES_$BASENAME
ESF_NAME=ESF_$BASENAME

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

#Create the ground state input file
cat << EOF > $GS_NAME.inp
! $dft_func $basis UseSym Opt TightSCF PrintGap NumFreq DefGrid3
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$GS_NAME"
*xyzfile 0 1 $SYM_NAME.xyz
EOF

#Create the pre-excited state input file
cat << EOF > $PES_NAME.inp
! $dft_func $basis TightOpt TightSCF DefGrid3
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$PES_NAME"
%geom
        MaxIter 500
end
%tddft
        TDA     True
        maxdim  10   # Davidson expansion space = MaxDim * nroots
                     # Use MaxDim 5-10 for favorable convergence
        nroots  5    # Setting the number of roots (transitions)
                     # to be calculated
        iroot   $iroot
        Followiroot True
end
*xyzfile 0 1 $GS_NAME.xyz
EOF

#Create the excited state input file
cat << EOF > $ES_NAME.inp
! $dft_func $basis TightOpt TightSCF DefGrid3
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ES_NAME"
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
! $dft_func $basis TightSCF NumFreq
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$ESF_NAME"
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
print_inp "ESroots (TD-DFT)" $esroots
print_inp "Iroot (TD-DFT)" $iroot
printf "\n"

run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
awk '/This point group/{c=2}c&&c--' $SYM_NAME.out
print_output_file "$SYM_NAME.out"

run_orca $GS_NAME "GROUND STATE" "Ground state calculation"
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
awk -v RS= -v OSR='\n\n' '/Mode   freq/' $GS_NAME.out
print_output_file "$GS_NAME.out"

run_orca $PES_NAME "PRE-EXCITED STATE" "Pre-excited state calculation"
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $PES_NAME.out | head -n 5 | \
  tail -n 2
printf "\n"
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $PES_NAME.out | tail -n 5 | \
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

print_output_file "$PES_NAME.out"

run_orca $ES_NAME "EXCITED STATE" "Excited state calculation"
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $ES_NAME.out | head -n 5 | \
  tail -n 2
printf "\n"
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $ES_NAME.out | tail -n $esroots | \
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

print_output_file "$ES_NAME.out"

run_orca $ESF_NAME "EXCITED STATE FREQUENCIES" \
  "Excited state frequencies calculation"
awk -v RS= -v OSR='\n\n' '/Mode   freq/' $ESF_NAME.out

print_output_file "$ESF_NAME.out"

line_separator
df=$(time_now)
echo "Program finished with exit code $? at: $(date --date=@$df +"(%F)  %T")"
total_run_time $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
