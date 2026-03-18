#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib.ticker as plticker
pd.options.mode.chained_assignment = None  # default='warn'

#GLOBAL CONSTANTS
DATAPATH = "./data/fullerenes_data_B3LYP.csv"
df = pd.read_csv(DATAPATH)
df0 = df[(df["pt_group"] == "Ih") & (df["natoms"] != 20)]
df1 = df[(df["pt_group"] == "D5h") | (df["pt_group"] == "D5d")]
df2 = df[(df["pt_group"] == "D2") | (df["pt_group"] == "D6d")]
df3 = df[(df["pt_group"] == "D3h") | (df["pt_group"] == "D3d")]

#plot parameters
#xmin=0.0026
#xmax=0.0173
#ymin=0
#ymax=2500
acs_w=240
acs_h=180
left_padding=0.107
figname="graph_E_N"
minor_ticks=True
show_grid=False
single_graph=False
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'1/N'
x_sec_label=r'N'
y_label=r'E/N (eV)'

#functions
def one_over(x):
    """Vectorized 1/x, treating x==0 manually"""
    x = np.array(x, float)
    near_zero = np.isclose(x, 0)
    x[near_zero] = np.inf
    x[~near_zero] = 1/x[~near_zero]
    return x

def E_N(df):
    return df["En"]/df["natoms"]

#Data processing
frames = [df0,df1,df2,df3]
for frame in frames:
    frame["E_N"] = frame.apply(E_N, axis=1)

df1_1 = df1[df1["natoms"]%30 == 0]
df1_2 = df1[df1["natoms"]%30 == 10]
df1_3 = df1[df1["natoms"]%30 == 20]

#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=4
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
plt.rcParams["mathtext.fontset"] = "cm"

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, ax = plt.subplots()

ax.scatter(1/df0["natoms"],df0["E_N"],marker="o",label=r'$I_h$',
        color=palette[0],s=ms,linewidths=lw)
ax.scatter(1/df1_1["natoms"],df1_1["E_N"],marker="o",label=r'C$_{60+30n}$',
        facecolor='none',edgecolor=palette[1],s=ms,linewidths=lw)
ax.scatter(1/df1_2["natoms"],df1_2["E_N"],marker="s",label=r'C$_{60+30n+10}$',
        facecolor='none',edgecolor=palette[2],s=ms,linewidths=lw)
ax.scatter(1/df1_3["natoms"],df1_3["E_N"],marker="v",label=r'C$_{60+30n+20}$',
        facecolor='none',edgecolor=palette[3],s=ms,linewidths=lw)
ax.scatter(1/df2["natoms"],df2["E_N"],marker="x",label=r'C$_{60+12n}$',
        color=palette[4],s=ms,linewidths=lw)
ax.scatter(1/df3["natoms"],df3["E_N"],marker="+",label=r'C$_{60+18n}$',
        color=palette[5],s=ms,linewidths=lw)

#annotations
if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, text in zip(df0["natoms"], df0["E_N"], annotations):
        if xi == 60:
            ax.annotate(text,
                    xy=(1/xi,yi), xycoords='data',
                        xytext=(0,-2.0), textcoords='offset points',
                        ha='center',va='top')

#legend
ax.legend()

#set xlim
#ax.set_xlim(xmin,xmax)

#set labels
ax.set_xlabel(x_label)
ax.set_ylabel(y_label)

#set axis
y_formatter = plticker.ScalarFormatter(useOffset=False)
ax.yaxis.set_major_formatter(y_formatter)

#set secondary axis
secax = ax.secondary_xaxis('top',functions=(one_over,one_over))
secax.set_xlabel(x_sec_label)
loc = plticker.FixedLocator([60,80,100,120,150,180,240,320])
secax.xaxis.set_major_locator(loc)

# show minor ticks
if minor_ticks:
    ax.minorticks_on()

#tick parameters
ax.tick_params(which='major',length=major_tick)
ax.tick_params(which='minor',length=minor_tick)

#show grid
if show_grid:
    ax.grid(True,which='major',axis='x',color='black',linestyle='dotted',
            linewidth=0.5)

#final layout
plt.tight_layout()
if single_graph:
    plt.subplots_adjust(left=left_padding)

if save_plot:
    plt.savefig(f"{figname}.svg")

if show_plot:
    plt.show()
