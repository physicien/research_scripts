#!/bin/bash

###################
# Timing function #
###################

time_dif3() {
  echo "scale=3; (${2}-${1})/1" | bc -l | awk '{printf "%.3f", $0}'
}

time_dif1() {
  echo "scale=3; (${2}-${1})/1" | bc -l | awk '{printf "%.1f", $0}'
}

total_run_time() {
  local sec=$(time_dif3 $1 $2)
  printf "TOTAL RUN TIME: "
  eval "echo $(date -ud "@$sec" +'$((%s/3600/24)) days %k hours %-M minutes\
      %-S seconds %3N msec')"
}

time_now() {
  echo $(date +"%s.%3N")
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
  termwidth="80"
  padding="$(printf '%0.1s' \ {1..80})"
  printf '%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" \
      "$1" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

# Function to print the section title
section_title() {
  line_separator; center "$1"; line_separator
}

# Function to print the starting time
print_start() {
  printf "Starting run at: $(date --date=@$1 +"(%F)  %T")\n\n"
}

# Function to print the ending time
print_end() {
  local ti=$1
  local tf=$2
  line_separator
  echo "Program finished with exit code $? at: $(date --date=@$tf +"(%F)  %T")"
  total_run_time $ti $tf
}

# Function to print the input parameters
print_inp() {
  printf '%-28s%-1s %s\n' "$1" ":" $2
}

# Function to print the detailed output file
print_output_file() {
  printf '\n%57s:  %12s\n' "Detailed output" $1
}

#####################
# Running functions #
#####################

# ORCA module load
load_orca() {
  module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
  module load orca/5.0.4
  export RSH_COMMAND="/usr/bin/ssh -x"
}

# ORCA running function + timing + output formating
run_orca() {
  local name="$1"
  local title="$2"
  local description="$3"
  local ti
  local tf

  ti=$(time_now)
  section_title "$title"
  printf '%-50s... ' "$description"
  $EBROOTORCA/orca $name.inp > $name.out
  tf=$(time_now)
  printf "done (%7s sec)\n\n" $(time_dif1 $ti $tf)
}

# ORCA orbital generation from OPT module
molden_orca() {
  $EBROOTORCA/orca_2mkl $1 -molden
  mv $1.molden.input $1.molden
  printf "\n"
}

# Global energetics output formating
run_ener() {
  local title="$1"
  local ti
  local tf

  ti=$(time_now)
  section_title "$title"
}

###################################
# ORCA output formating functions #
###################################

# Print SYM output
print_sym_output() {
  local sym_name=$1
  awk '/This point group/{c=2}c&&c--' $sym_name.out
  print_output_file "$sym_name.out"
}

# Print OPT output
print_opt_output() {
  local opt_name=$1
  molden_orca $opt_name
  awk -v RS= -n -v OSR='\n\n' '/NO   OCC/ {a=$0} END{print a}' $opt_name.out \
    | awk '$2 ~ /2.0000/{x=NR+1}(NR<=x){print}' \
    | tail -2 \
    | awk '{printf "%s\t",$4}' \
    | awk '{print "HOMO=",$1,"eV     LUMO=",$2,"eV     gap=",$2-$1,"eV\n"}'
  awk '/Total Energy/{
          inside = 1
          text = ""
        }
      inside {text = text $0 RS} /DFET/ {inside = 0}
      END {printf "%s", text}' < $opt_name.out
  print_output_file "$opt_name.out"
}

# Print IE output
print_ie_output() {
  local opt_name=$1
  local ie_name=$2
  ie_calc $ie_name.out $opt_name.out
  print_output_file "$ie_name.out"
}

# Print EA output
print_ea_output() {
  local opt_name=$1
  local ea_name=$2
  ea_calc $opt_name.out $ea_name.out
  print_output_file "$ea_name.out"
}

# Print EC output
print_ec_output() {
  local opt_name=$1
  local ie_name=$2
  local ea_name=$3
  ec_calc $opt_name.out $ie_name.out $ea_name.out
  print_output_file "$ie_name.out"
}

