#!/usr/bin/python3

import pandas as pd
import numpy as np
import os
import argparse
import matplotlib.pyplot as plt
import seaborn as sns

#GLOBAL CONSTANTS
names=["rshift","signal"]

#plot parameters
xmin=400
xmax=2100
ymin=0.00
ymax=2000
acs_w=160
acs_h=100
figprefix="graph_raman_"
minor_ticks=True
show_grid=False
save_plot=False
show_plot=True
acs_format=True
x_label=r'Raman shift (cm$^{-1}$)'
y_label=r'Counts'

#Functions
def fig_name(path,prefix):
    basename = os.path.basename(path)
    filename, file_extension = os.path.splitext(basename)
    return prefix + filename

#PARSER
#Create parser
parser = argparse.ArgumentParser(prog='graph_raman',\
        description='Parse data from .txt file')

#File is required
parser.add_argument("filename",
        help="the .txt data file")

#Parse arguments
args = parser.parse_args()

#Data processing
path = args.filename
df = pd.read_csv(path,sep="\t",index_col=False,header=1,names=names)

df0 = df[(df["rshift"]>=xmin) & (df["rshift"]<=xmax)]
main_x_data = df0["rshift"]
main_y_data = df0["signal"]

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
    width=10.0
    height=3.0
    s1,s2,s3,FS=14,16,18,18
    ms=10
    lw=1.25
    capsize=4
    major_tick,minor_tick=8,4

plt.rcParams['figure.figsize'] = [width, height]
plt.rc('font', size=s2)              # Set the default text font size
plt.rc('axes', titlesize=s2)         # Set the axes title font size
plt.rc('axes', labelsize=s2)         # Set the axes labels font size
plt.rc('xtick', labelsize=s1)        # Set the font size for x tick labels
plt.rc('ytick', labelsize=s1)        # Set the font size for y tick labels
plt.rc('legend', fontsize=s1)        # Set the legend font size
plt.rc('figure', titlesize=s3)       # Set the font size of the figure title

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, main_ax = plt.subplots()

main_ax.plot(main_x_data,main_y_data,color='k',lw=lw)

#annotations

#legend
#main_ax.legend(loc='lower right')

#set xlim
main_ax.set_xlim(min(main_x_data),max(main_x_data))

#set ylim
ymax = max(main_y_data)*1.1
main_ax.set_ylim(ymin,ymax)

#set labels
main_ax.set_xlabel(x_label)
main_ax.set_ylabel(y_label)

#show minor ticks
if minor_ticks:
    main_ax.minorticks_on()

#hide axis
#main_ax.get_yaxis().set_visible(False)

#hide spines
main_ax.spines[['top','right']].set_visible(False)

#tick parameters
main_ax.tick_params(which='major',length=major_tick)
main_ax.tick_params(which='minor',length=minor_tick)

#show grid
if show_grid:
    main_ax.grid(True,which='major',axis='x',color='black',linestyle='dotted',
            linewidth=0.5)

#tight layout
plt.tight_layout()

if save_plot:
    figname = fig_name(path,figprefix)
    plt.savefig(f"{figname}.svg")

if show_plot:
    plt.show()
