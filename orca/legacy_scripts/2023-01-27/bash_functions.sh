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

# Function to print the starting time
print_start (){
  printf "Starting run at: $(date --date=@$1 +"(%F)  %T")\n\n"
}

# Function to print the ending time
print_end (){
  local ti=$1
  local tf=$2
  line_separator
  echo "Program finished with exit code $? at: $(date --date=@$tf +"(%F)  %T")"
  total_run_time $ti $tf
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

# ORCA orbital generation from OPT module
molden_orca(){
  $EBROOTORCA/orca_2mkl $1 -molden
  mv $1.molden.input $1.molden
  printf "\n"
}

###################################
# ORCA output formating functions #
###################################

# Print SYM output
print_sym_output() {
  sym_name=$1
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

# Print IO output
print_io_output() {
  local io_name=$1
  local opt_name=$2
  io_calc $io_name.out $opt_name.out
  print_output_file "$io_name.out"
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

# Print LGT output
print_lgt_output() {
  local lgt_name=$1
  molden_orca $opt_name
  awk -v RS= -n -v OSR='\n\n' '/NO   OCC/ {a=$0} END{print a}' $lgt_name.out \
    | awk '$2 ~ /2.0000/{x=NR+1}(NR<=x){print}' \
    | tail -2 \
    | awk '{printf "%s\t",$4}' \
    | awk '{print "HOMO=",$1,"eV     LUMO=",$2,"eV     gap=",$2-$1,"eV\n"}'
  awk '/Total Energy/{
          inside = 1
          text = ""
        }
      inside {text = text $0 RS} /DFET/ {inside = 0}
      END {printf "%s", text}' < $lgt_name.out
  printf "\n"
  section_title "POLARIZABILITY"
  pol_calc $lgt_name.out
  awk -v RS= -n -v OSR='\n\n' '/DIPOLE MOMENT/{print $0}' $lgt_name.out
  print_output_file "$lgt_name.out"
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
  printf '%-35s%7s eV\n' "Ionization energy:" $eio
}

# Polarization extraction function
pol_extract_func () {
  local a=$(awk '/diagonalized tensor:/{getline;print}' $1)
  local pol_bohr=($a)
  echo ${pol_bohr[@]}
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
  local avg=$(avg_pol $a_xx $a_yy $a_zz)
  local ani=$(ani_pol $a_xx $a_yy $a_zz)
  printf '%-35s%7s\n' "Average polarizability:" $avg
  printf '%-35s%7s\n\n' "Anisotropic polarizability:" $ani
}

