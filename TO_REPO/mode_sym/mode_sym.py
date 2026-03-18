#!/usr/bin/python3
from hess_parser import HessianData
from posym import SymmetryNormalModes
import argparse

#create parser
parser = argparse.ArgumentParser(prog='mode_sym',\
        description='Parse data from .hess file')

#file is required
parser.add_argument("filename",
                    nargs=1,
                    help="the .hess file")

#point group is required
parser.add_argument("-gr","--group",
                    type=str,
                    required=True,
                    help="select the point group of the molecule"
                    )

#parse arguments
args = parser.parse_args()
path = args.filename[0]
gr = "{:s}".format(args.group)

#parse hessian data
hessian = HessianData(path)

#extract required information from ORCA calculation
coordinates = hessian.atoms
symbols = hessian.symbol
normal_modes = hessian.normal_modes[6:]
frequencies = hessian.freq[6:]

sym_modes_gs = SymmetryNormalModes(group=gr, coordinates=coordinates,
                                   modes=normal_modes, symbols=symbols)
for i in range(len(normal_modes)):
    print('Mode {:2}: {:8.3f} :'.format(i + 7, frequencies[i]),
          sym_modes_gs.get_state_mode(i))

print('Total symmetry: ', sym_modes_gs)
