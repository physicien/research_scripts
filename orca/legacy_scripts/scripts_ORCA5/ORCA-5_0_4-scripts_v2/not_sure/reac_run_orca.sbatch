#!/bin/bash

#SBATCH --job-name=c70-D5h_r
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=your_email@mail.com
#SBATCH --ntasks=64                   # cpus, if across several nodes
#SBATCH --mem-per-cpu=4G              # memory, if across several nodes
##SBATCH --nodes=1                     # nb of whole nodes
##SBATCH --ntasks-per-node=64          # cpus, if whole node
##SBATCH --mem=0                       # memory, mem=0 for all memory of the node
#SBATCH --time=00-03:00		      # time (DD-HH:MM)
#SBATCH --output=%x_%j.log 	      # output .log file
##SBATCH --error=%x_%j.err             # error .err file

#######################################
# Job variables and settings:
mol=C70-D5h
xyzfile=$mol.xyz
mofile=$mol.gbw
dft_func=B3LYP/G
disp=
basis=def2-SVP
ibasis=def2-SVP
max_mem=3000
grid=DefGrid3
scf=TightSCF
dthresh=0.01

#######################################
# Files names
BASENAME=$SLURM_JOB_NAME
SYM_NAME=SYM_$BASENAME
GS_NAME=GS_$BASENAME
CA_NAME=CA_$BASENAME
AN_NAME=AN_$BASENAME
BASHFCT=bash_functions.sh

#######################################
# Functions
source $BASHFCT

#######################################
#Create a local working directory for the ORCA calculation
LAUNCHDIR=$PWD;
XYZDIR=$LAUNCHDIR/xyz/$ibasis
MODIR=$XYZDIR/MO
WORKDIR=$SCRATCH/$BASENAME"_"$SLURM_JOB_ID
mkdir -p $WORKDIR

#Copy the input file and the script to the local working directory
cp $XYZDIR/$xyzfile $WORKDIR/$xyzfile
cp $MODIR/$mofile $WORKDIR/$mofile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR

cd $WORKDIR

#######################################
#Create the symetrization input file
cat << EOF > $SYM_NAME.inp
! $dft_func $ibasis NoIter XYZfile
# DFT functional:   $dft_func
# Basis:            $ibasis
%pal nprocs $(sym_nprocs $SLURM_NTASKS)
end
%base "$SYM_NAME"
%sym SymThresh 1.0e-1
end
*xyzfile 0 1 $xyzfile
EOF

#Create the ground state input file
cat << EOF > $GS_NAME.inp
! $dft_func $basis $disp $grid $scf AIM
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$GS_NAME"
%scf
      Guess         MORead
      MOInp         "$mofile"
      sthresh       1.0e-8    # Should be between 1e-5 and 1e-8
end
*xyzfile 0 1 $xyzfile
EOF

#Create the cation state input file
write_ca_input() {
  local homo=$(homo_extract_func $GS_NAME.out)
  local q=$(degeneracy $GS_NAME.out $homo $dthresh)
  local m=$(multiplicity $q)
  cat << EOF > $CA_NAME.inp
! $dft_func $basis $disp $grid $scf AIM
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$CA_NAME"
%scf
      Guess         MORead
      MOInp         "$mofile"
      sthresh       1.0e-8    # Should be between 1e-5 and 1e-8
end
*xyzfile $q $m $xyzfile
EOF
}

#Create the anion state input file
write_an_input() {
  local lumo=$(lumo_extract_func $GS_NAME.out)
  local p=$(degeneracy $GS_NAME.out $lumo $dthresh)
  local c=$(awk -v x=$p 'BEGIN{printf "%d",-1*x}')
  local m=$(multiplicity $p)
  cat << EOF > $AN_NAME.inp
! $dft_func $basis $disp $grid $scf AIM
# DFT functional:   $dft_func
# Basis:            $basis
%maxcore $max_mem
%pal nprocs $SLURM_NTASKS
end
%base "$AN_NAME"
%scf
      Guess         MORead
      MOInp         "$mofile"
      sthresh       1.0e-8    # Should be between 1e-5 and 1e-8
end
*xyzfile $c $m $xyzfile
EOF
}

#######################################
#               OUTPUT                #
#######################################
di=$(time_now)
print_start $di

#Start ORCA
load_orca

section_title "INPUT"
print_inp "Slurm Job ID" $SLURM_JOB_ID
print_inp "Slurm Ntasks" $SLURM_NTASKS
print_inp "XYZ file" $xyzfile
print_inp "DFT functional" $dft_func
print_inp "Dispersion correction" $disp
print_inp "Basis set" $basis
print_inp "Initial basis set" $ibasis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Degeneracy threshold" $dthresh
printf "\n"

run_orca $SYM_NAME "SYMMETRIZATION" "Symmetrization of the structure"
print_sym_output $SYM_NAME

run_orca $GS_NAME "GROUND STATE" "Ground state energy calculation"
print_opt_output $GS_NAME $dthresh

write_ca_input
write_an_input

run_orca $CA_NAME "CATIONIC STATE" "Cationic state energy calculation"
print_scf_output $CA_NAME

run_orca $AN_NAME "ANIONIC STATE" "Anionic state energy calculation"
print_scf_output $AN_NAME

df=$(time_now)
print_end $di $df

#Move the files to the local working directory 
mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_JOB_ID.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
