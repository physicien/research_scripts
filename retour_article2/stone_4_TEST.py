#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
from scipy.optimize import curve_fit
from uncertainties import ufloat
from uncertainties import unumpy as unp
from uncertainties.umath import log

#GLOBAL CONSTANTS
DATAPATH = "./data/lab_radius.csv"
df = pd.read_csv(DATAPATH,comment='#')
t0 = ufloat(3.127,0.195)
ipyrb = 199.0859    #258.5486#199.0859
apyrb = 177.9258    #238.0660#177.9258
ie_pyr = 7.16072
flowrate = 3.06
vm = t0*flowrate*1000
dc = 10
col_L = 250
porosity = vm/(math.pi*(dc/2)**2*col_L)
F = (1-porosity)/porosity
logF = log(F)
conv_eV = 96.4869 #kJ mol-1
R = 8.31446261815324e-03#8.63e-5
T = 295.15
nsig=1
min_radius=3

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

#def s_area(df):
#    a=bohr_to_ang(df["axx"])
#    b=bohr_to_ang(df["ayy"])
#    c=bohr_to_ang(df["azz"])
#    p=1.6075
#    return 4*math.pi*(1/3*((a*b)**p)+(a*c)**p+(b*c)**p)**(1/p)

def time_log(df):
    tR=ufloat(df["tR"],df["dtR"])
    return log((tR-t0)/t0) 

def logs(df):
    result = R*T*(logF-time_log(df))
    return pd.Series([result.n,result.s])

def dampFunc(r,alpha):
    x=1/alpha*r
    return 1-np.exp(-x)*(1+x+(x**2)/2+(x**3)/6+(x**4)/24+(x**5)/120+(x**6)/720)

def expFunc(df,alpha,r,rho):
    rho_mol = 1/rho + df["radius"]
    return 1*np.exp(-1/alpha*(r-rho_mol))

def solvFunc(df,pol,A,r):
    r0 = df["radius"] + min_radius
#    ie=df["ie"]
#    a=3/2*ie_pyr*ie/(ie_pyr+ie)
#    return 1/A/pol/a*(r-r0)     # Same result but bad shape
    return A*(r-r0)**2 

def dispFunc(df,r,pol,alpha):
    ie=df["ie"]
    a=3/2*ie_pyr*ie/(ie_pyr+ie)*conv_eV
    b=1/(r**6)
    return -b*a*pol#*dampFunc(r,alpha)

def distFunc(df,pol,D):
    ie=df["ie"]
    a=3/2*ie_pyr*ie/(ie_pyr+ie)*conv_eV
    return min_radius+1/D/(pol*a)

def delG0_eff(df,alpha,D,rho,A):
    eff=df["eff"]
    pol=ipyr*eff
    r=df["radius"]+distFunc(df,pol,D)
    return expFunc(df,alpha,r,rho)+solvFunc(df,pol,A,r)+dispFunc(df,r,pol,alpha)

def delG0_tot(df,alpha,D,rho,A):
    tot=df["c_factor"]
    r=df["radius"]+distFunc(df,tot,D)
    return expFunc(df,alpha,r,rho)+solvFunc(df,tot,A,r)+dispFunc(df,r,tot,alpha)

def chi_sq_red(ydata,y,dy):
    chi2 = sum((y-ydata)**2/dy**2)
    dof = len(y) - 4
    return chi2/dof

def pred_tR_eff(df,alpha,D,rho,A): 
    result = t0*unp.exp(-delG0_eff(df,alpha,D,rho,A)/R/T+logF)+t0
    return result.n

def pred_tR_tot(df,alpha,D,rho,A): 
    result = t0*unp.exp(-delG0_tot(df,alpha,D,rho,A)/R/T+logF)+t0
    return result.n

def error(estimate,true_val):
    result = (estimate-true_val)/true_val
    return result

def pred_tR_old(df): 
    result = t0*unp.exp(0.0198*df["iso"]-1.65)+t0
    return result.n

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

