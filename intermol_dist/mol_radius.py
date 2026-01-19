#!/usr/bin/python3

import numpy as np
import pandas as pd
import argparse
import math
from scipy.spatial import distance

#Constants
n_rad=15
headers = ["atom","x","y","z"]

def shortest_dist(df):
    center=[[0,0,0]]
    mol=df[["x","y","z"]].to_numpy()
    return distance.cdist(center,mol).min()

def longest_dist(df):
    center=[[0,0,0]]
    mol=df[["x","y","z"]].to_numpy()
    return distance.cdist(center,mol).max()

def avg_dist(df):
    center=[[0,0,0]]
    mol=df[["x","y","z"]].to_numpy()
    return distance.cdist(center,mol).mean()

def avg10_dist(df):
    center=[[0,0,0]]
    mol=df[["x","y","z"]].to_numpy()
    distribution=np.sort(distance.cdist(center,mol))
    print(distribution)
    return distribution[0,0:n_rad-1].mean()

#Create parser
parser = argparse.ArgumentParser(prog='mol_radius',\
        description='Parse data from .xyz file')

#File is required
parser.add_argument('filename',
        help='the .xyz data file')

#Parse arguments
args = parser.parse_args()

#Data processing
path = args.filename
df = pd.read_table(path,skiprows=2,sep="\s+",names=headers)

ful_radius = shortest_dist(df)
max_radius = longest_dist(df)
avg_radius = avg_dist(df)
avg10_radius = avg10_dist(df)

print(f'\nFullerene minimal radius:\t{ful_radius:.4f} ang')
print(f'Fullerene maximal radius:\t{max_radius:.4f} ang')
print(f'Fullerene average radius:\t{avg_radius:.4f} ang\n')
print(f'Fullerene avg {n_rad} min radius:\t{avg10_radius:.4f} ang\n')
