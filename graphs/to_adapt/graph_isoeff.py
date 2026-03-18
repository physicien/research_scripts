#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

#GLOBAL CONSTANTS
DATAPATH0 = "./data/Ih.csv"
DATAPATH1 = "./data/H2.csv"
DATAPATH2 = "./data/A1xA1.csv"
DATAPATH3 = "./data/A2.csv"
df0 = pd.read_csv(DATAPATH0)
df1 = pd.read_csv(DATAPATH1)
df2 = pd.read_csv(DATAPATH2)
df3 = pd.read_csv(DATAPATH3)

#plot parameters
#xmin=55
#xmax=315
ymin=-25
#ymax=2500
acs_w=240
acs_h=180
left_padding=0.13
figname="graph_isoeff"
minor_ticks=True
show_grid=False
single_graph=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'N'
y_label=r'Polarizabilities ($\AA^3$)'

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

#Data processing
frames = [df0,df1,df2,df3]
df = pd.concat(frames)

iso = df.apply(iso_pol, axis=1)
ani = df.apply(ani_pol, axis=1)
eff = iso - ani/6

#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=5
    lw=0.75
    major_tick,minor_tick=4,2
else:
    width=7.2
    height=7.2
    s1,s2,s3,FS=14,16,18,18
    ms=10
    lw=1.25
    major_tick,minor_tick=8,4

plt.rcParams['figure.figsize'] = [width, height]
plt.rc('font', size=s2)         # Set the default text font size
plt.rc('axes', titlesize=s3)    # Set the axes title font size
plt.rc('axes', labelsize=s3)    # Set the axes labels font size
plt.rc('xtick', labelsize=s1)   # Set the font size for x tick labels
plt.rc('ytick', labelsize=s1)   # Set the font size for y tick labels
plt.rc('legend', fontsize=s1)   # Set the legend font size
plt.rc('figure', titlesize=s3)  # Set the font size of the figure title

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, ax = plt.subplots()

ax.scatter(df["natoms"],bohr_to_ang(iso),marker="o",s=ms,linewidths=lw,
        label=r'$\overline{\alpha}$',facecolor="none",edgecolor=palette[0])
ax.scatter(df["natoms"],bohr_to_ang(eff),marker="+",s=ms,linewidth=lw,
        label=r'$\alpha_{\mathrm{eff}}$',color=palette[1])

#legend
ax.legend()

#set ylim
ax.set_ylim(bottom=ymin)

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