# Print UV output
print_uv_output() {
  local uv_name=$1
  local nroots=$2
  awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $uv_name.out \
    | head -n 5 \
    | tail -n 2
  printf "\n"
  awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $uv_name.out \
    | tail -n $nroots \
    | awk ' function abs(x) {return x < 0.0 ? -x : x}
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
  print_output_file "$uv_name.out"
}

# Print NMR output
print_nmr_output() {
  local nmr_name=$1
  awk -v RS= -v OSR='\n\n' '/CHEMICAL SHIELDING/' $nmr_name.out
  awk -v RS= -v OSR='\n\n' '/Nucleus  Element/' $nmr_name.out
  print_output_file "$nmr_name.out"
}

# Print POL output
print_pol_output() {
  local pol_name=$1
  pol_calc $pol_name.out
  awk -v RS= -n -v OSR='\n\n' '/DIPOLE MOMENT/{print $0}' $pol_name.out
  print_output_file "$pol_name.out"
}

# Print FRQ output
print_frq_output() {
  local frq_name=$1
  awk -v RS= -v OSR='\n\n' '/Mode   freq/' $frq_name.out
  print_output_file "$frq_name.out"
}

# Print RAM output
print_ram_output() {
  local ram_name=$1
  awk -v RS= -v OSR='\n\n' '/Activity/' $ram_name.out
  print_output_file "$ram_name.out"
}

# Print GS output
print_gs_output() {
  local gs_name=$1
  molden_orca $gs_name
  awk -v RS= -n -v OSR='\n\n' '/NO   OCC/ {a=$0} END{print a}' $gs_name.out \
    | awk '$2 ~ /2.0000/{x=NR+1}(NR<=x){print}' \
    | tail -2 \
    | awk '{printf "%s\t",$4}' \
    | awk '{print "HOMO=",$1,"eV     LUMO=",$2,"eV     gap=",$2-$1,"eV\n"}'
  awk '/Total Energy/{
          inside = 1
          text = ""
        }
      inside {text = text $0 RS} /DFET/ {inside = 0}
      END {printf "%s\n", text}' < $gs_name.out
  printf "\n"
  awk -v RS= -v OSR='\n\n' '/Mode   freq/' $gs_name.out
  print_output_file "$gs_name.out"
}

# Print ESD output
print_esd_output() {
  local esd_name=$1
  awk '/The sum of K*K/' $esd_name.out
  awk -v RS= -v OSR='\n\n' '/Homogeneous linewidth is:/' $esd_name.out
  awk '/The absorption spectrum/' $esd_name.out
  print_output_file "$esd_name.out"
}

print_scf_output() {
  local scf_name=$1
  molden_orca $scf_name
  awk '/Total Energy/{
          inside = 1
          text = ""
        }
      inside {text = text $0 RS} /DFET/ {inside = 0}
      END {printf "%s", text}' < $scf_name.out
  print_output_file "$scf_name.out"
}

print_xtb_output() {
  local xtb_name=$1
  grep 'G-E(el)' < $xtb_name.out
  print_output_file "$xtb_name.out"
}

# Print global indices output
print_glo_output() {
  local gs_name=$1
  local ie_name=$2
  local ea_name=$3
  local tce_name=$4
  awk -v RS= -n -v OSR='\n\n' '/NO   OCC/ {a=$0} END{print a}' $gs_name.out \
    | awk '$2 ~ /2.0000/{x=NR+1}(NR<=x){print}' \
    | tail -2 \
    | awk '{printf "%s\t",$4}' \
    | awk '{print "HOMO=",$1,"eV     LUMO=",$2,"eV     gap=",$2-$1,"eV\n"}'
  glo_calc $gs_name.out $ie_name.out $ea_name.out $tce_name.out
}

#############################
# Post-processing functions #
#############################

# Print final total energy
etot_print() {
  awk '/Total Energy/ {a=$0} END{print a}' $1
}

# Total energy extraction function
etot_extract_func() {
  local a=$(awk '/Total Energy/ {a=$0} END{print a}' $1 | awk '{print $6}')
  echo "$a"
}

