#!/bin/bash
#SBATCH --job-name=c60
#SBATCH --account=def-cotemich
#SBATCH --mail-type=END,FAIL            # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=your_email@mail.com
##SBATCH --ntasks=32                     # cpus, if across several nodes
##SBATCH --mem-per-cpu=2G                # memory, if across several nodes
#SBATCH --nodes=2                       # nb of whole nodes
#SBATCH --ntasks-per-node=64            # cpus, if whole node
#SBATCH --mem=0                         # memory, mem=0 for all memory of the node
#SBATCH --time=00-12:00			# time (DD-HH:MM)
#SBATCH --output=%x.log 		# output .log file
##SBATCH --error=%x.err                  # error .err file
#######################################
# Job variables and settings:
xyzfile=C60-Ih.xyz
dft_func=B3LYP/G
basis=6-31G*
#######################################
JOB=$SLURM_JOB_NAME

#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
WORKDIR=$LAUNCHDIR/$SLURM_JOB_NAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file to the local working directory
$cp $LAUNCHDIR/$SLURM_JOB_NAME.inp $WORKDIR/$SLURM_JOB_NAME.inp
cp $LAUNCHDIR/$xyzfile $WORKDIR/$xyzfile

#Change the number procs
sed -i "/nprocs/ s/[0-9]\+/$SLURM_NTASKS/" $WORKDIR/$SLURM_JOB_NAME.inp

cd $WORKDIR

#######################################

#Create the symetrization input file
cat << EOF > SYM_$SLURM_JOB_NAME.inp
! $dft_func $basis NoIter XYZfile
# DFT functional:   $dft_func
# Basis:            $basis
%pal nprocs $SLURM_NTASKS
end
%base "SYM_$SLURM_JOB_NAME"
%sym SymThresh 1.0e-1
end
*xyzfile 0 1 $xyzfile
EOF

#Create the geometry optimization input file
cat << EOF > OPT_$SLURM_JOB_NAME.inp
! $dft_func $basis UseSym Opt TightSCF
# DFT functional:   $dft_func
# Basis:            $basis
%pal nprocs $SLURM_NTASKS
end
%base "OPT_$SLURM_JOB_NAME"
*xyzfile 0 1 SYM_$SLURM_JOB_NAME.xyz
EOF

#Create the UV-vis input file
cat << EOF > UV-vis_$SLURM_JOB_NAME.inp
! $dft_func $basis TightSCF #UseSym
# DFT functional:   $dft_func
# Basis:            $basis
%pal nprocs $SLURM_NTASKS
end
%base "UV-vis_$SLURM_JOB_NAME"
%cpcm   epsilon 2.568   # o-xylene
        refrac  1.5058
end
%tddft
        maxdim 5    # Davidson expansion space = MaxDim * nroots
                    # Use MaxDim 5-10 for favorable convergence
        nroots 50   # Setting the number of roots (transitions) to be calculated
end
*xyzfile 0 1 OPT_$SLURM_JOB_NAME.xyz
EOF

#Create the NMR chemical shielding input file
cat << EOF > NMR_$SLURM_JOB_NAME.inp
! $dft_func $basis TightSCF NMR
# DFT functionnal:  $dft_func
# Basis:            $basis
* xyzfile 0 1 OPT_$SLURM_JOB_NAME.xyz
%eprnmr
        nuclei = All C {shift}
end
EOF

#Create the Raman input file
cat << EOF > RAM_$SLURM_JOB_NAME.inp
! $dft_func $basis NumFreq
# DFT functional:   $dft_func
# Basis:            $basis
%pal nprocs $SLURM_NTASKS
end
%base "RAM_$SLURM_JOB_NAME"
%elprop
        Polar 1
end
*xyzfile 0 1 OPT_$SLURM_JOB_NAME.xyz
EOF

#######################################

#Start ORCA
module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2
export RSH_COMMAND="/usr/bin/ssh -x"
#export OMPI_MCA_mtl='^mxm'
#export OMPI_MCA_pml='^yalla'

d1=$(date +%s.%N);
printf "\nJob execution start at: $(date --date=@$d1)\n"
printf "Slurm Job ID is: $SLURM_JOB_ID\n\n"

printf "Symmetrization of the structure..."
$EBROOTORCA/orca "SYM_"$SLURM_JOB_NAME.inp > "SYM_"$SLURM_JOB_NAME.out
d2=$(date +%s.%N);
printf " Done\n"
sym_time=$(echo "scale=3; ($d2-$d1)/1" | bc -l);
printf "The symmetrization took $sym_time sec\n\n"

printf "Geometry optimization..."
$EBROOTORCA/orca "OPT_"$SLURM_JOB_NAME.inp > "OPT_"$SLURM_JOB_NAME.out
d3=$(date +%s.%N);
printf " Done\n"
opt_time=$(echo "scale=3; ($d3-$d2)/1" | bc -l);
printf "The geometry optimization took $opt_time sec\n\n"

#printf "UV-vis..."
#$EBROOTORCA/orca "UV-vis_"$SLURM_JOB_NAME.inp > "UV-vis_"$SLURM_JOB_NAME.out
d4=$(date +%s.%N);
#printf " Done\n"
#uvvis_time=$(echo "scale=3; ($d4-$d3)/1" | bc -l);
#printf "The UV-vis calculation took $uvvis_time sec\n\n"

#printf "NMR..."
#$EBROOTORCA/orca "NMR_"$SLURM_JOB_NAME.inp > "NMR_"$SLURM_JOB_NAME.out
d5=$(date +%s.%N);
#printf " Done\n"
#nmr_time=$(echo "scale=3; ($d5-$d4)/1" | bc -l);
#printf "The NMR calculation took $nmr_time sec\n\n"

printf "Raman..."
$EBROOTORCA/orca "RAM_"$SLURM_JOB_NAME.inp > "RAM_"$SLURM_JOB_NAME.out
d6=$(date +%s.%N);
printf " Done\n"
raman_time=$(echo "scale3; ($d6-$d5)/1" | bc -l);
printf "The Raman calculation took $raman_time sec\n\n"

#Move the files to the local working directory 
mv $LAUNCHDIR/$SLURM_JOB_NAME.log $WORKDIR
#mv $LAUNCHDIR/$SLURM_JOB_NAME.err $WORKDIR

d7=$(date +%s.%N);
echo "Job finished at: $(date --date=@$d7)"

exit 0
