#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.optimize import curve_fit

#GLOBAL CONSTANTS
DATAPATH0 = "./data/lab_test.csv"
DATAPATH1 = "./data/lab_same.csv"
df0 = pd.read_csv(DATAPATH0,comment="#")
df1 = pd.read_csv(DATAPATH1,comment="#")
t0 = 3.127
dt0 = 0.195
ipyr = 199.0859
apyr = 177.9258
nsig = 1

# plot parameters
#xmin=75
#xmax=315
#ymin=-0.75
#ymax=2500
acs_w=460
acs_h=150
left_padding=0.06
figname="graph_three_exp2_horizontal"
minor_ticks=True
show_grid=False
single_graph=True
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label2=r'$\overline{\alpha}$ ($\AA^3$)'
x_label3=r'$\alpha_\mathrm{eff}$ ($\AA^3$)'
x_label4=r'$\alpha^{AB}$ ($\AA^6$)'
y_label=r'$\log k$'
label_1=r'All radii'
label_2=r'C$_{60}$-like radii'
linestyle1=(0, (5, 5))#'dashed'
linestyle2='dotted'
xytop=(2,6)#(4,6)
xydown=(11,-9)#(4,6)

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

def chi_sq_red(x,y,dy,inter,slope):
    chi2 = sum((y-linearFunc(x,inter,slope))**2/dy**2)
    dof = len(y) - 2
    return chi2/dof

def pos_anno(df):
    r = df["radius"]
    if r < 3.7:
        return xytop
    else:
        return xydown

#Data processing
iso0 = df0.apply(iso_pol, axis=1)
iso1 = df1.apply(iso_pol, axis=1)
ani0 = df0.apply(ani_pol, axis=1)
ani1 = df1.apply(ani_pol, axis=1)
log_data0 = df0.apply(log, axis=1) 
log_data1 = df1.apply(log, axis=1) 
dlog_data0 = df0.apply(dlog, axis=1)
dlog_data1 = df1.apply(dlog, axis=1)
eff0 = iso0 - ani0/6
eff1 = iso1 - ani1/6
c_factor0 = iso0*ipyr - (iso0*apyr + ani0*ipyr - ani0*apyr)/6 
c_factor1 = iso1*ipyr - (iso1*apyr + ani1*ipyr - ani1*apyr)/6 

x20 = bohr_to_ang(iso0)
a_fit20,cov20=curve_fit(linearFunc,x20,log_data0,sigma=dlog_data0,
        absolute_sigma=True)
inter20 = a_fit20[0]
slope20 = a_fit20[1]
d_inter20 = np.sqrt(cov20[0][0])
d_slope20 = np.sqrt(cov20[1][1])
chi2_red20=chi_sq_red(x20,log_data0,dlog_data0,inter20,slope20)

x21 = bohr_to_ang(iso1)
a_fit21,cov21=curve_fit(linearFunc,x21,log_data1,sigma=dlog_data1,
        absolute_sigma=True)
inter21 = a_fit21[0]
slope21 = a_fit21[1]
d_inter21 = np.sqrt(cov21[0][0])
d_slope21 = np.sqrt(cov21[1][1])
chi2_red21=chi_sq_red(x21,log_data1,dlog_data1,inter21,slope21)

x30 = bohr_to_ang(eff0)
a_fit30,cov30=curve_fit(linearFunc,x30,log_data0,sigma=dlog_data0,
        absolute_sigma=True)
inter30 = a_fit30[0]
slope30 = a_fit30[1]
d_inter30 = np.sqrt(cov30[0][0])
d_slope30 = np.sqrt(cov30[1][1])
chi2_red30=chi_sq_red(x30,log_data0,dlog_data0,inter30,slope30)

x31 = bohr_to_ang(eff1)
a_fit31,cov31=curve_fit(linearFunc,x31,log_data1,sigma=dlog_data1,
        absolute_sigma=True)
inter31 = a_fit31[0]
slope31 = a_fit31[1]
d_inter31 = np.sqrt(cov31[0][0])
d_slope31 = np.sqrt(cov31[1][1])
chi2_red31=chi_sq_red(x31,log_data1,dlog_data1,inter31,slope31)

x40 = bohr_to_ang(bohr_to_ang(c_factor0))
a_fit40,cov40=curve_fit(linearFunc,x40,log_data0,sigma=dlog_data0,
        absolute_sigma=True)
