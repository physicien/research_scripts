#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
import matplotlib.pyplot as plt
import seaborn as sns

#GLOBAL CONSTANTS
DATAPATH = "./data/lab_radius.csv"
df = pd.read_csv(DATAPATH,comment='#')
t0 = 3.127
ipyrb = 199.0859
apyrb = 177.9258
ie_pyr = 7.16072
flowrate = 3.06
vm = t0*flowrate*1000
dc = 10
col_L = 250
porosity = vm/(math.pi*(dc/2)**2*col_L)
F = (1-porosity)/porosity
logF = math.log(F)
conv_eV = 96.4869 #kJ mol-1
R = 8.31446261815324e-03
T = 295.15
nsig=1
min_radius=3

alpha_eff=1.8364e-01
D_eff=1.9340e-07
rho_eff=4.9747
A_eff=7.2444e-02

alpha_tot=2.6911e-01
D_tot=2.2857e-07
rho_tot=4.9419
A_tot=5.9167e-02

#Plot parameters
xmin=7.5
xmax=11.9
ymin=-8.5#-7.0
ymax=6.2
acs_w=240
acs_h=280
left_padding=0.113
figname="plot_potential"
minor_ticks=True
show_grid=False
show_legend=True
single_graph=True
save_plot=False
show_plot=True
show_eff=False
acs_format=True
x_label=r'r ($\AA$)'
y_label=r'$\Delta G^0$ (kJ mol$^{-1}$)'

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

def time_log(df):
    tR=df["tR"]
    return math.log((tR-t0)/t0) 

def logs(df):
    result = R*T*(logF-time_log(df))
    return result

def dampFunc(r,alpha):
    x=alpha*r
    return 1-np.exp(-x)*(1+x+(x**2)/2+(x**3)/6+(x**4)/24+(x**5)/120+(x**6)/720)

def expFunc(df,alpha,r,rho):
    rho_mol = rho + df["radius"]
    return 1*np.exp(-1/alpha*(r-rho_mol))

def solvFunc(df,pol,A,r):
    r0 = df["radius"] + min_radius
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

def delG0_eff(df,alpha,r,rho,A):
    eff=df["eff"]
    pol=ipyr*eff
    return expFunc(df,alpha,r,rho)+solvFunc(df,pol,A,r)+dispFunc(df,r,pol,alpha)

def delG0_tot(df,alpha,r,rho,A):
    tot=df["c_factor"]
    return expFunc(df,alpha,r,rho)+solvFunc(df,tot,A,r)+dispFunc(df,r,tot,alpha)

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
df["r_eff"] = df["radius"]+distFunc(df,ipyr*eff,D_eff)
df["r_tot"] = df["radius"]+distFunc(df,c_factor,D_tot)
df["delG0_eff"] = delG0_eff(df,alpha_eff,df["r_eff"],rho_eff,A_eff)
df["delG0_tot"] = delG0_tot(df,alpha_tot,df["r_tot"],rho_tot,A_tot)

#Set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=3
    lw=0.60
    mew=0.50
    major_tick,minor_tick=4,2
else:
    width=7.2
    height=7.5
    s1,s2,s3,FS=14,16,18,18
    ms=6
    lw=1.00
    mew=1.00
    major_tick,minor_tick=8,4

plt.rcParams['figure.figsize'] = [width, height]
plt.rc('font', size=s2)
plt.rc('axes', titlesize=s3)
plt.rc('axes', labelsize=s3)
plt.rc('xtick', labelsize=s1)
plt.rc('ytick', labelsize=s1)
plt.rc('legend', fontsize=s2)

#Prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, ax = plt.subplots()

if show_legend:
    natoms = df["natoms"].values.tolist()
    group = df["pt_group"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$-"+gr[0]+"$_{"+gr[1:]+"}$"
            for nato, gr in zip(natoms,group)]

D=np.arange(0.1,15.0,0.002)
div=3
cdiv=5
minpot = []
for i in df.index:
    lstyles = ['-',(0,(3,3)),(0,(3,1,1,1)),':']
    ls = lstyles[i%div]
    c=palette[i%cdiv]
    if show_legend:
        anno=annotations[i]
    else:
        anno=''
    if show_eff:
        ax.plot(D,delG0_eff(df.iloc[i],alpha_eff,D,rho_eff,A_eff),
                ls=ls, lw=lw, c=c)
        ax.plot(df["r_eff"].iloc[i],df["delG0_eff"].iloc[i],marker="o",
                ms=ms, mew=mew, mfc='white', c=c, ls=ls, lw=lw, label=anno)
        minpot.append(delG0_eff(df.iloc[i],alpha_eff,D,rho_eff,A_eff).min())
    else:
        ax.plot(D,delG0_tot(df.iloc[i],alpha_tot,D,rho_tot,A_tot),
                ls=ls, lw=lw, c=c)
        ax.plot(df["r_tot"].iloc[i],df["delG0_tot"].iloc[i],marker="o",
                ms=ms, mew=mew, mfc='white', c=c, ls=ls, lw=lw, label=anno)
        minpot.append(delG0_tot(df.iloc[i],alpha_tot,D,rho_tot,A_tot).min())
#        ax.plot(D,solvFunc(df.iloc[i],df["c_factor"].iloc[i],A_tot,D),
#                ls=ls, lw=lw, c=palette[i%cdiv])
df["min_pot"] = minpot

#ax.plot(D,delG0_tot(df.iloc[0],alpha_tot,D,rho_tot,A_tot),linestyle='-',color=palette[0])
#ax.plot(D,dampFunc(D,alpha_eff),linestyle='-',color=palette[0])

#legend
if show_legend:
    ax.legend(handlelength=4,loc='lower right')

#Set xlim and ylim
ax.set_xlim(xmin,xmax)
ax.set_ylim(ymin,ymax)

#Set labels
ax.set_xlabel(x_label,fontsize=FS)
ax.set_ylabel(y_label,fontsize=FS)

#Show minot ticks
if minor_ticks:
    ax.minorticks_on()

#Tick parameters
ax.tick_params(which='major',length=major_tick)
ax.tick_params(which='minor',length=minor_tick)

#Spine
ax.spines[['top','right']].set_visible(False)

#Show grid
if show_grid:
    ax.grid(True,which='major',axis='x',color='black',linestyle='dotted'
            ,linewidth=0.5)

#final layout
plt.tight_layout()
if single_graph:
    plt.subplots_adjust(left=left_padding)

if save_plot:
    plt.savefig(f"{figname}.svg")

if show_plot:
    if show_eff:
        print(df[["name","r_eff","delG0_eff","min_pot"]])
    else:
        print(df[["name","r_tot","delG0_tot","min_pot"]])
    plt.show()
