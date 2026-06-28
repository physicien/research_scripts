#!/bin/bash

#SBATCH --job-name=c60-Ih_EPC
#SBATCH --array=0-4,17-21,26,53-57,81-85,104-108,120-124,144-148,156,169-173
#SBATCH --account=rrg-cotemich-ac
#SBATCH --mail-type=END,FAIL          # Mail events (NONE,BEGIN,END,FAIL,ALL)
#SBATCH --mail-user=manubou5@hotmail.com
##SBATCH --ntasks=4                    # cpus, if across several nodes
##SBATCH --mem-per-cpu=4G              # memory, if across several nodes
#SBATCH --nodes=1                     # nb of nodes
#SBATCH --ntasks-per-node=4           # cpus, if by node
#SBATCH --mem=8G                      # memory, mem=0 for all memory of the node
##SBATCH --tmp=2000G                   # min storage
#SBATCH --time=00-12:00               # time (DD-HH:MM)
#SBATCH --output=%x_%A_%3a.log        # output .log file
##SBATCH --error=%x_%A_%3a.err         # error .err file
##SBATCH --signal=B:USR1@300           # send USR1 signal before the time limit

#######################################
# Job variable and settings:
mol=c60-Ih
frqdir=FRQ_orca
storage=$SLURM_TMPDIR
dft_func=B3LYP/G
basis=def2-tzvp
auxbasis=def2-tzvp-ri
max_mem=1750
grid=DefGrid3
scf=TightSCF
delta=1.00
mode=$SLURM_ARRAY_TASK_ID
ncond=3
usesym=false

#######################################
# Files names
frqfile=FRQ"_"$mol"_"f.out
root=$(printf %03d $mode)
fdm_file=$mol"_"$root"_"m.inp
fdp_file=$mol"_"$root"_"p.inp
fdp_wfn=$mol"_"$root"_"p.wfn
fdm_wfn=$mol"_"$root"_"m.wfn
BASENAME=$SLURM_JOB_NAME
LUANAME=$mol"_"$root
luafile=$LUANAME.lua
BASHFCT=bash_functions.sh
PYFILE=disp_single_mode.py

#######################################
# Functions
source $BASHFCT

#######################################
# Create a local working directory for the calculations
LAUNCHDIR=$PWD;
FRQDIR=$LAUNCHDIR/$frqdir
WORKDIR=$storage/$BASENAME"_"$SLURM_ARRAY_JOB_ID"_"$root
mkdir -p $WORKDIR

# Copy the input file and script to the local working directory
cp $FRQDIR/$frqfile $WORKDIR/$frqfile
cp "$(readlink -f $0)" "$WORKDIR"
cp $LAUNCHDIR/$BASHFCT $WORKDIR
cp $LAUNCHDIR/$PYFILE $WORKDIR

cd $WORKDIR

#######################################
# Setup of the ORCA Sym block
usesym_simple_setup $usesym

#######################################
# Create the beDeft input file
cat << EOF > $LUANAME.lua
-- -----------------------------------------------------------------------------
-- generate the two perturbated geometries
-- -----------------------------------------------------------------------------

-- shift coordinates by small negative amount
mol_fdm = Fragment.new("$fdm_file")

-- shift coordinates by small positive amount
mol_fdp = Fragment.new("$fdp_file")

-- -----------------------------------------------------------------------------
-- set Kohn-Sham basis set
-- -----------------------------------------------------------------------------

mol_fdm:setKohnShamSpecies("*","$basis")
mol_fdm:setAuxiliarySpecies("*","$auxbasis")
mol_fdp:setKohnShamSpecies("*","$basis")
mol_fdp:setAuxiliarySpecies("*","$auxbasis")

-- -----------------------------------------------------------------------------
-- perform dft for both systems
-- -----------------------------------------------------------------------------

-- in case of non-orthogonal WFN
setenv("ALLOW_NON_OTHOGONAL_WFN","1")

-- negative shift
mol_fdm:OrcaDysonOrbitals([[
    ! $dft_func $scf $grid $sym
    %maxcore $max_mem
    $sym_block
]])

-- positive shift
mol_fdp:OrcaDysonOrbitals([[
    ! $dft_func $scf $grid $sym
    %maxcore $max_mem
    $sym_block
]])

-- -----------------------------------------------------------------------------
-- align wave function of both systems (so far they are ranked by energy, so we
-- may have crossings). We sort them by closest projection, this is important
-- to estimate coefficient derivatives and unperturbed values.
-- -----------------------------------------------------------------------------

mol_fdm:reorderDysonOrbitals(mol_fdp)

-- -----------------------------------------------------------------------------
-- write fragments Kohn-Sham orbitals
-- -----------------------------------------------------------------------------

mol_fdp:dumpDysonOrbitals("$fdp_wfn")
mol_fdm:dumpDysonOrbitals("$fdm_wfn")

-- -----------------------------------------------------------------------------
-- get Hamiltonian (H), Overlaps (S) and Coefficient (C) matrices
-- -----------------------------------------------------------------------------

-- Hamiltonian in atomic orbital basis
Hm = mol_fdm:H()
Hp = mol_fdp:H()

-- Overlaps of the atomic orbital basis
Sm = mol_fdm:S()
Sp = mol_fdp:S()

-- WFN Coefficients in the atomic orbital basis
Cm = mol_fdm:C()
Cp = mol_fdp:C()

-- QP (Kohn-Sham here) energies in a diagonal matrix format
Em = mol_fdm:E_matrix()
Ep = mol_fdp:E_matrix()

