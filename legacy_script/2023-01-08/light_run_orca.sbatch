#!/bin/bash

#SBATCH --job-name=c60-Ih_l
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=64                   # cpus, if across several nodes
##SBATCH --mem-per-cpu=6G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of whole nodes
#SBATCH --ntasks-per-node=64          # cpus, if whole node
#SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
xyzfile=C60-Ih.xyz
dft_func=B3LYP/G
basis=def2-SVP
max_mem=3000

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
IO_NAME=IO_$BASENAME
POL_NAME=POL_$BASENAME

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

# Ionisation energy calculation
io_calc () {
  local e1=$(etot_extract_func $1)
  local e2=$(etot_extract_func $2)
  local eio=$(echo "scale=5; $e1 - $e2" | bc -l)
  printf '%-35s%7s eV\n\n' "Ionization energy:" $eio
}

# Polarization extraction function
pol_extract_func () {
  local a=$(awk '/diagonalized tensor:/{getline;print}' $1)
  pol_bohr=($a)
}

# Polarization unit conversion
bohr_to_ang () {
  local a3_to_b3=6.748228           # Conversion factor ang^3 to bohr^3
  echo "scale=5; $1/$a3_to_b3" | bc -l
}

# Average polarizability
avg_pol () {
  echo "scale=3; ($1+$2+$3)/3" | bc -l
}

# Anisotropic polarizability
ani_pol () {
  echo "scale=3; sqrt((($1-$2)^2+($2-$3)^2+($3-$1)^2)/2)" | bc -l
}

# Polarizability calculations
pol_calc () {
  pol_extract_func $1
  local b_xx=${pol_bohr[0]}
  local b_yy=${pol_bohr[1]}
  local b_zz=${pol_bohr[2]}
  printf "Diagonalized polarizability tensor (bohr^3):\n"
  printf '  a_xx = %10s    a_yy = %10s    a_zz = %10s\n\n' $b_xx $b_yy $b_zz
  local a_xx=$(bohr_to_ang $b_xx)
  local a_yy=$(bohr_to_ang $b_yy)
  local a_zz=$(bohr_to_ang $b_zz)
  printf "Diagonalized polarizability tensor (ang^3):\n"
  printf '  a_xx = %10s    a_yy = %10s    a_zz = %10s\n\n' $a_xx $a_yy $a_zz
  local avg=$(avg_pol $a_xx $a_yy $a_zz)
  local ani=$(ani_pol $a_xx $a_yy $a_zz)
  printf '%-35s%7s\n' "Average polarizability:" $avg
  printf '%-35s%7s\n\n' "Anisotropic polarizability:" $ani
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

#Create the polarizability input file
cat << EOF > $POL_NAME.inp
! $dft_func $basis
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$POL_NAME"
%elprop
        Polar 1
end
*xyzfile 0 1 $OPT_NAME.xyz
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

diio=$(date +"%s.%3N")
section_title "IONIZATION ENERGY"
printf '%-50s... ' "Ionization energy calculation"
$EBROOTORCA/orca $IO_NAME.inp > $IO_NAME.out
dfio=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $diio $dfio)

io_calc $IO_NAME.out $OPT_NAME.out
print_output_file "$IO_NAME.out"

dipol=$(date +"%s.%3N")
section_title "POLARIZABILITY"
printf '%-50s... ' "Polarizability calculation"
$EBROOTORCA/orca $POL_NAME.inp > $POL_NAME.out
dfpol=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $dipol $dfpol)

pol_calc $POL_NAME.out
awk -v RS= -n -v OSR='\n\n' '/DIPOLE MOMENT/{print $0 "\n"}' $POL_NAME.out
print_output_file "$POL_NAME.out"

line_separator
df=$(date +"%s.%3N")
echo "Program finished with exit code $? at: $(date --date=@$df +"(%F)  %T")"
total_run_time $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
