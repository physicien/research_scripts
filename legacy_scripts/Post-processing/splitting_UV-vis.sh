#!/bin/bash

FILE=$1
filename="${FILE%%.*}"
TMPF=$filename.tmp
nroot=400
xmin=350.0
xmax=750.0
eVshft=0.00

shft=$(echo "scale=1; $eVshft*8065.544" | bc -l)


module load StdEnv/2020 gcc/10.3.0 openmpi/4.1.1
module load orca/5.0.2
module load gnuplot/5.2.8

$EBROOTORCA/orca_mapspc $FILE Abs -x07500 -x150000 -w500 -n10000
CURVEFILE=$FILE.abs.dat
rm $FILE.abs.stk

# Data extraction
awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $FILE | tail -n $nroot | awk '
    function abs(x) {return x < 0.0 ? -x : x}
    {
        if ($5 >= 0.0001){
            if (abs($7) > abs($6) && abs($7) > abs($8)){
                print $0, " 1" ;
            }
            else {
                print $0, " 2";
            }
        }
    }' > $TMPF

# Plot section
gnuplot -p <<-EOFMarker
    set terminal svg size 1734,876 enhanced font "sans,24"
    set output "$filename.svg"
    set xrange [$xmin:$xmax]
    stats "$CURVEFILE" u (10000000/\$1):(\$2/400000) nooutput
    set yrange [0:(STATS_max_y*1.02)]
    set border 3 lw 3.0
    set xtics 0.0, 50.0 out nomirror offset 0,0.5
    set mxtics 5
    set ytics out nomirror offset 0.5,0
    set mytics 5
    set format y "%.2f"
    set xlabel "Wavelength (nm)" font "sans,32"
    set ylabel "Intensity (arb. units)" font "sans,32"
    set palette model RGB defined ( 0 '#ff8422', 1 '#43729d' )
    unset key
    unset colorbox
    plot "$CURVEFILE" u (10000000/(\$1+$shft)):(\$2/400000) with lines \
        linecolor "dark-violet" lw 2.0, "$TMPF" u (10000000/(\$2+$shft)):4:(\
        \$9 == 1 ? 0 : 1) with impulses palette lw 2.0
EOFMarker

rm $TMPF
rm $CURVEFILE