df[["y","dy"]] = df.apply(logs, axis=1)

a_fit0,cov0=curve_fit(delG0_eff,df,df["y"],sigma=df["dy"],
        absolute_sigma=True,bounds=([0,0,0,0], [1,1,1,1]),maxfev=5000)
a_fit1,cov1=curve_fit(delG0_tot,df,df["y"],sigma=df["dy"],
        absolute_sigma=True,bounds=([0,0,0,0], [1,1,1,1]),maxfev=5000)

alpha_eff = a_fit0[0]
D_eff = a_fit0[1]
rho_eff = a_fit0[2]
A_eff = a_fit0[3]
d_alpha_eff = np.sqrt(cov0[0][0])
d_D_eff = np.sqrt(cov0[1][1])
d_rho_eff = np.sqrt(cov0[2][2])
d_A_eff = np.sqrt(cov0[3][3])
alpha_tot = a_fit1[0]
D_tot = a_fit1[1]
rho_tot = a_fit1[2]
A_tot = a_fit1[3]
d_alpha_tot = np.sqrt(cov1[0][0])
d_D_tot = np.sqrt(cov1[1][1])
d_rho_tot = np.sqrt(cov1[2][2])
d_A_tot = np.sqrt(cov1[3][3])

chi2_eff = chi_sq_red(delG0_eff(df,alpha_eff,D_eff,rho_eff,A_eff),df["y"],df["dy"])
print(chi2_eff)
chi2_tot = chi_sq_red(delG0_tot(df,alpha_tot,D_tot,rho_tot,A_tot),df["y"],df["dy"])
print(chi2_tot)

print(["alpha","D","rho","A"])
print(a_fit0)
print(a_fit1)

df["tR_eff"]=df.apply(pred_tR_old, axis=1)
#df["tR_eff"]=df.apply(pred_tR_eff, axis=1, alpha=alpha_eff,
#        D=D_eff, rho=rho_eff, A=A_eff)
df["tR_tot"]=df.apply(pred_tR_tot, axis=1, alpha=alpha_tot,
        D=D_tot, rho=rho_tot, A=A_tot)
df["err_eff"]=error(df["tR_eff"],df["tR"])
df["err_tot"]=error(df["tR_tot"],df["tR"])
print(df[["name","radius","tR","dtR","tR_eff","err_eff","tR_tot","err_tot"]])
print('{:>36}'.format("Eff"),'{:>11}'.format("Aniso"))
print('{:30}'.format("Mean Error (ME):"),
        '{: .4f}'.format(df["err_eff"].mean()),
        '{: 10.4f}'.format(df["err_tot"].mean()))
print('{:30}'.format("Mean Absolute Error (MAE):"),
        '{: .4f}'.format(abs(df["err_eff"]).mean()),
        '{: 10.4f}'.format(abs(df["err_tot"]).mean()))
print('{:30}'.format("Standard Deviation (SD):"),
        '{: .4f}'.format(df["err_eff"].std()),
        '{: 10.4f}'.format(df["err_tot"].std()))
print('{:30}'.format("Absolute Maximum Error (AMAX):"),
        '{: .4f}'.format(abs(df["err_eff"]).max()),
        '{: 10.4f}'.format(abs(df["err_tot"]).max()))
#chi2_red_eff = chi_sq_red(df["tR_eff"],df["tR"],df["dtR"])
#print(chi2_red_eff)
#chi2_red_tot = chi_sq_red(df["tR_tot"],df["tR"],df["dtR"])
#print(chi2_red_tot)
#print(delG0_eff(df,alpha_eff,D_eff,rho_eff,A_eff))
#print(delG0_tot(df,alpha_tot,D_tot,rho_tot,A_tot))
df["r1"]=df["radius"]+distFunc(df,eff*ipyr,D_eff)
df["r2"]=df["radius"]+distFunc(df,c_factor,D_tot)
#print(df[["r1","r2"]])
#print(df["r1"]-df["r2"])
