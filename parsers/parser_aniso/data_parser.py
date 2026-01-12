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
header = ["name","natoms","pt_group","homo","lumo","ie","axx","ayy",
        "azz","dipole"]

#create parser
parser = argparse.ArgumentParser(prog='aniso_parser',\
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
        "natoms": mol.natoms,
        "pt_group": mol.ptgroup,
        "homo": mol.homo,
        "lumo": mol.lumo,
        "ie": mol.ie,
        "axx": mol.axx,
        "ayy": mol.ayy,
        "azz": mol.azz,
        "dipole": mol.dipole
    }
    mol_list.append(mol_data)
    data_list = sorted(mol_list, key=lambda d: float(d["natoms"])) 

df = pd.DataFrame(data_list)
df.to_csv("molecules_data.csv", index=False, header=header)

