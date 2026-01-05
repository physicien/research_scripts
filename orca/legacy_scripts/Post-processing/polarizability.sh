#!/bin/bash

#######################################
# Job variables and settings:
polfile=$1
a3_to_b3=6.748228           # Conversion factor ang^3 to bohr^3

#######################################
# Extraction function
extract_func () {
    local a=$(awk '/diagonalized tensor:/{getline;print}' $polfile)
    pol_bohr=($a)
}

# Unit conversion function
bohr_to_ang () {
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

# Line separator
line_separator () {
  printf -- '-%.0s' {1..80}; printf "\n"
}

#######################################
extract_func
b_xx=${pol_bohr[0]}
b_yy=${pol_bohr[1]}
b_zz=${pol_bohr[2]}

line_separator
printf "\nDiagonalized polarizability tensor (bohr^3):\n"
printf "  a_xx = %10s     a_yy = %10s     a_zz = %10s\n\n" $b_xx $b_yy $b_zz

a_xx=$(bohr_to_ang $b_xx)
a_yy=$(bohr_to_ang $b_yy)
a_zz=$(bohr_to_ang $b_zz)

printf "Diagonalized polarizability tensor (ang^3):\n"
printf "  a_xx = %10s     a_yy = %10s     a_zz = %10s\n\n" $a_xx $a_yy $a_zz

avg=$(avg_pol $a_xx $a_yy $a_zz)
ani=$(ani_pol $a_xx $a_yy $a_zz)

printf '%-35s%7s\n' "Average polarizability:" $avg
printf '%-35s%7s\n\n' "Anisotropic polarizability:" $ani
line_separator
