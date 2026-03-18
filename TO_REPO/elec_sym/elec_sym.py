#!/usr/bin/python3
import sys
from pyqchem import Structure
from pyqchem.parsers.parser_fchk import parser_fchk
from posym import SymmetryGaussianLinear, SymmetryMolecule
from posym.tools import get_basis_set, build_orbital
import argparse

#create parser
parser = argparse.ArgumentParser(prog='elec_sym',\
        description='Parse data from .fch/.fchk file')

#file is required
parser.add_argument("filename",
                    nargs=1,
                    help="the .fch/.fchk file")

#point group is required
parser.add_argument("-gr","--group",
                    type=str,
                    required=True,
                    help="select the point group of the molecule"
                    )

#individual orbital range - start
parser.add_argument('-orb0','--startorb',
                    type=int,
                    help="start symmetry analysis with orb0"
                    )

#individual orbital range - end
parser.add_argument('-orb1','--endorb',
                    type=int,
                    help="end symmetry analysis with orb0"
                    )

#parse arguments
args = parser.parse_args()
path = args.filename[0]
gr = "{:s}".format(args.group)

#parse electronic structure data
with open(path) as f:
    fchk_txt = f.read()

ee = parser_fchk(fchk_txt)

#extract required information from ORCA calculation
coordinates = ee['structure'].get_coordinates()
symbols = ee['structure'].get_symbols()
sm = SymmetryMolecule(gr, coordinates, symbols)
angles = sm.orientation_angles
mo_coefficients = ee['coefficients']['alpha']
basis = ee['basis']

#check if startorb < 0 - exit if true
if args.startorb:
    if args.startorb < 0:
        print("Warning. orb0 < 0. Exit.")
        sys.exit(1)

#check if startorb > nb of orbitals - exit if true
if args.startorb:
    norb = len(mo_coefficients)-1
    if args.startorb > norb:
        print("Warning. orb0 > {}. Exit.".format(norb))
        sys.exit(1)

#check if endorb < 0 - exit if true
if args.endorb:
    if args.endorb < 0:
        print("Warning. orb1 < 0. Exit.")
        sys.exit(1)

#if startorb argument is given - orbital range
if args.startorb:
    orb0 = args.startorb
else:
    orb0 = 0

#if endorb argument is given - orbital range
if args.endorb:
    orb1 = args.endorb
else:
    orb1 = len(mo_coefficients)

#print results
print("Molecular orbitals (alpha) symmetry")
basis_set = get_basis_set(coordinates, basis)
for i, orbital_coeff in enumerate(mo_coefficients):
    if (i >= orb0 and i <= orb1):
        orbital = build_orbital(basis_set, orbital_coeff)
        sym_orbital = SymmetryGaussianLinear(gr, orbital,
                                             orientation_angles=angles)
        print("Symmetry O{}: ".format(i), sym_orbital)  #.format(i+1)
