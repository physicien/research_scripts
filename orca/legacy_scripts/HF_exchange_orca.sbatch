#!/bin/bash

#SBATCH --job-name=c96
#SBATCH --account=def-cotemich
#SBATCH --mail-type=END,FAIL            # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=256                    # cpus, if across several nodes
##SBATCH --mem-per-cpu=5G                # memory, if across several nodes
#SBATCH --nodes=2                       # nb of whole nodes
#SBATCH --ntasks-per-node=64            # cpus, if whole node
#SBATCH --mem=0                         # memory, mem=0 for all memory of the node
#SBATCH --time=00-03:00			# time (DD-HH:MM)
#SBATCH --output=%x.log 		# output .log file
##SBATCH --error=%x.err                  # error .err file

#######################################
# Job variables and settings:
xyzfile=C96-D3d.xyz
dft_func=B3LYP/G
basis=6-31G*
max_mem=3000
eex=0.50

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
OPT_NAME=OPT_$BASENAME
UV_NAME=UV_$BASENAME
NMR_NAME=NMR_$BASENAME
POL_NAME=POL_$BASENAME

#######################################
# Timing function
time_diff () {
    echo "scale=3; ($2-$1)/1" | bc -l
}

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz
WORKDIR=$LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID
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
%pal nprocs $SLURM_NTASKS
end
%base "$SYM_NAME"
%sym SymThresh 1.0e-1
end
%method
    ScalHFX = $eex
end
*xyzfile 0 1 $xyzfile
EOF

#Create the geometry optimization input file
cat << EOF > $OPT_NAME.inp
! $dft_func $basis UseSym Opt TightSCF
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$OPT_NAME"
%method
    ScalHFX = $eex
end
*xyzfile 0 1 $SYM_NAME.xyz
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
%method
    ScalHFX = $eex
end
%cpcm
        epsilon 2.568   # o-xylene
        refrac  1.5058
end
%tddft
        TDA     True
        maxdim  10   # Davidson expansion space = MaxDim * nroots
                     # Use MaxDim 5-10 for favorable convergence
        nroots  50   # Setting the number of roots (transitions) to be calculated
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
%method
    ScalHFX = $eex
end
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
%method
    ScalHFX = $eex
end
%elprop
        Polar 1
end
*xyzfile 0 1 $OPT_NAME.xyz
EOF

#######################################

#Start ORCA
module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2
export RSH_COMMAND="/usr/bin/ssh -x"

d1=$(date +%s.%N);
printf "\nStarting run at: $(date --date=@$d1)\n"
printf "Slurm Job ID: $SLURM_JOB_ID\n"
printf "DFT functional: $dft_func\n"
printf "Basis: $basis\n\n"

printf "Symmetrization of the structure..."
$EBROOTORCA/orca $SYM_NAME.inp > $SYM_NAME.out
d2=$(date +%s.%N);
printf " Done\n"
printf "The symmetrization took `time_diff $d1 $d2` sec\n\n"

printf "Geometry optimization..."
$EBROOTORCA/orca $OPT_NAME.inp > $OPT_NAME.out
d3=$(date +%s.%N);
printf " Done\n"
printf "The geometry optimization took `time_diff $d2 $d3` sec\n\n"
$EBROOTORCA/orca_2mkl $OPT_NAME -molden
mv $OPT_NAME.molden.input $OPT_NAME.molden
printf "\n"

printf "UV-vis..."
$EBROOTORCA/orca $UV_NAME.inp > $UV_NAME.out
d4=$(date +%s.%N);
printf " Done\n"
printf "The UV-vis calculation took `time_diff $d3 $d4` sec\n\n"

printf "NMR..."
#$EBROOTORCA/orca "SSCC_"$JOB.inp > "SSCC_"$JOB.out
$EBROOTORCA/orca $NMR_NAME.inp > $NMR_NAME.out
d5=$(date +%s.%N);
printf " Done\n"
printf "The NMR calculation took `time_diff $d4 $d5` sec\n\n"

printf "Polarizability..."
$EBROOTORCA/orca $POL_NAME.inp > $POL_NAME.out
d6=$(date +%s.%N);
printf " Done\n"
printf "The Polarizability calculation took `time_diff $d5 $d6` sec\n\n"

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME.err $WORKDIR

d7=$(date +%s.%N);
echo "Program finished with exit code $? at: $(date --date=@$d7)"
