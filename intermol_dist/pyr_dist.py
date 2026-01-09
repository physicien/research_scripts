#!/usr/bin/python3

import numpy as np
import pandas as pd
import argparse
import math
from itertools import groupby
from operator import itemgetter
from scipy.spatial import distance

#Constants
headers = ["atom","x","y","z"]

#Functions
def center_of_mass(df):
    x=df["x"]
    y=df["y"]
    z=df["z"]
    return [np.average(x),np.average(y),np.average(z)]

def shortest_dist(df1,df2):
    mol1=df1[["x","y","z"]].to_numpy()
    mol2=df2[["x","y","z"]].to_numpy()
    return distance.cdist(mol1,mol2).min(axis=1).min()

def pyr_to_center(df1,df2):
    mol1=[df1]
    mol2=df2[["x","y","z"]].to_numpy()
    return distance.cdist(mol1,mol2).min()

#Create parser
parser = argparse.ArgumentParser(prog='intermol_dist',\
        description='Parse data from .xyz file')

#File is required
parser.add_argument('filename',
        help='the .xyz data file')

#Parse arguments
args = parser.parse_args()

#Data processing
path = args.filename
df = pd.read_table(path,skiprows=2,sep="\s+",names=headers)
row_C = df[df["atom"]=="C"].index.to_numpy()
mol_rows=[list(map(itemgetter(1),g)) for k, g in groupby(enumerate(row_C), \
        lambda i_x: i_x[0] - i_x[1])]
df_ful = df.iloc[mol_rows[0]]
df_pyr = df.iloc[mol_rows[-1]]
df_pyr_center = df_pyr.iloc[[12,14]]

cofm_ful = center_of_mass(df_ful)
cofm_pyr = center_of_mass(df_pyr_center)
c_to_c = math.dist(cofm_ful,cofm_pyr)
min_dist = shortest_dist(df_ful,df_pyr)
c_to_w = shortest_dist(df_ful,df_pyr_center)
p_to_c = pyr_to_center(cofm_ful,df_pyr)

print(f'\nCenter-to-Center distance:\t{c_to_c:.4f} ang')
print(f'Shortest distance:\t\t{min_dist:.4f} ang')
print(f'Wall-to-Center distance:\t{c_to_w:.4f} ang\n')
print(f'Pyrene-to_Center distance:\t{p_to_c:.4f} ang\n')