# HOMO extraction function
homo_extract_func() {
  local a=$(awk -v RS= -n -v OSR='\n\n' '/NO   OCC/ {a=$0} END{print a}' $1 \
    | awk '$2 ~ /2.0000/{print}' \
    | tail -1 \
    | awk '{printf "%s\t",$4}'# \
  )
  echo "$a"
}

# Vertical ionization energy
ie_calc() {
  local e1=$(etot_extract_func $1)
  local e2=$(etot_extract_func $2)
  local eio=$(echo "scale=5; $e1 - $e2" | bc -l)
  printf '%-35s%7s eV\n' "Ionization energy:" $eio
}

# Vertical electron affinity
ea_calc() {
  local e1=$(etot_extract_func $1)
  local e2=$(etot_extract_func $2)
  local eaf=$(echo "scale=5; $e1 - $e2" | bc -l)
  printf '%-35s%7s eV\n' "Electron affinity:" $eaf
}

# Electrochemical band gap
ec_calc() {
  local e1=$(etot_extract_func $1)
  local e2=$(etot_extract_func $2)
  local e3=$(etot_extract_func $3)
  local ecf=$(echo "scale=5; $e2 + $e3 - 2*$e1" | bc -l)
  printf '%-35s%7s eV\n' "Electrochemical band gap:" $ecf
}

# Global indices
glo_calc() {
  local gs=$(etot_extract_func $1)
  local ca=$(etot_extract_func $2)
  local an=$(etot_extract_func $3)
  local homo=$(homo_extract_func $1)
  local tce=$(homo_extract_func $4)
  local ie=$(awk -v x=$ca -v y=$gs 'BEGIN{printf "%.4f\n", x-y}')
  local ea=$(awk -v x=$gs -v y=$an 'BEGIN{printf "%.4f\n", x-y}')
  local chi=$(awk -v x=$ie -v y=$ea 'BEGIN{printf "%.4f\n", (x+y)/2}')
  local mu=$(awk -v x=$chi 'BEGIN{printf "%.4f\n", -1*x}')
  local hard=$(awk -v x=$ie -v y=$ea 'BEGIN{printf "%.4f\n", x-y}')
  local soft=$(awk -v x=$hard 'BEGIN{printf "%.4f\n", 1/x}')
  local elin=$(awk -v x=$mu -v y=$hard 'BEGIN{printf "%.4f\n", x^2/(2*y)}')
  local nuin=$(awk -v x=$homo -v y=$tce 'BEGIN{printf "%.4f\n", x-y}')
  printf '%-35s%7s eV\n' "Ionization energy:" $ie
  printf '%-35s%7s eV\n' "Electron affinity:" $ea
  printf '%-35s%7s eV\n' "Mulliken electronegativity:" $chi
  printf '%-35s%7s eV\n' "Chemical potential:" $mu
  printf '%-35s%7s eV\n' "Hardness:" $hard
  printf '%-35s%7s 1/eV\n' "Softness:" $soft
  printf '%-35s%7s eV\n' "Electrophilicity index:" $elin
  printf '%-35s%7s eV\n' "Nucleophilicity index:" $nuin
}

# Polarization extraction function
pol_extract_func() {
  local a=$(awk '/diagonalized tensor:/{getline;print}' $1)
  local pol_bohr=($a)
  echo ${pol_bohr[@]}
}

# Polarization unit conversion
bohr_to_ang() {
  local a3_to_b3=6.748228           # Conversion factor ang^3 to bohr^3
  echo "scale=5; $1/$a3_to_b3" | bc -l
}

# Isotropic polarizability
iso_pol() {
  echo "scale=3; ($1+$2+$3)/3" | bc -l
}

# Anisotropic polarizability
ani_pol() {
  echo "scale=3; sqrt((($1-$2)^2+($2-$3)^2+($3-$1)^2)/2)" | bc -l
}

# Polarizability calculations
pol_calc() {
  local pol_bohr=($(pol_extract_func $1))
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
  local iso=$(iso_pol $a_xx $a_yy $a_zz)
  local ani=$(ani_pol $a_xx $a_yy $a_zz)
  printf '%-35s%7s\n' "Isotropic polarizability:" $iso
  printf '%-35s%7s\n\n' "Anisotropic polarizability:" $ani
}

