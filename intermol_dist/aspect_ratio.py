#!/usr/bin/python3

import numpy as np
import pandas as pd
import argparse
import math
from scipy.spatial import distance

#Constants
axis="y"    #y or z
endcaps=60
pyr_len=3.55
headers = ["atom","x","y","z"]

#Functions
def ful_len(df):
    mol_max=max(df[axis])
    mol_min=min(df[axis])
    return mol_max-mol_min

def avg_rad(df):
    center=[[0,0,0]]
    df[[axis]]=0
    mol=df[["x","y","z"]].to_numpy()
    distribution=np.sort(distance.cdist(center,mol))
    return distribution[0,endcaps-1:-1].mean()

def center_section(df):
    center=[[0,0]]
    mol_ax=df.sort_values(by=axis, key=lambda col: abs(col))
    tube=mol_ax.iloc[:len(df)-endcaps]
    center_tube=tube[abs(tube[axis]) <= pyr_len]
    axes=["x","y","z"]
    axes.remove(axis)
    mol=center_tube[axes].to_numpy()
    distri=distance.cdist(center,mol)
    return distri

#Create parser
parser = argparse.ArgumentParser(prog='aspect_ratio',\
        description='Parse data from .xyz file')

#File is required
parser.add_argument('filename',
        help='the .xyz data file')

#Parse arguments
args = parser.parse_args()

#Data processing
path = args.filename
df = pd.read_table(path,skiprows=2,sep="\s+",names=headers)

center_tube = center_section(df)

max_radius = ful_len(df)
avg_rad = avg_rad(df)
avg_center = center_tube.mean()
min_center_rad = center_tube.min()

print(
        f'\n{"Fullerene length:":<20}{max_radius:>10.4f} ang',
        f'\n{"Fullerene diameter:":<20}{2*avg_rad:>10.4f} ang\n'
        f'\n{"Fullerene radius:":<20}{avg_rad:>10.4f} ang'
        f'\n{"Avg. center radius:":<20}{avg_center:>10.4f} ang'
        f'\n{"Min. center radius:":<20}{min_center_rad:>10.4f} ang\n'
)
