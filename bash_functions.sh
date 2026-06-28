#!/bin/bash

###################
# Timing function #
###################

_time_dif() {
  awk "BEGIN{printf \"%.$1f\", ($3-$2)/1}"
}

time_dif3() {
  _time_dif 3 "$1" "$2"
}

time_dif1() {
  _time_dif 1 "$1" "$2"
}

total_run_time() {
  awk -v t1="$1" -v t2="$2" '
    BEGIN {
      s = t2 - t1
      d = int(s / 86400)
      h = int((s - d*86400) / 3600)
      m = int((s - d*86400 - h*3600) / 60)
      sec = s - d*86400 - h*3600 - m*60
      ms = int((sec - int(sec)) * 1000 + 0.5)
      printf "TOTAL RUN TIME: %d days %d hours %d minutes %d seconds %d msec\n", d, h, m, int(sec), ms
    }'
}

time_now() {
  date +"%s.%3N"
}

###################
# Handle function #
###################

vpt2_unfinished_lister(){
  local dir="$1"
  ls "$dir" | gawk 'match($0, /(D[0-9]+).+tmp/, a) {print a[1]}' \
    | awk '!visited[$0]++'
}

vpt2_unfinished_verify(){
  local dir="$1"
  vpt2_unfinished_lister "$dir" | xargs -I {} find "$dir" -name '*{}*'
}

vpt2_unfinished_delete(){
  local dir="$1"
  vpt2_unfinished_lister "$dir" | xargs -I {} find "$dir" -name '*{}*' -delete
}

