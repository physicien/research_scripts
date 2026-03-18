#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# GLOBAL CONSTANTS
DATAPATH0 = "./data/lab_test.csv"
df0 = pd.read_csv(DATAPATH0)
conv_eV = 96.4869 #kJ mol-1
ie_pyr = 7.16072
R = 8.31446261815324e-03
T = 295.15
min_radius=3
vcut=0.7

#plot parameters
#xmin=55
#xmax=315
ymin=0
ymax=1.0#0.005
acs_w=240
acs_h=180
left_padding=0.112#0.138
figname="graph_ab_exp"
minor_ticks=True
show_grid=False
single_graph=True
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'N'
y_label=r'$ba$ ($\AA^{-6}$ K)'#r'$ba/T$ ($\AA^{-6}$)'

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

#Data processing
df0["ab"] = df0.apply(ab, axis=1)
df0["rmin"] = df0.apply(rmin, axis=1)
df0_1 = df0[df0["ab"] > vcut]
df0_2 = df0[df0["ab"] <= vcut]
#moy = df0_1["ab"].mean()
#print((moy-df0["ab"])/moy)
#print(((moy-df0["ab"])/moy).abs().mean())
#print(((moy-df0_1["ab"])/moy).abs().mean())
#print((df0["ab"][0]-df0["ab"])/df0["ab"][0])
#print(df0_1["rmin"].mean())
#print(df0_1[["name","rmin"]])
#print(df0_1["rmin"]+df0_1["radius"])

#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=8
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
ax.scatter(df0_1["natoms"],df0_1["ab"],marker="o",label=r'C$_{60}$-like radii',
        color=palette[0],s=ms,linewidths=lw)
ax.scatter(df0_2["natoms"],df0_2["ab"],marker="s",label=r'Larger radii',
        facecolor='none',edgecolor=palette[1],s=ms,linewidths=lw)

#annotations
if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, text in zip(df0["natoms"], df0["ab"], annotations):
        if yi > vcut:
            y = 4
        else:
            y = -7.5
        ax.annotate(text,
                xy=(xi,yi), xycoords='data',
                xytext=(4,y), textcoords='offset points',ha='right')

#legend
ax.legend(loc='lower right')

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
