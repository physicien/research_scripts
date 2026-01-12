#!/usr/bin/python3
import sys
import os
import re
import pandas as pd
import argparse
import numpy as np
from txt_reader import DataReader

#global list
data_list=list()
header = ["name","experiment"]

#create parser
parser = argparse.ArgumentParser(prog='data_parser',\
    description='Parse data from all .txt files to easily plot')

#file is required
parser.add_argument("filename",
    nargs='+',
    help="the .txt output file")

#parse arguments
args = parser.parse_args()

expt_list=list()

for index,path in enumerate(args.filename):
    filename_path = path
    expt = DataReader(filename_path)
    expt_data = {
        "name": expt.name,
        "experiment": expt.experiment,
    }
    expt_data2 = expt_data | expt.data
    expt_list.append(expt_data2)
    #Why is it in the loop???
    data_list = sorted(expt_list, key=lambda d: d["name"]) 

df = pd.DataFrame(data_list)
print("\nDataReader output.")
print("DataReader should be used directly in your script.")
print(df)