# Function executed before the end of the time limit
sig_handler_USR1() {
  echo "CANCEL"
  echo "   function sig_handler_USR1 called"
  echo "   Signal trapped -  `date`"
  printf "   Saving data ..."

  if [[ -z "$BASENAME" || -z "$SLURM_JOB_ID" || -z "$WORKDIR" || -z "$LAUNCHDIR" ]]; then
    echo "   Error: required variables not set (BASENAME, SLURM_JOB_ID, WORKDIR, LAUNCHDIR)" >&2
    exit 2
  fi

  local jobname="${BASENAME}_${SLURM_JOB_ID}"
  vpt2_unfinished_verify "$WORKDIR" > "$WORKDIR/TO_VERIFY"
  rm -f "$WORKDIR"/*.tmp*
  mkdir -p "$LAUNCHDIR/$jobname"
  mv "$WORKDIR"/* "$LAUNCHDIR/$jobname" 2>"$LAUNCHDIR/$jobname/BROKEN_FILES"
  printf " done\n"
  local dfi
  dfi=$(time_now)
  print_end "$di" "$dfi"
  mv "$LAUNCHDIR/$jobname.log" "$LAUNCHDIR/$jobname/"
  exit 2
}

#############################
# Input formating functions #
#############################

# Number of processors ORCA symetrization
sym_nprocs() {
  if (($1 < 16)); then
    echo "$1"
  else
    echo 16
  fi
}

# Setup of the ORCA Symmetry block
usesym_setup() {
  local use_sym=$1
  local sym_name=$2
  local xyz_file=$3
  if $use_sym; then
    opt_xyzfile=$sym_name.xyz
    sym=UseSym
    read -r -d '' sym_block <<- EOM
%sym
      SymRelaxOpt   False
      CleanUpGrad   True
end
EOM
  else
    opt_xyzfile=$xyz_file
    sym=""
    sym_block=""
  fi
}

usesym_simple_setup() {
  local use_sym=$1
  if $use_sym; then
    sym=UseSym
    read -r -d '' sym_block <<- EOM
%sym
      SymRelaxOpt   False
      CleanUpGrad   True
end
EOM
  else
    sym=""
    sym_block=""
  fi
}

# Frequency grid for polarizabily array
freq_grid() {
  local -i root=$1
  if ((root == 0)); then
    awk "BEGIN{printf \"%.2f\", $root}"
  else
    awk "BEGIN{printf \"%.2f\", 0.01*2^($root-1)}"
  fi
}

##############################
# Output formating functions #
##############################

# Separator printing function
line_separator() {
  printf -- '-%.0s' {1..80}; printf "\n"
}

# Center printing function
center() {
  local text="$1"
  local termwidth=80
  local pad=$(((termwidth - ${#text}) / 2))
  printf "%*s%s\n" "$pad" "" "$text"
}

# Function to print the section title
section_title() {
  line_separator; center "$1"; line_separator
}

# Function to print the starting time
print_start() {
  printf "Starting run at: $(date --date=@"$1" +"(%F)  %T")\n"
}

# Function to print the ending time
print_end() {
  local rc=$?
  local ti=$1
  local tf=$2
  line_separator
  echo "Program finished with exit code $rc at: $(date --date=@$tf +"(%F)  %T")"
  total_run_time "$ti" "$tf"
}

# Function to print the input parameters
print_inp() {
  printf '%-28s%-1s %s\n' "$1" ":" "$2"
}

# Function to print the detailed output file
print_output_file() {
  printf '\n%57s:  %12s\n' "Detailed output" "$1"
}

#####################
# Running functions #
#####################

# beDeft module load
load_beDeft() {
  local ml="StdEnv/2023 gcc/12.3 openmpi/4.1.5"
  module load $ml 2>/dev/null
  module load scalapack/2.2.0 2>/dev/null
  module load orca/6.1.1 2>/dev/null
  export RSH_COMMAND="/usr/bin/ssh -x"
  export ROOTBEDEFT="/lustre09/project/6004866/bourrete/software/beDeft_package/beDeft/build/src"
  export ORCA_PATH=$EBROOTORCA
  export PATH="$ORCA_PATH:$PATH"
  set > ORCA_CLEAN_ENV
}

# beDeft running function + timing + output formating
run_beDeft() {
  local file="$1"
  local title="$2"
  local description="$3"

  if [[ -z "$file" || -z "$title" || -z "$description" ]]; then
    echo "Error: run_beDeft requires 3 arguments: file title description" >&2
    return 1
  fi

  local ti tf
  trap 'sig_handler_USR1' USR1
  ti=$(time_now)
  section_title "$title"
  printf '%-50s... ' "$description"
  mpirun -n "$SLURM_NTASKS" "$ROOTBEDEFT/beDeft" "$file" > log_beDeft
  wait
  tf=$(time_now)
  printf "done (%7s sec)\n\n" "$(time_dif1 "$ti" "$tf")"
}

# ORCA module load
load_orca() {
  local version="$1"
  if [[ -z "$version" ]]; then
    echo "Error: load_orca requires a version argument (e.g., '6.1.1')" >&2
    return 1
  fi
  local ml=$(module -t spi orca/$version 2>/dev/null | tail -n 1)
  if [[ -z "$ml" ]]; then
    echo "Warning: no module found for orca/$version" >&2
  fi
  module load $ml 2>/dev/null || echo "Warning: failed to load $ml" >&2
  module load "orca/$version" 2>/dev/null || echo "Warning: failed to load orca/$version" >&2
  export RSH_COMMAND="/usr/bin/ssh -x"
}

# ORCA running function + timing + output formating
run_orca() {
  local name="$1"
  local title="$2"
  local description="$3"

  if [[ -z "$name" || -z "$title" || -z "$description" ]]; then
    echo "Error: run_orca requires 3 arguments: name title description" >&2
    return 1
  fi
  if [[ -z "$EBROOTORCA" ]]; then
    echo "Error: EBROOTORCA is not set — has load_orca been called?" >&2
    return 1
  fi

  local ti tf
  trap 'sig_handler_USR1' USR1
  ti=$(time_now)
  section_title "$title"
  printf '%-50s... ' "$description"
  $EBROOTORCA/orca "$name".inp >& "$name".out &
  wait
  tf=$(time_now)
  printf "done (%7s sec)\n\n" "$(time_dif1 "$ti" "$tf")"
}

# ORCA orbital generation from OPT module
molden_orca() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Error: molden_orca requires a filename argument" >&2
    return 1
  fi
  if [[ -z "$EBROOTORCA" ]]; then
    echo "Error: EBROOTORCA is not set — has load_orca been called?" >&2
    return 1
  fi
  "$EBROOTORCA/orca_2mkl" "$name" -molden
  mv "$name".molden.input "$name".molden
  printf "\n"
}

# Generic section title output formating
run_title() {
  local title="$1"
  section_title "$title"
}

###################################
# ORCA output formating functions #
###################################

# Print SYM output
print_sym_output() {
  local sym_name=$1
  awk '/Auto-detected point group/{c=2}c&&c--' "$sym_name.out"
  print_output_file "$sym_name.out"
}

# Print OPT output
print_opt_output() {
  local opt_name=$1
  local dthresh=$2
  local disp=$3
  molden_orca "$opt_name"
  print_HLgap "$opt_name.out"
  print_degeneracy "$opt_name.out" "$dthresh"
  print_energies "$opt_name.out"
  print_disp "$opt_name.out" "$disp"
  print_output_file "$opt_name.out"
}

# Print IE output
print_ie_output() {
  local opt_name=$1
  local ie_name=$2
  ie_calc "$ie_name.out" "$opt_name.out"
  print_output_file "$ie_name.out"
}

# Print EA output
print_ea_output() {
  local opt_name=$1
  local ea_name=$2
  ea_calc "$opt_name.out" "$ea_name.out"
  print_output_file "$ea_name.out"
}

# Print EC output
print_ec_output() {
  local opt_name=$1
  local ie_name=$2
  local ea_name=$3
  ec_calc "$opt_name.out" "$ie_name.out" "$ea_name.out"
  print_output_file "$ie_name.out"
}

# Print UV output
print_uv_output() {
  local uv_name=$1
  local nroots=$2
  awk -v RS= -v ORS='\n\n'\
      '/ABSORPTION SPECTRUM VIA TRANSITION ELECTRIC DIPOLE MOMENTS/'\
      "$uv_name.out"\
    | head -n 5\
    | tail -n 2
  printf "\n"
  awk -v RS= -v ORS='\n\n'\
      '/ABSORPTION SPECTRUM VIA TRANSITION ELECTRIC DIPOLE MOMENTS/'\
      "$uv_name.out" \
    | tail -n "$nroots"
  print_output_file "$uv_name.out"
}

# Print POL output
print_pol_output() {
  local pol_name=$1
  pol_calc "$pol_name.out"
  awk -v RS= -v ORS='\n\n' '/DIPOLE MOMENT/{print $0}' "$pol_name.out"
  awk -v RS= -v ORS='\n\n' '/Electronic contribution:/{print $0}' \
      "$pol_name.out" | tail -n -8
  print_output_file "$pol_name.out"
}

# Print FRQ output
print_frq_output() {
  local frq_name=$1
  awk -v RS= -v ORS='\n\n' '/Mode   freq/' "$frq_name.out"
  print_output_file "$frq_name.out"
}

# Print RAM output
print_ram_output() {
  local ram_name=$1
  awk -v RS= -v ORS='\n\n' '/Activity/' "$ram_name.out"
  print_output_file "$ram_name.out"
}

# Print NMR output
print_nmr_output() {
  local nmr_name=$1
  awk -v RS= -v ORS='\n\n' '/CHEMICAL SHIELDING/' "$nmr_name.out"
  awk -v RS= -v ORS='\n\n' '/Nucleus  Element/' "$nmr_name.out"
  print_output_file "$nmr_name.out"
}

# Print GS output
print_gs_output() {
  local gs_name=$1
  local dthresh=$2
  local disp=$3
  molden_orca "$gs_name"
  print_HLgap "$gs_name.out"
  print_degeneracy "$gs_name.out" "$dthresh"
  print_energies "$gs_name.out"
  print_disp "$gs_name.out" "$disp"
  printf "\n"
  awk -v RS= -v ORS='\n\n' '/Mode   freq/' "$gs_name.out"
  print_output_file "$gs_name.out"
}

# Print ESD output
print_esd_output() {
  local esd_name=$1
  awk '/The sum of K*K/' "$esd_name.out"
  awk -v RS= -v ORS='\n\n' '/Homogeneous linewidth is:/' "$esd_name.out"
  awk '/The absorption spectrum/' "$esd_name.out"
  print_output_file "$esd_name.out"
}

print_scf_output() {
  local scf_name=$1
  local disp=$2
  molden_orca "$scf_name"
  print_energies "$scf_name.out"
  print_disp "$scf_name.out" "$disp"
  print_output_file "$scf_name.out"
}

print_xtb_output() {
  local xtb_name=$1
  grep 'G-E(el)' < "$xtb_name.out"
  print_output_file "$xtb_name.out"
}

# Print global indices output
print_glo_output() {
  local gs_name=$1
  local ie_name=$2
  local ea_name=$3
  local tcne_name=$4
  print_HLgap "$gs_name.out"
  glo_calc "$gs_name.out" "$ie_name.out" "$ea_name.out" "$tcne_name.out"
}

#############################
# Post-processing functions #
#############################

# Print final total energy
etot_print() {
  awk '/Total Energy  / {a=$0} END{print a}' "$1"
}

# Total energy extraction function
etot_extract_func() {
  awk '/Total Energy  / {a=$0} END{print a}' "$1" | awk '{print $6}'
}

# Extract the ORBITAL ENERGIES section from an ORCA output file
_orbital_section() {
  awk -v RS= -v ORS='\n\n' '/NO   OCC/ {a=$0} END{print a}' "$1"
}

# HOMO extraction function
homo_extract_func() {
  local a=$(_orbital_section "$1" \
    | awk '$2 ~ /2.0000/{print}' \
    | tail -1 \
    | awk '{printf "%s\t",$4}'
  )
  echo "$a"
}

# LUMO extraction function
lumo_extract_func() {
  local a=$(_orbital_section "$1" \
    | awk '$2 ~ /2.0000/{x=NR+1}(NR<=x){print}' \
    | tail -1 \
    | awk '{printf "%s\t",$4}'
  )
  echo "$a"
}

# HL gap function
gap_func() {
  awk "BEGIN{printf \"%.4f\", $2 - $1}"
}

print_HLgap() {
  local name=$1
  local homo=$(homo_extract_func "$name")
  local lumo=$(lumo_extract_func "$name")
  local gap=$(gap_func "$homo" "$lumo")
  printf "HOMO= %s eV     LUMO= %s eV     gap= %s eV\n\n" "$homo" "$lumo" "$gap"
}

degeneracy() {
  local name="$1"
  local energy=$2
  local threshold=$3
  _orbital_section "$name" \
    | awk -v x=$energy '{printf "%s\n",sqrt(($4-x)^2)}' \
    | awk -v y=$threshold '$1<=y' \
    | wc -l
}

multiplicity() {
  awk -v x=$1 'BEGIN{printf "%d",x+1}'
}

# Print degeneracy level
print_degeneracy(){
  local name=$1
  local thresh=$2
  local homo=$(homo_extract_func "$name")
  local q=$(degeneracy "$name" "$homo" "$thresh")
  local lumo=$(lumo_extract_func "$name")
  local p=$(degeneracy "$name" "$lumo" "$thresh")
  printf '%-35s%2s\n' "Degree of degeneracy in HOMO:" "$q"
  printf '%-35s%2s\n\n' "Degree of degeneracy in LUMO:" "$p"
}

# Print energies
print_energies(){
  local name=$1
  awk '/Total Energy       :/{inside=1;text=""} inside \
    {text=text $0 RS} /SCF CONVERGENCE/ {inside=0} \
    END {printf "%s",text}' < "$name" | head -n -3
}

print_disp(){
  local name=$1
  local disp=$2
  printf '\n'
  awk '/Dispersion correction/ {a=$0} END{print a}' "$name"
  awk '/FINAL SINGLE POINT ENERGY/ {a=$0} END{print a}' "$name"
}

# Vertical ionization energy
ie_calc() {
  local e1=$(etot_extract_func "$1")
  local e2=$(etot_extract_func "$2")
  local eio=$(awk "BEGIN{printf \"%.5f\", $e1 - $e2}")
  printf '%-35s%7s eV\n' "Ionization energy:" "$eio"
}

# Vertical electron affinity
ea_calc() {
  local e1=$(etot_extract_func "$1")
  local e2=$(etot_extract_func "$2")
  local eaf=$(awk "BEGIN{printf \"%.5f\", $e1 - $e2}")
  printf '%-35s%7s eV\n' "Electron affinity:" "$eaf"
}

# Electrochemical band gap
ec_calc() {
  local e1=$(etot_extract_func "$1")
  local e2=$(etot_extract_func "$2")
  local e3=$(etot_extract_func "$3")
  local ecf=$(awk "BEGIN{printf \"%.5f\", $e2 + $e3 - 2*$e1}")
  printf '%-35s%7s eV\n' "Electrochemical band gap:" "$ecf"
}

# Global indices
glo_calc() {
  local gs=$(etot_extract_func "$1")
  local ca=$(etot_extract_func "$2")
  local an=$(etot_extract_func "$3")
  local homo=$(homo_extract_func "$1")
  local tcne=$(homo_extract_func "$4")
  local ie=$(awk -v x=$ca -v y=$gs 'BEGIN{printf "%.4f\n", x-y}')
  local ea=$(awk -v x=$gs -v y=$an 'BEGIN{printf "%.4f\n", x-y}')
  local chi=$(awk -v x=$ie -v y=$ea 'BEGIN{printf "%.4f\n", (x+y)/2}')
  local mu=$(awk -v x=$chi 'BEGIN{printf "%.4f\n", -1*x}')
  local hard=$(awk -v x=$ie -v y=$ea 'BEGIN{printf "%.4f\n", x-y}')
  local soft=$(awk -v x=$hard 'BEGIN{printf "%.4f\n", 1/x}')
  local elin=$(awk -v x=$mu -v y=$hard 'BEGIN{printf "%.4f\n", x^2/(2*y)}')
  local nuin=$(awk -v x=$homo -v y=$tcne 'BEGIN{printf "%.4f\n", x-y}')
  printf '%-35s%7s eV\n' "Ionization energy:" "$ie"
  printf '%-35s%7s eV\n' "Electron affinity:" "$ea"
  printf '%-35s%7s eV\n' "Mulliken electronegativity:" "$chi"
  printf '%-35s%7s eV\n' "Chemical potential:" "$mu"
  printf '%-35s%7s eV\n' "Hardness:" "$hard"
  printf '%-35s%7s 1/eV\n' "Softness:" "$soft"
  printf '%-35s%7s eV\n' "Electrophilicity index:" "$elin"
  printf '%-35s%7s eV\n' "Nucleophilicity index:" "$nuin"
}

# Polarization extraction function
pol_extract_func() {
  awk '/diagonalized tensor:/{getline;print}' "$1"
}

# Polarization unit conversion
bohr_to_ang() {
  awk "BEGIN{printf \"%.5f\", $1 / 6.748228}"
}

print_bohr() {
  awk "BEGIN{printf \"%.5f\", $1}"
}

# Isotropic polarizability
iso_pol() {
  awk "BEGIN{printf \"%.3f\", ($1+$2+$3)/3}"
}

# Anisotropic polarizability
ani_pol() {
  awk "BEGIN{printf \"%.3f\", sqrt((($1-$2)^2+($2-$3)^2+($3-$1)^2)/2)}"
}

# Polarizability calculations
pol_calc() {
  local pol_bohr=($(pol_extract_func "$1"))
  local b_xx=${pol_bohr[0]}
  local b_yy=${pol_bohr[1]}
  local b_zz=${pol_bohr[2]}
  local b_x
  b_x=$(print_bohr "$b_xx")
  local b_y
  b_y=$(print_bohr "$b_yy")
  local b_z
  b_z=$(print_bohr "$b_zz")
  printf "Diagonalized polarizability tensor (bohr^3):\n"
  printf "%8s%12s%10s%12s%10s%12s\n\n" "a_xx =" "$b_x" "a_yy =" "$b_y" "a_zz =" "$b_z"
  local a_x
  a_x=$(bohr_to_ang "$b_xx")
  local a_y
  a_y=$(bohr_to_ang "$b_yy")
  local a_z
  a_z=$(bohr_to_ang "$b_zz")
  printf "Diagonalized polarizability tensor (ang^3):\n"
  printf "%8s%12s%10s%12s%10s%12s\n\n" "a_xx =" "$a_x" "a_yy =" "$a_y" "a_zz =" "$a_z"
  local iso
  iso=$(iso_pol "$a_x" "$a_y" "$a_z")
  local ani
  ani=$(ani_pol "$a_x" "$a_y" "$a_z")
  printf '%-35s%7s\n' "Isotropic polarizability:" "$iso"
  printf '%-35s%7s\n\n' "Anisotropic polarizability:" "$ani"
}

# ESD replotting values extraction functions
dele_extract_func() {
  awk '/Adiabatic/ {print $4}' "$1"
}

tdip_extract_func() {
  awk '/Reference transition dipole/{c=3}c&&c--' "$1" \
    | awk 'sub(/.*[^(]*\(/,"") && sub(/).*/,"") {print $1"\n"$2}' \
    | awk '{print $1}' ORS="," \
    | awk '{sub(/,$/,""); print}'
}
