#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as m_patches
import seaborn as sns
pd.options.mode.chained_assignment = None  # default='warn'

# GLOBAL CONSTANTS
DATAPATH = "./data/fullerenes_data_B3LYP.csv"
df = pd.read_csv(DATAPATH)
df0 = df[df["pt_group"] == "Ih"]
df1 = df[(df["pt_group"] == "D5h") | (df["pt_group"] == "D5d")]
df2 = df[(df["pt_group"] == "D2") | (df["pt_group"] == "D6d")]
df3 = df[(df["pt_group"] == "D3h") | (df["pt_group"] == "D3d")]

# plot parameters
#xmin=55
#xmax=315
#ymin=0
#ymax=2500
acs_w=240
acs_h=220
left_padding=0.107
figname="graph_HL"
minor_ticks=True
show_grid=False
single_graph=False
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'N'
y_label=r'Energies (eV)'

#functions

# Data processing
df1_1 = df1[df1["natoms"]%30 == 0]
df1_2 = df1[df1["natoms"]%30 == 10]
df1_3 = df1[df1["natoms"]%30 == 20]

frames = [df0,df1_1,df1_2,df1_3,df2,df3]

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
plt.rcParams["mathtext.fontset"] = "cm"

#prepare plot
n_cols = 3
palette = sns.color_palette("colorblind")
colors = [palette[i] for i in range(6)]
markers = ["D","o","s","v","X","P"]
labels = [r'$I_h$',r'C$_{60+30n}$',r'C$_{60+30n+10}$',r'C$_{60+30n+20}$',
          r'C$_{60+12n}$',r'C$_{60+18n}$']
sns.set_palette(palette)
fig, ax = plt.subplots()

patches_col0 = [m_patches.Patch(color='w',label=r'')]
patches_col_homo = [m_patches.Patch(color='none',label=r'HOMO')]
patches_col_lumo = [m_patches.Patch(color='none',label=r'LUMO')]

for i,(frame,color,marker,label) in enumerate(zip(frames,colors
                                                  ,markers,labels)):
    phomo = ax.scatter(frame["natoms"],frame["homo"],marker=marker,
                       label='i',facecolor='none',edgecolor=color,
                       s=ms,lw=lw)
    plumo = ax.scatter(frame["natoms"],frame["lumo"],marker=marker,
                       label='i',facecolor=color,s=ms,lw=lw)

    patches_col0.append(m_patches.Patch(color='none',label=label))
    patches_col_homo.append(phomo)
    patches_col_lumo.append(plumo)

patches = list()
patches.extend(patches_col0)
patches.extend(patches_col_homo)
patches.extend(patches_col_lumo)

#annotations
if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, zi, text in zip(df0["natoms"], df0["homo"], df0["lumo"]
                            , annotations):
        if xi == 60:
            ax.annotate(text,
                    xy=(xi,yi), xycoords='data',
                    xytext=(-2,3), textcoords='offset points',ha='right')
            ax.annotate(text,
                    xy=(xi,zi), xycoords='data',
                    xytext=(-2,-6), textcoords='offset points',ha='right')

#legend
lg = ax.legend(ncol=n_cols,handles=patches,handletextpad=-2.0,markerfirst=True)

for i, text in enumerate(lg.get_texts()):
    if i < 7:
        pass
    elif i == 7:
        text.set_color('black')
    elif 8 <= i < 14:
        text.set_color('none')
    elif i == 14:
        text.set_color('black')
    else:
        text.set_color('none')

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
