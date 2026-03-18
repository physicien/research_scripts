#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.optimize import curve_fit
from scipy.signal import find_peaks

#GLOBAL CONSTANTS
scale=1
headers = ["time","potential"]
DATAPATH0 = "./data/C130_HPLC.txt"
DATAPATH1 = "./data/fig2_c130_left.csv"
DATAPATH2 = "./data/fig2_c130_right.csv"
df0 = pd.read_table(DATAPATH0,names=headers,skiprows=7)
df1 = pd.read_csv(DATAPATH1)
df2 = pd.read_csv(DATAPATH2)

#plot parameters
xmin=20
xmax=65
#ymin=0.00
#ymax=3.23
xmin_inset=400
xmax_inset=850
width=240/72*scale
height=125/72*scale
msize=5*scale
lw=0.5*scale
prominence1=0.04
prominence2=0.03
figname="graph_before_after"
minor_ticks=True
show_grid=False
save_plot=False
show_plot=True
x_label=r'Time (min)'
y_label=r'Potential (mV)'
x_label_inset=r'Wavelength (nm)'
y_label_inset=r'Absorbance (a.u.)'

#Functions
def gauss(x, H, A, x0, sigma):
    return H + A*np.exp(-(x-x0)**2/(2*sigma**2))

def gauss_fit(x,y):
    mean = sum(x*y)/sum(y)
    sigma = np.sqrt(sum(y*(x-mean)**2)/sum(y))
    popt, pcov = curve_fit(gauss, x, y, p0=[min(y), max(y), mean, sigma])
    return popt

#Data processing
main_x_data = df0["time"]
main_y_data = df0["potential"]

H, A, x0, sigma = gauss_fit(main_x_data,main_y_data)

before_x_data = df1["wavelength"]
before_y_data = df1["absorbance"]

after_x_data = df2["wavelength"]
after_y_data = df2["absorbance"]

#Find peaks
peaks_before , _ = find_peaks(before_y_data,prominence=prominence1)
peaks_after , _ = find_peaks(after_y_data,prominence=prominence2)

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

before_inset_ax = fig.add_axes([.20,.72,.32,0.2])
before_inset_ax.plot(before_x_data,before_y_data,color='k',lw=lw)
after_inset_ax = fig.add_axes([.675,.72,.32,0.2])
after_inset_ax.plot(after_x_data,after_y_data,color='k',lw=lw)


#annotations
main_ax.annotate(f'{x0:.1f}',
        xy=(x0,(H+A)*1.10),
        xycoords='data',fontsize=FS,
        xytext=(0,4),textcoords='offset points',
        ha='center')

abs_peaks_before = before_x_data[peaks_before]
for index, txt in enumerate(peaks_before):
    peak_label = round(before_x_data[peaks_before[index]])
    if 700 > peak_label > 550:
        before_inset_ax.annotate(peak_label,
                xy=(before_x_data[peaks_before[index]],
                    before_y_data[peaks_before[index]]),
                xycoords='data',fontsize=5*scale,
                xytext=(0,4),textcoords='offset points',
                ha='center')

abs_peaks_after = after_x_data[peaks_after]
for index, txt in enumerate(peaks_after):
    peak_label = round(after_x_data[peaks_after[index]])
    if 700 > peak_label > 550:
        after_inset_ax.annotate(peak_label,
                xy=(after_x_data[peaks_after[index]],
                    after_y_data[peaks_after[index]]),
                xycoords='data',fontsize=5*scale,
                xytext=(0,4),textcoords='offset points',
                ha='center')

#legend
#main_ax.legend(loc='lower right')

#set xlim
main_ax.set_xlim(xmin,xmax)
before_inset_ax.set_xlim(xmin_inset,xmax_inset)
after_inset_ax.set_xlim(xmin_inset,xmax_inset)

#set ylim
ymax = max(main_y_data)*1.5
main_ax.set_ylim(ymax=ymax)

#set labels
main_ax.set_xlabel(x_label)
main_ax.set_ylabel(y_label)
before_inset_ax.set_xlabel(x_label_inset,size=5*scale)
after_inset_ax.set_xlabel(x_label_inset,size=5*scale)

#show minor ticks
if minor_ticks:
    main_ax.minorticks_on()

#hide axis
main_ax.get_yaxis().set_visible(False)
before_inset_ax.get_yaxis().set_visible(False)
after_inset_ax.get_yaxis().set_visible(False)

#hide spines
main_ax.spines[['top','left','right']].set_visible(False)
before_inset_ax.spines[['top','left','right']].set_visible(False)
after_inset_ax.spines[['top','left','right']].set_visible(False)

#tick parameters
main_ax.tick_params(which='major',length=4*scale)
main_ax.tick_params(which='minor',length=2*scale)
before_inset_ax.tick_params(which='major',length=2*scale)
after_inset_ax.tick_params(which='major',length=2*scale)

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
