#!/bin/bash

###################
# Timing function #
###################

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

time_now () {
  echo $(date +"%s.%3N")
}

##############################
# Output formating functions #
##############################

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

# Function to print the input parameters
print_inp (){
  printf '%-28s%-1s %s\n' "$1" ":" $2
}

# Function to print the detailed output file
print_output_file () {
  printf '\n%57s:  %12s\n' "Detailed output" $1
}

#####################
# Running functions #
#####################

# ORCA running function + timing + output formating
run_orca (){
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

#############################
# Post-processing functions #
#############################

# Total energy extraction function
etot_extract_func() {
  local a=$(awk '/Total Energy/ {a=$0} END{print a}' $1 | awk '{print $6}')
  echo "$a"
}

# Ionization energy calculation
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

