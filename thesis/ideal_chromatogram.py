#!/usr/bin/python3

import numpy as np
import os
import matplotlib.pyplot as plt
import seaborn as sns

#GLOBAL CONSTANTS
A0 = 1.5
x00 = 4
sig0 = 0.1
A1 = 6.0
x01 = 10
sig1 = 0.25
A2 = 6.0
x02 = 15
sig2 = 0.4

#plot parameters
xmin=0
xmax=20
ymin=0.00
ymax=10
xfmin=25
xfmax=60
acs_w=420
acs_h=150
figname="ideal_chromatogram"
minor_ticks=False
show_grid=False
show_peak=False
save_plot=True
show_plot=True
acs_format=True
x_label=r'Temps'
y_label=r'Réponse du'+'\n'+'détecteur'
ls=(0, (5, 5))

#Functions
def gauss(x, H, A, x0, sigma):
    return H + A*np.exp(-(x-x0)**2/(2*sigma**2))

def chromato(x):
    return gauss(x,0,A0,x00,sig0)+gauss(x,0,A1,x01,sig1)+gauss(x,0,A2,x02,sig2)

#Data processing
x_data = np.arange(xmin, xmax, 0.01)


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
plt.rc('font', size=s3)              # Set the default text font size
plt.rc('axes', titlesize=s3)         # Set the axes title font size
plt.rc('axes', labelsize=s3)         # Set the axes labels font size
plt.rc('xtick', labelsize=s2)        # Set the font size for x tick labels
plt.rc('ytick', labelsize=s2)        # Set the font size for y tick labels
plt.rc('legend', fontsize=s1)        # Set the legend font size
plt.rc('figure', titlesize=s3)       # Set the font size of the figure title

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, main_ax = plt.subplots()

main_ax.plot(x_data,chromato(x_data),color='k',lw=lw*1.5)
main_ax.vlines(x00,0,A0+0.8,colors='k',lw=lw,ls=ls)
main_ax.vlines(x01,0,A1+0.8,colors='k',lw=lw,ls=ls)
main_ax.vlines(x02,0,A2+2.4,colors='k',lw=lw,ls=ls)

main_ax.hlines(A0+0.4,0,x00,colors='k',lw=lw)
main_ax.hlines(A1+0.4,0,x01,colors='k',lw=lw)
main_ax.hlines(A2+2.0,0,x02,colors='k',lw=lw)

main_ax.hlines(0.5,x01-2*sig1,x01+2*sig1,colors='k',lw=lw)
main_ax.hlines(0.5,x02-2*sig2,x02+2*sig2,colors='k',lw=lw)

#annotations
if show_peak:
    main_ax.annotate(f'{x0:.2f}',
            xy=(x0,(H+A)*1.05),
            xycoords='data',fontsize=FS,
            xytext=(0,4),textcoords='offset points',
            ha='center')

#legend
#main_ax.legend(loc='lower right')

#set xlim
main_ax.set_xlim(xmin,xmax)

#set ylim
#ymax = max(chromato(x_data))*1.1
main_ax.set_ylim(ymin=ymin,ymax=ymax)

#set labels
main_ax.set_xlabel(x_label)
main_ax.set_ylabel(y_label, rotation=0)
main_ax.xaxis.set_label_coords(1.03, -.05)
main_ax.yaxis.set_label_coords(0, 1.05)
main_ax.plot(1, 0, ">k", transform=main_ax.get_yaxis_transform(),
             clip_on=False)
main_ax.plot(0, 1, "^k", transform=main_ax.get_xaxis_transform(),
             clip_on=False)

#show minor ticks
if minor_ticks:
    main_ax.minorticks_on()

#hide axis
#main_ax.get_yaxis().set_visible(False)

#hide spines
main_ax.spines[['top','right']].set_visible(False)

#tick parameters
main_ax.tick_params(which='both',bottom=False,labelbottom=False,
                    left=False,labelleft=False)

#show grid
if show_grid:
    main_ax.grid(True,which='major',axis='x',color='black',linestyle='dotted',
            linewidth=0.5)

#tight layout
plt.tight_layout()
plt.subplots_adjust(right=0.94)

if save_plot:
    plt.savefig(f"{figname}.svg")

if show_plot:
    plt.show()
