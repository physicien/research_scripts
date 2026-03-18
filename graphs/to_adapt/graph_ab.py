#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

# GLOBAL CONSTANTS
DATAPATH0 = "./data/Ih.csv"
DATAPATH1 = "./data/H2.csv"
DATAPATH2 = "./data/A1xA1.csv"
DATAPATH3 = "./data/A2.csv"
df0 = pd.read_csv(DATAPATH0)
df1 = pd.read_csv(DATAPATH1)
df2 = pd.read_csv(DATAPATH2)
df3 = pd.read_csv(DATAPATH3)
conv_eV = 96.4869 #kJ mol-1
ie_pyr = 7.16072
R = 8.31446261815324e-03
T = 295.15
min_radius=3

# plot parameters
#xmin=55
#xmax=315
ymin=0
ymax=1.19#0.005
acs_w=240
acs_h=180
left_padding=0.112#0.138
figname="graph_ab"
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

# Data processing
df0["ab"] = df0.apply(ab, axis=1)
df1["ab"] = df1.apply(ab, axis=1)
df2["ab"] = df2.apply(ab, axis=1)
df3["ab"] = df3.apply(ab, axis=1)
df1_1 = df1[df1["natoms"]%30 == 0]
df1_2 = df1[df1["natoms"]%30 == 10]
df1_3 = df1[df1["natoms"]%30 == 20]

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

# prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, ax = plt.subplots()

ax.scatter(df0["natoms"],df0["ab"],marker="o",label=r'$I_h$',
        color=palette[0],s=ms,lw=lw)
ax.scatter(df1_1["natoms"],df1_1["ab"],marker="o",label=r'C$_{60+30n}$',
        fc='none',edgecolor=palette[1],s=ms,lw=lw)
ax.scatter(df1_2["natoms"],df1_2["ab"],marker="s",label=r'C$_{60+30n+10}$',
        fc='none',edgecolor=palette[2],s=ms,lw=lw)
ax.scatter(df1_3["natoms"],df1_3["ab"],marker="v",label=r'C$_{60+30n+20}$',
        fc='none',edgecolor=palette[3],s=ms,lw=lw)
ax.scatter(df2["natoms"],df2["ab"],marker="x",label=r'C$_{60+12n}$',
        color=palette[4],s=ms,lw=lw)
ax.scatter(df3["natoms"],df3["ab"],marker="+",label=r'C$_{60+18n}$',
        color=palette[5],s=ms,lw=lw)

#annotations
if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, text in zip(df0["natoms"], df0["ab"], annotations):
        if xi == 60:
            ax.annotate(text,
                    xy=(xi,yi), xycoords='data',
                    xytext=(0,2.5), textcoords='offset points',
                        ha='right',va='bottom')

# legend
ax.legend()

#set ylim
ax.set_ylim(ymin,ymax)

# set labels
ax.set_xlabel(x_label)
ax.set_ylabel(y_label)

# show minor ticks
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
