#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
import matplotlib.pyplot as plt
import seaborn as sns

# GLOBAL CONSTANTS
DATAPATH0 = "./data/lab_test.csv"
df0 = pd.read_csv(DATAPATH0)
conv_eV = 96.4869 #kJ mol-1
ie_pyr = 7.16072
R = 8.31446261815324e-03
T = 295.15
min_radius=4.38
vcut=0.23
ipyr = 199.0859
apyr = 177.9258
t0 = 3.127
flowrate = 3.06
vm = t0*flowrate*1000
dc = 10
col_L = 250
porosity = vm/(math.pi*(dc/2)**2*col_L)
F = (1-porosity)/porosity
logF = math.log(F)
slope=0.0249

#plot parameters
xmin=75.96
xmax=198.93
ymin=1.75
ymax=5.15
acs_w=240
acs_h=134
left_padding=0.110#0.138
figname="graph_abpol_exp"
minor_ticks=True
show_grid=False
single_graph=True
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'$\alpha^B_\mathrm{eff}$ ($\AA^3$)'
#y_label=(r'$\left(\dfrac{ba}{T}\right)\/\overline{\alpha}^A$'
#        r'$\alpha^B_\mathrm{eff} + \log F$')
y_label=r'$\log k$'

#functions
def ab(df):
    ie=df["ie"]
    a=3/2*(ie*ie_pyr)/(ie+ie_pyr)*conv_eV
    r=df["radius"]+min_radius
    b=1/(R*r**6)
    return a*b#/T

def rmin(df):
    ie=df["ie"]
    a=3/2*(ie*ie_pyr)/(ie+ie_pyr)*conv_eV
    val=7.92e-04#2.49e-02/29.5
    x=(a/R/T/val)**(1/6) - df["radius"]
    return x

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

def y_th(df):
    ab=df["ab"]
    pyr=bohr_to_ang(ipyr)
    pol=df["eff"]
    return ab*pyr*pol/T+logF

#Data processing
df0["ab"] = df0.apply(ab, axis=1)
df0["rmin"] = df0.apply(rmin, axis=1)
iso = df0.apply(iso_pol, axis=1)
ani = df0.apply(ani_pol, axis=1)
df0["eff"] = bohr_to_ang(iso - ani/6)
df0["y"] = df0.apply(y_th, axis=1) 
df0_1 = df0[df0["ab"] > vcut]
df0_2 = df0[df0["ab"] <= vcut]

#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=6
    lw=0.50
    capsize=2
    major_tick,minor_tick=4,2
else:
    width=7.2
    height=7.2
    s1,s2,s3,FS=14,16,18,18
    ms=10
    lw=1.25
    capsize=4
    major_tick,minor_tick=8,4

plt.rcParams['figure.figsize'] = [width, height]
plt.rc('font', size=s2)         # Set the default text font size
plt.rc('axes', titlesize=s2)    # Set the axes title font size
plt.rc('axes', labelsize=s2)    # Set the axes labels font size
plt.rc('xtick', labelsize=s1)   # Set the font size for x tick labels
plt.rc('ytick', labelsize=s1)   # Set the font size for y tick labels
plt.rc('legend', fontsize=s1)   # Set the legend font size
plt.rc('figure', titlesize=s3)  # Set the font size of the figure title

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, ax = plt.subplots()

#ax.scatter(df0["natoms"],df0["ab"],marker="o",label=r'Expt.',
#        color=palette[0],s=ms,linewidths=lw)
#ax.axhline(y=df0["ab"][0], lw=lw, color='k', ls=(0,(5,8)), alpha=0.5)
#ax.axhspan(df0["ab"][0]*0.9, df0["ab"][0]*1.1,
#        facecolor=palette[2], alpha=0.2)
ax.scatter(df0_1["eff"],df0_1["y"],marker="o",label=r'C$_{60}$-like radii',
        color=palette[0],s=ms,linewidths=lw)
ax.scatter(df0_2["eff"],df0_2["y"],marker="s",label=r'Larger radii',
        facecolor='none',edgecolor=palette[1],s=ms,linewidths=lw)
ax.axline(xy1=(0,logF), slope=0.0249, ls='dotted', c=palette[0], lw=lw)

#annotations
x_eq = 0.02
y_eq = 0.99

if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, abi, text in zip(df0["eff"], df0["y"], df0["ab"], annotations):
        if abi > vcut:
            y = 4
        else:
            y = -7.5
        ax.annotate(text,
                xy=(xi,yi), xycoords='data',
                xytext=(4,y), textcoords='offset points',ha='right')

ax.text(x_eq, y_eq, f'$y = $'+f'{slope:.2e}'+f'$x {logF:+.2f}$',
        horizontalalignment='left',
        verticalalignment='top',
        fontsize=s2,
        color=palette[0],
        transform=ax.transAxes)

#legend
ax.legend(loc='lower right')

#set xlim
ax.set_xlim(xmin,xmax)

#set ylim
ax.set_ylim(ymin,ymax)

#set labels
ax.set_xlabel(x_label)
ax.set_ylabel(y_label)

#show minor ticks
if minor_ticks:
    ax.minorticks_on()

#tick parameters
ax.tick_params(which='major',length=major_tick)
ax.tick_params(which='minor',length=minor_tick)

#spine
ax.spines[['top','right']].set_visible(False)

#show grid
if show_grid:
    ax.grid(True,which='major',axis='x',color='black',linestyle='dotted',
            linewidth=0.5)

#tight layout
plt.tight_layout()
if single_graph:
    plt.subplots_adjust(left=left_padding)

if save_plot:
    plt.savefig(f"{figname}.svg")

if show_plot:
    plt.show()
