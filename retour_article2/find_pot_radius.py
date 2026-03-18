#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
from uncertainties import ufloat
from uncertainties import unumpy as unp
from uncertainties.umath import log

#GLOBAL CONSTANTS
DATAPATH = "./data/lab_radius.csv"
df = pd.read_csv(DATAPATH)
t0 = ufloat(3.127,0.195)
ipyrb = 199.0859
apyrb = 177.9258
ie_pyr = 7.16072
flowrate = 3.06
vm = t0*flowrate*1000
dc = 10
col_L = 250
porosity = vm/(math.pi*(dc/2)**2*col_L)
F = (1-porosity)/porosity
logF = log(F)
conv_eV = 96.4869 #kJ mol-1
R = 8.31446261815324e-03
T = 295.15
nsig=2
shift=3.47*1.22

#functions
def bohr_to_ang(pol):
    return pol/6.748228

def iso_pol(df):
    x=df["axx"]
    y=df["ayy"]
    z=df["azz"]
    return bohr_to_ang(np.average([x,y,z]))

def ani_pol(df):
    x=df["axx"]
    y=df["ayy"]
    z=df["azz"]
    return bohr_to_ang(((0.5*((x-y)**2+(x-z)**2+(y-z)**2))**0.5))

def tlog(df):
    tR=ufloat(df["tR"],df["dtR"])
    return log((tR-t0)/t0) 

def U_iso(df):
    ie=df["ie"]
    iso=iso_pol(df)
    logK=tlog(df)
    r=df["radius"]+shift
    b=3/2*ie_pyr*ie/(ie_pyr+ie)*conv_eV
    a=1/(R*r**6)
    result=-(b*a/T*ipyr*iso+logF-logK)
    return '{:.3f}'.format(result)

def U_eff(df):
    ie=df["ie"]
    iso=iso_pol(df)
    ani=ani_pol(df)
    eff=iso - ani/6
    logK=tlog(df)
    r=df["radius"]+shift
    b=3/2*ie_pyr*ie/(ie_pyr+ie)*conv_eV
    a=1/(R*r**6)
    result=-(b*a/T*ipyr*eff+logF-logK)
    return '{:.3f}'.format(result)

def U_full(df):
    ie=df["ie"]
    iso=iso_pol(df)
    ani=ani_pol(df)
    tot=iso*ipyr - (ipyr*ani + apyr*iso - apyr*ani)/6
    logK=tlog(df)
    r=df["radius"]+shift
    b=3/2*ie_pyr*ie/(ie_pyr+ie)*conv_eV
    a=1/(R*r**6)
    result=-(b*a/T*tot+logF-logK)
    return '{:.3f}'.format(result)

#Data processing
ipyr = bohr_to_ang(ipyrb)
apyr = bohr_to_ang(apyrb)
iso = df.apply(iso_pol, axis=1)
ani = df.apply(ani_pol, axis=1)
eff = iso - ani/6
c_factor = iso*ipyr - (iso*apyr + ani*ipyr - ani*apyr)/6 

df["iso"] = iso
df["eff"] = eff
df["c_factor"] = c_factor
df["iso_U"] = df.apply(U_iso, axis=1)
df["eff_U"] = df.apply(U_eff, axis=1)
df["full_U"] = df.apply(U_full, axis=1)

print(df[["name","iso_U","eff_U","full_U","radius"]])
#print(df[["name","iso","iso_U"]])
#print(df[["name","eff","eff_U"]])
#print(df[["name","c_factor","full_U"]])
