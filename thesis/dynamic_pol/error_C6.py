#!/usr/bin/python3

import pandas as pd

#GLOBAL CONSTANTS
DATAPATH1 = "./result_C6.csv"
DATAPATH2 = "./result_C6_London.csv"
df1 = pd.read_csv(DATAPATH1,comment='#')
df2 = pd.read_csv(DATAPATH2,comment='#')

#functions
def error(theo,approx):
    return (approx-theo)/theo

df2["err_000"] = error(df1["C6_000"],df2["C6_000"])
df2["err_202"] = error(df1["C6_202"],df2["C6_202"])
df2["err_022"] = error(df1["C6_022"],df2["C6_022"])
df2["err_22X"] = error(df1["C6_22X"],df2["C6_22X"])
print(df1)
print(df2)
#print(df2[["C6_000","err_000","C6_202","err_202",
#           "C6_022","err_022","C6_22X","err_22X"]])
