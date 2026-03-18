#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
from scipy.optimize import curve_fit
from uncertainties import ufloat
from uncertainties import unumpy as unp

#GLOBAL CONSTANTS
DATAPATH0 = "./data/lab_radius.csv"
DATAPATH1 = "./data/lab_tubes.csv"
df0 = pd.read_csv(DATAPATH0)
df1 = pd.read_csv(DATAPATH1)
t0 = 3.127
dt0 = 0.195
ipyrb = 199.0859
apyrb = 177.9258
ie_pyr = 7.16072
conv_eV = 96.4869 #kJ mol-1
R = 8.31446261815324e-03
T = 295.15
nsig=2

#functions
def bohr_to_ang(pol):
    return pol/6.748228

def iso_pol(df):
    x=df["axx"]
    y=df["ayy"]
    z=df["azz"]
    return np.average([x,y,z])

def ani_pol(df):
    x=df["axx"]
    y=df["ayy"]
    z=df["azz"]
    return ((0.5*((x-y)**2+(x-z)**2+(y-z)**2))**0.5)

def log(df):
    tR=df["tR"]
    return math.log((tR-t0)/t0)

def dlog(df):
    tR=df["tR"]
    dtR=nsig*df["dtR"]
    return math.sqrt((1/(tR-t0))**2*dtR**2 + (tR/(tR*t0-t0**2))**2*dt0**2)

def linearFunc(x,intercept,slope):
    y = intercept + slope * x
    return y

def chi_sq_red(x,y,dy,inter,slope):
    chi2 = sum((y-linearFunc(x,inter,slope))**2/dy**2)
    dof = len(y) - 2
    return chi2/dof

def a_ie(df):
    ie=df["ie"]
    return 3/2*ie_pyr*ie/(ie_pyr+ie)

def m_slope(slope,dslope):
    m=ufloat(slope,dslope)
    return m

def r_iso(df):
    a = a_ie(df)
    slope = df["slope_iso"]
    dslope = df["dslope_iso"]
    m = m_slope(slope,dslope)
    result=abs(a*ipyr/(m*R*T))**(1/6)
    return '{:.3f}'.format(result)

def r_eff(df):
    a = a_ie(df)
    slope = df["slope_eff"]
    dslope = df["dslope_eff"]
    m = m_slope(slope,dslope)
    result=abs(a*ipyr/(m*R*T))**(1/6)
    return '{:.3f}'.format(result)

def r_full(df):
    a = a_ie(df)
    slope = df["slope_full"]
    dslope = df["dslope_full"]
    m = m_slope(slope,dslope)
    result=abs(a/(m*R*T))**(1/6)
    return '{:.3f}'.format(result)

#Data processing
ipyr = bohr_to_ang(ipyrb)
apyr = bohr_to_ang(apyrb)
iso0 = df0.apply(iso_pol, axis=1)
iso1 = df1.apply(iso_pol, axis=1)
ani0 = df0.apply(ani_pol, axis=1)
ani1 = df1.apply(ani_pol, axis=1)
log_data0 = df0.apply(log, axis=1) 
log_data1 = df1.apply(log, axis=1) 
dlog_data0 = df0.apply(dlog, axis=1)
dlog_data1 = df1.apply(dlog, axis=1)
eff0 = iso0 - ani0/6
eff1 = iso1 - ani1/6
c_factor0 = iso0*ipyr - (iso0*apyr + ani0*ipyr - ani0*apyr)/6 
c_factor1 = iso1*ipyr - (iso1*apyr + ani1*ipyr - ani1*apyr)/6 

df0["iso"] = iso0
df1["iso"] = iso1
df0["eff"] = eff0
df1["eff"] = eff1
df0["c_factor"] = c_factor0
df1["c_factor"] = c_factor1

x20 = bohr_to_ang(iso0)
a_fit20,cov20=curve_fit(linearFunc,x20,log_data0,sigma=dlog_data0,
        absolute_sigma=True)
inter20 = a_fit20[0]
slope20 = a_fit20[1]
d_inter20 = np.sqrt(cov20[0][0])
d_slope20 = np.sqrt(cov20[1][1])
chi2_red20=chi_sq_red(x20,log_data0,dlog_data0,inter20,slope20)

df0["slope_iso"] = slope20
df0["dslope_iso"] = d_slope20

x21 = bohr_to_ang(iso1)
a_fit21,cov21=curve_fit(linearFunc,x21,log_data1,sigma=dlog_data1,
        absolute_sigma=True)
inter21 = a_fit21[0]
slope21 = a_fit21[1]
d_inter21 = np.sqrt(cov21[0][0])
d_slope21 = np.sqrt(cov21[1][1])
chi2_red21=chi_sq_red(x21,log_data1,dlog_data1,inter21,slope21)

df1["slope_iso"] = slope21
df1["dslope_iso"] = d_slope21

x30 = bohr_to_ang(eff0)
a_fit30,cov30=curve_fit(linearFunc,x30,log_data0,sigma=dlog_data0,
        absolute_sigma=True)
inter30 = a_fit30[0]
slope30 = a_fit30[1]
d_inter30 = np.sqrt(cov30[0][0])
d_slope30 = np.sqrt(cov30[1][1])
chi2_red30=chi_sq_red(x30,log_data0,dlog_data0,inter30,slope30)

df0["slope_eff"] = slope30
df0["dslope_eff"] = d_slope30

x31 = bohr_to_ang(eff1)
a_fit31,cov31=curve_fit(linearFunc,x31,log_data1,sigma=dlog_data1,
        absolute_sigma=True)
inter31 = a_fit31[0]
slope31 = a_fit31[1]
d_inter31 = np.sqrt(cov31[0][0])
d_slope31 = np.sqrt(cov31[1][1])
chi2_red31=chi_sq_red(x31,log_data1,dlog_data1,inter31,slope31)

df1["slope_eff"] = slope31
df1["dslope_eff"] = d_slope31

x40 = bohr_to_ang(bohr_to_ang(c_factor0))
a_fit40,cov40=curve_fit(linearFunc,x40,log_data0,sigma=dlog_data0,
        absolute_sigma=True)
inter40 = a_fit40[0]
slope40 = a_fit40[1]
d_inter40 = np.sqrt(cov40[0][0])
d_slope40 = np.sqrt(cov40[1][1])
chi2_red40=chi_sq_red(x40,log_data0,dlog_data0,inter40,slope40)

df0["slope_full"] = slope40
df0["dslope_full"] = d_slope40

x41 = bohr_to_ang(bohr_to_ang(c_factor1))
a_fit41,cov41=curve_fit(linearFunc,x41,log_data1,sigma=dlog_data1,
        absolute_sigma=True)
inter41 = a_fit41[0]
slope41 = a_fit41[1]
d_inter41 = np.sqrt(cov41[0][0])
d_slope41 = np.sqrt(cov41[1][1])
chi2_red41=chi_sq_red(x41,log_data1,dlog_data1,inter41,slope41)

df1["slope_full"] = slope41
df1["dslope_full"] = d_slope41

df0["iso_r"] = df0.apply(r_iso, axis=1)
df1["iso_r"] = df1.apply(r_iso, axis=1)
df0["eff_r"] = df0.apply(r_eff, axis=1)
df1["eff_r"] = df1.apply(r_eff, axis=1)
df0["full_r"] = df0.apply(r_full, axis=1)
df1["full_r"] = df1.apply(r_full, axis=1)

print(df0[["name","iso_r","eff_r","full_r"]])
#print(df1[["name","iso_r","eff_r","full_r"]])
