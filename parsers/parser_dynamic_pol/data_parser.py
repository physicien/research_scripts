#!/usr/bin/python3
import sys
import os
import re
import pandas as pd
import argparse
import numpy as np
from log_reader import MoleculeData

#global list
data_list=list()
header = ["name","molecule","natoms","freq","axx","ayy","azz","dipole"]

#create parser
parser = argparse.ArgumentParser(prog='data_parser',\
    description='Parse data from all .log files to easily plot')

#file is required
parser.add_argument("filename",
    nargs='+',
    help="the .log output file")

#parse arguments
args = parser.parse_args()

mol_list=list()

for index,path in enumerate(args.filename):
    filename_path = path
    mol = MoleculeData(filename_path)
    mol_data = {
        "name": mol.name,
        "molecule": mol.molecule,
        "natoms": mol.natoms,
        "freq": mol.freq,
        "axx": mol.axx,
        "ayy": mol.ayy,
        "azz": mol.azz,
        "dipole": mol.dipole
    }
    mol_list.append(mol_data)
    #Why is it in the loop???
    data_list = sorted(mol_list, key=lambda d: (d["molecule"],float(d["freq"]))) 

df = pd.DataFrame(data_list)
df.to_csv("dyn_pol_data.csv", index=False, header=header)

