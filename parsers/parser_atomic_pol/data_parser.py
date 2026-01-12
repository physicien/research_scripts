#!/usr/bin/python3
import sys
import os
import re
import pandas as pd
import argparse
import numpy as np
from log_reader import MoleculeData, AtomicData
#pd.set_option('display.max_rows', None)

#global list
data_list=list()
header_mol = ["name","molecule","natoms","freq","axx","ayy","azz","dipole"]
header_xyz = ["element","x","y","z"]
header_dip = ["ux","uy","uz"]
header_pol = ["axx","ayy","azz","axy","axz","ayz"]

#functions
def bohr_to_ang(pol):
    return pol/6.748228

def iso_pol(df):
    xx=df["axx"]
    yy=df["ayy"]
    zz=df["azz"]
    return np.average([xx,yy,zz])

def anisotropy(df):
    xx=df["axx"]
    yy=df["ayy"]
    zz=df["azz"]
    xy=df["axy"]
    xz=df["axz"]
    yz=df["ayz"]
    return 3*(xy**2+xz**2+yz**2)+0.5*((xx-yy)**2+(xx-zz)**2+(yy-zz)**2)

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

    atom = AtomicData(filename_path)
    df_xyz = pd.DataFrame(atom.atoms, columns=header_xyz)
    df_dip = pd.DataFrame(atom.atom_dip, columns=header_dip)
    df_pol = pd.DataFrame(atom.atom_pol, columns=header_pol)
    df_atoms = pd.concat([df_xyz,df_dip,df_pol],axis=1)
    
    df_atoms["iso_pol"]=df_atoms.apply(iso_pol, axis=1)
    df_atoms["anisotropy"]=df_atoms.apply(anisotropy, axis=1)

    col_iso = ["element","x","y","z","iso_pol"]
    col_aniso = ["element","x","y","z","anisotropy"]
    col_w = [3,18,18,18,18]
    fname_iso = str(mol.molecule) + "_iso.chg"
    fname_aniso = str(mol.molecule) + "_aniso.chg"
    iso_string = df_atoms.to_string(columns=col_iso,col_space=col_w,
                                    header=None,index=None,
                                    float_format='%10.10f')
    with open(fname_iso, "w") as text_file:
        text_file.write(iso_string)
    aniso_string = df_atoms.to_string(columns=col_aniso,col_space=col_w,
                                    header=None,index=None,
                                    float_format='%10.10f')
    with open(fname_aniso, "w") as text_file:
        text_file.write(aniso_string)
#    print(df_atoms["iso_pol"].apply(bohr_to_ang))

#df = pd.DataFrame(data_list)
#df.to_csv("dyn_pol_data.csv", index=False, header=header_mol)

