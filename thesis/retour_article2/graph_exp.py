#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.optimize import curve_fit

#GLOBAL CONSTANTS
DATAPATH = "./data/lab_test.csv"
df = pd.read_csv(DATAPATH)
t0 = 3.127
dt0 = 0.195
ipyr = 199.0859
apyr = 177.9258
nsig=1

# plot parameters
#xmin=75
#xmax=315
#ymin=-0.75
#ymax=2500
acs_w=400
acs_h=200
left_padding=0.08
figname="graph_exp"
minor_ticks=True
show_grid=False
single_graph=True
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'$\alpha$ ($\AA^3$)'      #CHANGE HERE
#x_label=r'$\overline{\alpha}$ ($\AA^3$)'
#x_label=r'$\alpha_\mathrm{eff}$ ($\AA^3$)'
#x_label=r'$\alpha^{AB}$ ($\AA^6$)'
#y_label=r'$\log\left(\frac{t_R-t_0}{t_0}\right)$'
y_label=r'$\log k$'

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

def log(df):
    tR=df["tR"]
    return math.log((tR-t0)/t0) 

def dlog(df):
    tR=df["tR"]
    dtR=nsig*df["dtR"]
    return math.sqrt((1/(tR-t0))**2*dtR**2 + (tR/(tR*t0-t0**2))**2*dt0**2)

def linearFunc(x,intercept,slope):
    y = intercept + slope * x
    return y

#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=2
    lw=0.75
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

#Data processing
iso = df.apply(iso_pol, axis=1)
ani = df.apply(ani_pol, axis=1)
log_data = df.apply(log, axis=1) 
dlog_data = df.apply(dlog, axis=1)
eff = iso - ani/6
c_factor = iso*ipyr - (iso*apyr + ani*ipyr - ani*apyr)/6 
n_list = df["natoms"]

x_data = bohr_to_ang(iso) #CHANGE HERE
#x_data = bohr_to_ang(eff)
#x_data = bohr_to_ang(c_factor)

a_fit,cov=curve_fit(linearFunc,x_data,log_data,sigma=dlog_data,
        absolute_sigma=True)
inter = a_fit[0]
slope = a_fit[1]
d_inter = np.sqrt(cov[0][0])
d_slope = np.sqrt(cov[1][1])

chi2 = sum((log_data-linearFunc(x_data,inter,slope))**2/dlog_data**2)
dof = len(log_data) - 2
chi2_red = chi2/dof

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, ax = plt.subplots()

ax.errorbar(x_data,log_data,yerr=dlog_data,capsize=capsize,fmt="o",ecolor="k",
        ms=ms,elinewidth=lw,capthick=lw)
xlim=ax.get_xlim()
ylim=ax.get_ylim()
ax.axline(xy1=(0,inter), slope=slope,label=f'$y = {slope:.4f}x {inter:+.3f}$',
        linestyle=(0, (5, 5)),color=palette[1],lw=lw)

#annotations
if show_annot:
    natoms = df["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, text in zip(x_data, log_data, annotations):
        ax.annotate(text,
                xy=(xi,yi), xycoords='data',
                xytext=(1,6), textcoords='offset points',ha='right')
ax.text(0.99, 0.09, r'$\chi^2_\nu$'f'$ = {chi2_red:.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    color=palette[1],
    transform=ax.transAxes)
ax.text(0.20,0.99,r'$y = $'+f'{slope:.2e}'+f'$x {inter:+.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    color=palette[1],
    transform=ax.transAxes)


#legend
#ax.legend()

#set xlim
ax.set_xlim(xlim)

#set ylim
ax.set_ylim(ylim)

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