inter40 = a_fit40[0]
slope40 = a_fit40[1]
d_inter40 = np.sqrt(cov40[0][0])
d_slope40 = np.sqrt(cov40[1][1])
chi2_red40=chi_sq_red(x40,log_data0,dlog_data0,inter40,slope40)

x41 = bohr_to_ang(bohr_to_ang(c_factor1))
a_fit41,cov41=curve_fit(linearFunc,x41,log_data1,sigma=dlog_data1,
        absolute_sigma=True)
inter41 = a_fit41[0]
slope41 = a_fit41[1]
d_inter41 = np.sqrt(cov41[0][0])
d_slope41 = np.sqrt(cov41[1][1])
chi2_red41=chi_sq_red(x41,log_data1,dlog_data1,inter41,slope41)

#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS,FSc,FSb=5,6,7,5,6,10
    ms=1
    lw=0.75
    capsize=2
    major_tick,minor_tick=4,2
else:
    width=7.2
    height=7.2
    s1,s2,s3,FS,FSc,FSb=14,16,18,14,16,20
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

#prepare plot
palette = sns.color_palette("colorblind")
sns.set_palette(palette)
fig, axs = plt.subplots(1,3)

axs[0].errorbar(x20,log_data0,yerr=dlog_data0,capsize=capsize,fmt="o",
        ms=ms,elinewidth=lw,capthick=lw,ecolor="k",color=palette[2])
xlim2=axs[0].get_xlim()
ylim2=axs[0].get_ylim()
axs[0].axline(xy1=(0,inter20), slope=slope20,
        label=label_1,
        linestyle=linestyle1,color=palette[1],lw=lw)
axs[0].axline(xy1=(0,inter21), slope=slope21,
        label=label_2,
        linestyle=linestyle2,color=palette[0],lw=lw)

axs[1].errorbar(x30,log_data0,yerr=dlog_data0,capsize=capsize,fmt="o",
        ms=ms,elinewidth=lw,capthick=lw,ecolor="k",color=palette[2])
xlim3=axs[1].get_xlim()
ylim3=axs[1].get_ylim()
axs[1].axline(xy1=(0,inter30), slope=slope30,
        label=label_1,
        linestyle=linestyle1,color=palette[1],lw=lw)
axs[1].axline(xy1=(0,inter31), slope=slope31,
        label=label_2,
        linestyle=linestyle2,color=palette[0],lw=lw)

axs[2].errorbar(x40,log_data0,yerr=dlog_data0,capsize=capsize,fmt="o",
        ms=ms,elinewidth=lw,capthick=lw,ecolor="k",color=palette[2])
xlim4=axs[2].get_xlim()
ylim4=axs[2].get_ylim()
axs[2].axline(xy1=(0,inter40), slope=slope40,
        label=label_1,
        linestyle=linestyle1,color=palette[1],lw=lw)
axs[2].axline(xy1=(0,inter41), slope=slope41,
        label=label_2,
        linestyle=linestyle2,color=palette[0],lw=lw)

#annotations
x_ac = 0.99
y0_ac = 0.17#0.52
y1_ac = 0.09#0.42
x_eq = 0.58#0.02
y0_eq = 0.99
y1_eq = 0.91
labchi2a=r'$\chi^2_{\nu,\mathrm{all}}$'
labchi2t=r'$\chi^2_{\nu,\mathrm{tubes}}$'
labya=r'$y_\mathrm{all} = $'
labyt=r'$y_\mathrm{tubes} = $'

if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    xyanno = df0.apply(pos_anno, axis=1)
    for xi, yi, xyi, text in zip(x20, log_data0, xyanno, annotations):
        axs[0].annotate(text,
                xy=(xi,yi), xycoords='data',
                xytext=xyi, textcoords='offset points',ha='right')
    for xi, yi, xyi, text in zip(x30, log_data0, xyanno, annotations):
        axs[1].annotate(text,
                xy=(xi,yi), xycoords='data',
                xytext=xyi, textcoords='offset points',ha='right')
    for xi, yi, xyi, text in zip(x40, log_data0, xyanno, annotations):
        axs[2].annotate(text,
                xy=(xi,yi), xycoords='data',
                xytext=xyi, textcoords='offset points',ha='right')