-- estimate unperturbed (median) quantities, as well as derivatives
H = (Hm+Hp) * 0.5
S = (Sm+Sp) * 0.5
C = (Cm+Cp) * 0.5
E = (Em+Ep) * 0.5
dH = (Hp-Hm) * ( 1.0 / (2 * $delta) )
dS = (Sp-Sm) * ( 1.0 / (2 * $delta) )
dC = (Cp-Cm) * ( 1.0 / (2 * $delta) )
dE = (Ep-Em) * ( 1.0 / (2 * $delta) )

-- residuals
-- Rm = Hm * Cm - Sm * Cm * Em
-- Rp = Hp * Cp - Sp * Cp * Ep

-- derivatives of residuals
-- dR = dH * C + H * dC - dS * C * E - S * dC * E - S * C * dE

-- compute dH through derivative of H*C-S*C*E
-- dH_var = - ( H * dC - dS * C * E - S * dC * E - S * C * dE ) * C:pinv()

-- -----------------------------------------------------------------------------
-- write matrices
-- -----------------------------------------------------------------------------

H:write("H_$root.out")
S:write("S_$root.out")
C:write("C_$root.out")
E:write("E_$root.out")
dE:write("dE_$root.out")

-- -----------------------------------------------------------------------------
-- get the off-diagonal overlaps derivatives
-- -----------------------------------------------------------------------------

nocc = mol_fdp:noccupied()
ncond = nocc + $ncond
nvir = mol_fdp:nvirtual()
nstates = nocc + nvir

-- n x 1 grid
grid = MPI_Grid.new(1,__global_nprocs__)
-- context
ctxt = BlacsContext.new(grid,1,2)
-- n x n matrix
g = ScalapackMatrix.new(ctxt,$ncond,$ncond)

-- get MPI rank
local rank_str = os.getenv("OMPI_COMM_WORLD_RANK")
local my_rank = tonumber(rank_str)

-- writing function exclusive to the master process (rank 0)
local function write_master(...)
  if my_rank == 0 then
    io.write(...)
  end
end

write_master("Computing the matrix elements in g_mn,","\\\\","nu ")
write_master("(for the requested orbitals)\n")

for m=nocc+1, ncond do
  write_master(string.format("%6s%d%s%d%s\n","m = ",m,"  (of ",nstates,")"))

  psi_m = (mol_fdp:dysonOrbital( m ) + mol_fdm:dysonOrbital( m )) * 0.5
  e_m = E:get_coeff(m-1,m-1)

  for n=nocc+1, ncond do
    tic = os.clock()
    write_master(string.format("%8s%d\n","n = ",n))
    e_n = E:get_coeff(n-1,n-1)
    de_mn = dE:get_coeff(m-1,n-1)
    psi_fdp_n = mol_fdp:dysonOrbital( n )
    psi_fdm_n = mol_fdm:dysonOrbital( n )
    overlap_p = psi_m * psi_fdp_n
    overlap_m = psi_m * psi_fdm_n

    g_mn = de_mn + (e_n - e_m) * (overlap_p-overlap_m) * ( 1.0 / (2 * $delta) )

    g:set_coeff(m-1-nocc,n-1-nocc,g_mn)

    tac = os.clock()
    write_master(string.format("%11s%-9s%5s%17E\n","","de_mn","=",de_mn))
    write_master(string.format("%11s%-9s%5s%17E\n","","e_n","=",e_n))
    write_master(string.format("%11s%-9s%5s%17E\n","","e_m","=",e_m))
    write_master(string.format("%11s%-9s%5s%17E\n","","overlap_p","=",overlap_p))
    write_master(string.format("%11s%-9s%5s%17E\n","","overlap_m","=",overlap_m))
    write_master(string.format("%11s%s\n","",string.rep("-",31)))
    write_master(string.format("%11s%-9s%5s%17E\n","","g_mn","=",g_mn))
    write_master(string.format("%48s%.0f%s","done in ....",tac-tic,"s\n"))

  end
end

-- -----------------------------------------------------------------------------
-- print matrices
-- -----------------------------------------------------------------------------

-- Hamiltonian variation, explicit
-- dH:write("dH_$root.out")

-- Hamiltonian variation, computed from derivatives of C, S and E
-- dH_var:print("dH_var")

-- -----------------------------------------------------------------------------
-- write matrices
-- -----------------------------------------------------------------------------

g:write("g_$root.out")

EOF

#######################################
#               OUTPUT                #
#######################################
di=$(time_now)
print_start $di

# Python pre-processing
module load scipy-stack
source /lustre09/project/6004866/$USER/virtualenv/EPC_ENV/bin/activate

python $PYFILE $mol -m $mode -d $delta

# Start beDeft
load_beDeft

section_title "INPUT"
print_inp "Slurm job ID" $SLURM_JOB_ID
print_inp "Slurm ntasks" $SLURM_NTASKS
print_inp "Lua file" $luafile
print_inp "DFT functional" $dft_func
print_inp "Basis set" $basis
print_inp "Auxiliary basis set" $auxbasis
print_inp "Grid" $grid
print_inp "SCF level" $scf
print_inp "Use Symmetry" $usesym
print_inp "Mode" $mode
print_inp "Delta displacement" $delta
printf "\n"

run_beDeft $luafile "ELECTRON-PHONON COUPLING" "Calculation of g_nu through beDeft" 

df=$(time_now)
print_end $di $df

# Move the files back to the launching directory
mv $LAUNCHDIR/$BASENAME"_"$SLURM_ARRAY_JOB_ID"_"$root.log $WORKDIR
#mv $LAUNCHDIR/$BASENAME"_"$SLURM_ARRAY_JOB_ID"_"$root.err $WORKDIR
mv $WORKDIR $LAUNCHDIR
