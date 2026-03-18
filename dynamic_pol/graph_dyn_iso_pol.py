#!/usr/bin/python3

import pandas as pd
import numpy as np
from scipy.interpolate import Akima1DInterpolator, PchipInterpolator
import matplotlib.pyplot as plt
import seaborn as sns
import re

#GLOBAL CONSTANTS
DATAPATH = "./data/dyn_pol_data.csv"
df = pd.read_csv(DATAPATH,comment='#')

#plot parameters
xmin=0
#xmax=82
xmin_inset=0
xmax_inset=0.95
ymin=0
#ymax=5
ymin_inset=0
#ymax_inset=
acs_w=400
acs_h=200
left_padding=0.135
figname="graph_dyn_iso_pol"
minor_ticks=True
show_grid=False
single_graph=False
show_annot=False
save_plot=False
show_plot=True
acs_format=True
x_label=r'$\nu$ [au]'
y_label=r'$\overline{\alpha}(i\nu)$ [$a_0^3$]'
#y_label=r'$\overline{\alpha}(i\omega)$ [$\AA^3$]'

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
    return (0.5*((x-y)**2+(x-z)**2+(y-z)**2))**0.5

def label_format(molecule):
    if re.search(r"^[cC]\d+-",molecule):
        na = re.search(r"^[cC](\d+)-([A-Z])(\d?[a-z]?)-?(\d+)?",molecule)
        nato = na.group(1)
        gr1 = na.group(2)
        gr2 = na.group(3)
        isomer = ""
        if na.group(4):
            isomer = "$("+str(na.group(4))+")$"
        return r"C$_{"+str(nato)+"}$-$"+str(gr1)+"_{"+str(gr2)+"}$"+isomer
    else:
        print(molecule.title())
        return molecule.title()

#Data processing
df["iso"] = df.apply(iso_pol, axis=1)
df["ani"] = df.apply(ani_pol, axis=1)

xy_dict = {}
interp_dict = {}
xmax_list = list()
ymax_list = list()
df2 = df.sort_values(by=["natoms","molecule"])
mol_list = df2["molecule"].unique()

for mol in mol_list:
    df_test = df[df["molecule"]==mol]
    x = df_test["freq"].to_numpy()
    y = df_test["iso"].to_numpy()
    natom = df_test["natoms"].unique()
    xs = np.linspace(np.min(x), np.max(x), num=10000)
#    y_interp = Akima1DInterpolator(x, y, method="akima")(xs)
    f = PchipInterpolator(x,y)
    y_interp = f(xs)
    interp_dict[mol] = [xs,y_interp]
    xy_dict[mol] = [x,y,natom[0]]
    xmax_list.append(np.max(x))
    ymax_list.append(np.max(y))


#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=5
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
plt.rc('legend', fontsize=s2)   # Set the legend font size
plt.rc('figure', titlesize=s3)  # Set the font size of the figure title
plt.rcParams["mathtext.fontset"] = "cm"

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, ax = plt.subplots()
inset = fig.add_axes([.35,.45,.48,.5])

lstyles = ['-',(0,(3,3)),(0,(3,1,1,1)),':']
div=3
cdiv=5

for i, mol in enumerate(mol_list):
    ls = lstyles[i%div]
    c = palette[i%cdiv]
    xy = interp_dict[mol]
    xy_pts = xy_dict[mol]
    label = label_format(mol)
    ax.plot(xy[0],xy[1],label=label,ls=ls,lw=lw,c=c)
    ax.scatter(xy_pts[0],xy_pts[1],marker="o",fc='none',
               edgecolor=c,s=ms,lw=lw)
    inset.plot(xy[0],xy[1],ls=ls,lw=lw,c=c)
    inset.scatter(xy_pts[0],xy_pts[1],marker="o",fc='none',
                  edgecolor=c,s=ms,lw=lw)

#annotations
#if show_annot:

#legend
lg = ax.legend(reverse=True,bbox_to_anchor=(1.02,1),
               loc='upper left',borderaxespad=0.)

#set xlim
xmax=np.max(xmax_list)
xlim=[xmin,xmax]
ax.set_xlim(xlim)
xlim_inset=[xmin_inset,xmax_inset]
inset.set_xlim(xlim_inset)

#set ylim
ymax=np.max(ymax_list)/150
ymax_inset=np.max(ymax_list)*1.1
ylim=[ymin,ymax]
ax.set_ylim(ylim)
ylim_inset=[ymin_inset,ymax_inset]
inset.set_ylim(ylim_inset)

#set labels
ax.set_xlabel(x_label,fontsize=FS)
ax.set_ylabel(y_label,fontsize=FS)

#show minor ticks
if minor_ticks:
    ax.minorticks_on()
    inset.minorticks_on()

#tick parameters
ax.tick_params(which='major',length=major_tick)
ax.tick_params(which='minor',length=minor_tick)
inset.tick_params(which='major',length=major_tick)
inset.tick_params(which='minor',length=minor_tick)

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
