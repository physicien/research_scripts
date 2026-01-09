#!/bin/bash

#SBATCH --account=rrg-cotemich-ac
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=1G
#SBATCH --time=00-03:00

module load openbabel-omp
export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"

obabel c100_crystal_mod_test.xyz -O c100_crystal_mod_test.pdb 
