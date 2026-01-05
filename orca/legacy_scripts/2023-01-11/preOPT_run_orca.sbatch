#!/bin/bash

#SBATCH --job-name=c84-D2d-23_o
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
xyzfile=C84-D2d-23.xyz
dft_func=PBE
basis=def2-SVP
max_mem=3000

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME

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
cp $XYZDIR/math_structures/$xyzfile $WORKDIR/$xyzfile
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

#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $basis UseSym Opt TightSCF PrintGap
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$OPT_NAME"
*xyzfile 0 1 $SYM_NAME.xyz
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
printf "\n"

disym=$(date +"%s.%3N")
section_title "SYMMETRIZATION"
printf '%-50s... ' "Symmetrization of the structure"
$EBROOTORCA/orca $SYM_NAME.inp > $SYM_NAME.out
dfsym=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $disym $dfsym)
awk '/This point group/{c=2}c&&c--' $SYM_NAME.out
print_output_file "$SYM_NAME.out"

diopt=$(date +"%s.%3N")
section_title "GEOMETRY OPTIMIZATION"
printf '%-50s... ' "Geometry optimization"
$EBROOTORCA/orca $OPT_NAME.inp > $OPT_NAME.out
dfopt=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $diopt $dfopt)
$EBROOTORCA/orca_2mkl $OPT_NAME -molden
mv $OPT_NAME.molden.input $OPT_NAME.molden
printf "\n"
#awk '/HOMO/ {a=$0} END{print a}' $OPT_NAME.out | awk '
#  {print $1,$4,$5,"    ",$6,$7,$8,"    ",$9,$10,$11,"\n"}'
awk -v RS= -n -v OSR='\n\n' '/NO   OCC/ {a=$0} END{print a}' $OPT_NAME.out | \
  awk '/2.0000/{x=NR+1}(NR<=x){print}' | tail -2 | \
  awk '{printf "%s\t",$4}' | awk \
  '{print "HOMO=",$1,"eV     LUMO=",$2,"eV     gap=",$2-$1,"eV\n"}'
awk '/Total Energy/{
        inside = 1
        text = ""
      }
    inside {text = text $0 RS} /DFET/ {inside = 0}
    END {printf "%s\n", text}' < $OPT_NAME.out
print_output_file "$OPT_NAME.out"

line_separator
df=$(date +"%s.%3N")
echo "Program finished with exit code $? at: $(date --date=@$df +"(%F)  %T")"
total_run_time $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
cp $OPT_NAME.xyz $XYZDIR/$xyzfile
mv $WORKDIR $LAUNCHDIR
