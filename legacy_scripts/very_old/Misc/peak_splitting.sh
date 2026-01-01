#!/bin/bash

FILE=$1
filename="${FILE%%.*}"
nroot=50

awk -v RS= -v OSR='\n\n' '/ELECTRIC DIPOLE/' $FILE | tail -n $nroot | awk \
    -v fn=$filename 'function abs(x) {return x < 0.0 ? -x : x}
    {
        if ($5 >= 0.0001){
            if (abs($7) > abs($6) && abs($7) > abs($8)){
                print $0, " s" ;
            }
            else {
                print $0, " d" ;
            }
        }
    }'