axs[0].text(x_ac, y0_ac, labchi2a+f'$ = {chi2_red20:.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[1],
    transform=axs[0].transAxes)
axs[0].text(x_ac, y1_ac, labchi2t+f'$ = {chi2_red21:.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[0],
    transform=axs[0].transAxes)
axs[0].text(x_eq, y0_eq, labya+f'{slope20:.2e}'+f'$x {inter20:+.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[1],
    transform=axs[0].transAxes)
axs[0].text(x_eq, y1_eq, labyt+f'{slope21:.2e}'+f'$x {inter21:+.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[0],
    transform=axs[0].transAxes)
#axs[0].text(-0.20, 0.99, "(a)",
#    horizontalalignment='left',
#    verticalalignment='bottom',
#    fontsize=FSb,# weight='bold',
#    transform=axs[0].transAxes)

axs[1].text(x_ac, y0_ac, labchi2a+f'$ = {chi2_red30:.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[1],
    transform=axs[1].transAxes)
axs[1].text(x_ac, y1_ac, labchi2t+f'$ = {chi2_red31:.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[0],
    transform=axs[1].transAxes)
axs[1].text(x_eq, y0_eq, labya+f'{slope30:.2e}'+f'$x {inter30:+.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[1],
    transform=axs[1].transAxes)
axs[1].text(x_eq, y1_eq, labyt+f'{slope31:.2e}'+f'$x {inter31:+.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[0],
    transform=axs[1].transAxes)
#axs[1].text(-0.20, 0.99, "(b)",
#    horizontalalignment='left',
#    verticalalignment='bottom',
#    fontsize=FSb,# weight='bold',
#    transform=axs[1].transAxes)

axs[2].text(x_ac, y0_ac, labchi2a+f'$ = {chi2_red40:.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[1],
    transform=axs[2].transAxes)
axs[2].text(x_ac, y1_ac, labchi2t+f'$ = {chi2_red41:.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[0],
    transform=axs[2].transAxes)
axs[2].text(x_eq, y0_eq, labya+f'{slope40:.2e}'+f'$x {inter40:+.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[1],
    transform=axs[2].transAxes)
axs[2].text(x_eq, y1_eq, labyt+f'{slope41:.2e}'+f'$x {inter41:+.2f}$',
    horizontalalignment='right',
    verticalalignment='top',
    fontsize=FSc,
    color=palette[0],
    transform=axs[2].transAxes)
#axs[2].text(-0.20, 0.99, "(c)",
#    horizontalalignment='left',
#    verticalalignment='bottom',
#    fontsize=FSb,# weight='bold',
#    transform=axs[2].transAxes)

#legend
#for ax in axs.flat:
#    ax.legend()#loc='lower right')

#set xlim
axs[0].set_xlim(xlim2)
axs[1].set_xlim(xlim3)
axs[2].set_xlim(xlim4)

#set ylim
axs[0].set_ylim(ylim2)
axs[1].set_ylim(ylim3)
axs[2].set_ylim(ylim4)

#set labels
axs[0].set_xlabel(x_label2,fontsize=FS)
axs[1].set_xlabel(x_label3,fontsize=FS)
axs[2].set_xlabel(x_label4,fontsize=FS)
axs[0].set_ylabel(y_label,fontsize=FS)
#axs[1].set_ylabel(y_label,fontsize=FS)
#axs[2].set_ylabel(y_label,fontsize=FS)

#show minor ticks
if minor_ticks:
    for ax in axs.flat:
        ax.minorticks_on()

#tick parameters
axs[1].tick_params(which='both', left = False, labelleft = False)
axs[2].tick_params(which='both', left = False, labelleft = False)
for ax in axs.flat:
    ax.tick_params(which='major',length=major_tick)
    ax.tick_params(which='minor',length=minor_tick)


#spine
for ax in axs.flat:
    ax.spines[['top','right']].set_visible(False)

#show grid
if show_grid:
    for ax in axs.flat:
        ax.grid(True,which='major',axis='x',color='black',linestyle='dotted',
            linewidth=0.5)

#tight layout
plt.tight_layout()
if single_graph:
    plt.subplots_adjust(left=left_padding)
plt.subplots_adjust(wspace=0.1)

if save_plot:
    t01 = "{:.3f}".format(t0).replace(".","_")
    plt.savefig(f"{figname}-{t01}-{nsig}.svg")

if show_plot:
    plt.show()
