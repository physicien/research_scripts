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
df = pd.read_table(path,skiprows=2,delim_whitespace=True,names=headers)
row_C = df[df["atom"]=="C"].index.to_numpy()
mol_rows=[list(map(itemgetter(1),g)) for k, g in groupby(enumerate(row_C), \
        lambda i_x: i_x[0] - i_x[1])]
df_cnt = df.iloc[mol_rows[0]]
df_ful = df.iloc[mol_rows[1]]

cofm_cnt = center_of_mass(df_cnt)
cofm_ful = center_of_mass(df_ful)
c_to_c = math.dist(cofm_cnt,cofm_ful)
min_dist = shortest_dist(df_cnt,df_ful)

print(f'\nCenter-to-Center distance:\t{c_to_c:.4f} ang')
print(f'Shortest distance:\t\t{min_dist:.4f} ang\n')
