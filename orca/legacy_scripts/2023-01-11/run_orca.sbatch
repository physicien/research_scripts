#!/bin/bash

#SBATCH --job-name=c60-Ih
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
xyzfile=C60-Ih.xyz
dft_func=B3LYP/G
basis=def2-SVP
max_mem=3000
nroots=400
solv_epsilon=2.02     # c-hexane
solv_refrac=1.4266    # c-hexane

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
IO_NAME=IO_$BASENAME
UV_NAME=UV_$BASENAME
NMR_NAME=NMR_$BASENAME
POL_NAME=POL_$BASENAME

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
*xyzfile 0 1 $OPT_NAME.xyz
EOF

##Create the Spin-Spin coupling constants (Raman)
#cat << EOF > SSCC_$JOB.inp
#! $dft_func $basis TightScf
## DFT functional:   $dft_func
## Basis:            $basis
#%maxcore $max_mem
#%pal nprocs $SLURM_NTASKS
#end
#%base "SSCC_$JOB"
#*xyzfile 0 1 $OPT_NAME.xyz
#%eprnmr
#        nuclei = all C {ssall,ist=13}
#        SpinSpinRThresh 6.0             # radius for the sscc (Angstrom)
#end
#EOF

#Create the NMR chemical shielding input file
cat << EOF > $NMR_NAME.inp
! $dft_func $basis TightSCF NMR
# DFT functionnal:  $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$NMR_NAME"
%cpcm
        epsilon 2.641   # CS2
        refrac  1.6276
end
* xyzfile 0 1 $OPT_NAME.xyz
%eprnmr
    nuclei = all C {shift}
end
EOF
#    NMRREF[6] 190.202               # shielding for 13C reference [ppm]

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
print_inp "Slurm Job ID" $SLURM_JOB_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "XYZ file" $xyzfile
print_inp "DFT functional" $dft_func
print_inp "Basis" $basis
print_inp "Number of roots (TD-DFT)" $nroots
print_inp "Dielec. Const. (CPCM)" $solv_epsilon
print_inp "Refrac. Index (CPCM)" $solv_refrac
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

diio=$(date +"%s.%3N")
section_title "IONIZATION ENERGY"
printf '%-50s... ' "Ionization energy calculation"
$EBROOTORCA/orca $IO_NAME.inp > $IO_NAME.out
dfio=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $diio $dfio)

io_calc $IO_NAME.out $OPT_NAME.out
print_output_file "$IO_NAME.out"

diuv=$(date +"%s.%3N")
section_title "UV-VIS"
printf '%-50s... ' "TD-DFT calculation"
$EBROOTORCA/orca $UV_NAME.inp > $UV_NAME.out
dfuv=$(date +"%s.%3N")
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $diuv $dfuv)
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

dinmr=$(date +"%s.%3N");
section_title "NMR"
printf '%-50s... ' "NMR chemical shift of 13C"
#$EBROOTORCA/orca "SSCC_"$JOB.inp > "SSCC_"$JOB.out
$EBROOTORCA/orca $NMR_NAME.inp > $NMR_NAME.out
dfnmr=$(date +"%s.%3N");
printf "done"
printf " (%7s sec)\n\n" $(time_dif1 $dinmr $dfnmr)
awk -v RS= -v OSR='\n\n' '/CHEMICAL SHIELDING/' $NMR_NAME.out
awk -v RS= -v OSR='\n\n' '/Nucleus  Element/' $NMR_NAME.out
print_output_file "$NMR_NAME.out"

dipol=$(date +"%s.%3N");
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
