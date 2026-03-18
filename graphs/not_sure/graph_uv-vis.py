#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.signal import find_peaks

#GLOBAL CONSTANTS
scale=1
DATAPATH0 = "./data/C130_UV-vis.csv"
df0 = pd.read_csv(DATAPATH0)

#plot parameters
xmin=400
xmax=850
#ymin=0.00
#ymax=3.23
width=240/72*scale
height=100/72*scale
msize=5*scale
lw=0.5*scale
prominence=0.1
figname="graph_uv-vis"
minor_ticks=True
show_grid=False
save_plot=False
show_plot=True
x_label=r'Wavelength (nm)'
y_label=r'Absorbance (a.u.)'

#Data processing
main_x_data = df0["wavelength"]
main_y_data = df0["absorbance"]

#Find peaks
peaks , _ = find_peaks(main_y_data,prominence=prominence)

#set font size
plt.rcParams['figure.figsize'] = [width, height]
plt.rc('font', size=6*scale)         # Set the default text font size
plt.rc('axes', titlesize=6*scale)    # Set the axes title font size
plt.rc('axes', labelsize=6*scale)    # Set the axes labels font size
plt.rc('xtick', labelsize=5*scale)   # Set the font size for x tick labels
plt.rc('ytick', labelsize=5*scale)   # Set the font size for y tick labels
plt.rc('legend', fontsize=5*scale)   # Set the legend font size
plt.rc('figure', titlesize=7*scale)  # Set the font size of the figure title
FS=7*scale

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, main_ax = plt.subplots()

main_ax.plot(main_x_data,main_y_data,color='k',lw=lw)

#annotations
abs_peaks = main_x_data[peaks]
for index, txt in enumerate(peaks):
    peak_label = round(main_x_data[peaks[index]])
    main_ax.annotate(peak_label,
            xy=(main_x_data[peaks[index]],main_y_data[peaks[index]]),
            xycoords='data',fontsize=FS,
            xytext=(0,4),textcoords='offset points',
            ha='center')

#legend
#main_ax.legend(loc='lower right')

#set xlim
main_ax.set_xlim(xmin,xmax)

#set ylim
#ymax = max(main_y_data)
#main_ax.set_ylim(ymin,ymax)

#set labels
main_ax.set_xlabel(x_label)
main_ax.set_ylabel(y_label)

#show minor ticks
if minor_ticks:
    main_ax.minorticks_on()

#hide axis
main_ax.get_yaxis().set_visible(False)

#hide spines
main_ax.spines[['top','left','right']].set_visible(False)

#tick parameters
main_ax.tick_params(which='major',length=4*scale)
main_ax.tick_params(which='minor',length=2*scale)

#show grid
if show_grid:
    main_ax.grid(True,which='major',axis='x',color='black',linestyle='dotted',
            linewidth=0.5)

#increase figure size N times
plt.tight_layout()

if save_plot:
    plt.savefig(f"{figname}.svg")

if show_plot:
    plt.show()
