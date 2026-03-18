#!/usr/bin/python3

import pandas as pd
import numpy as np
import math
import matplotlib.pyplot as plt
import matplotlib.patches as m_patches
from matplotlib.ticker import FormatStrFormatter
import seaborn as sns
from scipy.optimize import curve_fit

#GLOBAL CONSTANTS
DATAPATH = "./data/fullerenes_data_B3LYP.csv"
df = pd.read_csv(DATAPATH)
df0 = df[df["pt_group"] == "Ih"]
df1 = df[(df["pt_group"] == "D5h") | (df["pt_group"] == "D5d")]
df2 = df[(df["pt_group"] == "D2") | (df["pt_group"] == "D6d")]
df3 = df[(df["pt_group"] == "D3h") | (df["pt_group"] == "D3d")]

#plot parameters
xmin=55
#xmax=315
ymin=70
#ymax=2500
acs_w=504
acs_h=300
left_padding=0.06
figname="graph_ll_tensor"
minor_ticks=True
show_grid=False
single_graph=False
save_plot=False
show_plot=True
acs_format=True
x_label=r'N'
y_label="Polarizability tensor ($\AA^3$)"

#functions
def bohr_to_ang(pol):
    return pol/6.748228

def log(df,col):
    return math.log10(df[col])

def logy(df,col):
    y=bohr_to_ang(df[col])
    return math.log10(y)

def linearFunc(x,intercept,slope):
    y = intercept + slope * x
    return y

def logFit(df,xmin=0,xmax=10000):
    x = df[(df["natoms"]>xmin) & (df["natoms"]<xmax)].apply(log,axis=1,
            col=("natoms"))
    yx = df[(df["natoms"]>xmin) & (df["natoms"]<xmax)].apply(logy,axis=1,
            col=("axx"))
    yy = df[(df["natoms"]>xmin) & (df["natoms"]<xmax)].apply(logy,axis=1,
            col=("ayy"))
    yz = df[(df["natoms"]>xmin) & (df["natoms"]<xmax)].apply(logy,axis=1,
            col=("azz"))
    a_fit_x,cov_x=curve_fit(linearFunc,x,yx)
    a_fit_y,cov_y=curve_fit(linearFunc,x,yy)
    a_fit_z,cov_x=curve_fit(linearFunc,x,yz)
    print('{:<8.3f}{:<8.3f}{:<8.3f}'.format(a_fit_x[1],a_fit_y[1],a_fit_z[1]))
    return a_fit_x,a_fit_y,a_fit_z,len(x)

def slopeCurve(x,inter,slope):
    return x**slope * 10**inter

def meanCurve(lls,n):
    return np.mean(lls[0:n],axis=0)
    
#Data processing
frames = [df0,df1,df2,df3]

lls0=logFit(df0,150)
lls1=logFit(df1,150)
lls2=logFit(df2,150)
lls3=logFit(df3,150)

nbMol=lls1[3]+lls2[3]+lls3[3]
sl0=meanCurve(lls0,3)
slxy=(meanCurve(lls1,2)*lls1[3]
        +meanCurve(lls2,2)*lls2[3]
        +meanCurve(lls3,2)*lls3[3])/nbMol
slz=(lls1[2]*lls1[3]+lls2[2]*lls2[3]+lls3[2]*lls3[3])/nbMol


#set font size and plot parameters
if acs_format:
    width=acs_w/72
    height=acs_h/72
    s1,s2,s3,FS=5,6,7,7
    ms=8
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
plt.rc('legend', fontsize=s2)   # Set the legend font size
plt.rc('figure', titlesize=s3)  # Set the font size of the figure title
plt.rcParams["mathtext.fontset"] = "cm"

#prepare plot
n_cols = 4
palette = sns.color_palette("colorblind")
colors = [palette[i] for i in range(4)]
labels = [r'$I_h$',r'C$_{60+10n}$',r'C$_{60+12n}$',r'C$_{60+18n}$']
sns.set_palette(palette)
fig, ax = plt.subplots()

t=np.arange(150,330,1)
cs=palette[7]
ax.plot(t,slopeCurve(t,sl0[0],sl0[1]),ls='--',c=cs)
ax.plot(t,slopeCurve(t,slxy[0],slxy[1]),ls='--',c=cs)
ax.plot(t,slopeCurve(t,slz[0],slz[1]),ls='--',c=cs)

patches_col0 = [m_patches.Patch(color='w', label=r'')]
patches_colx = [m_patches.Patch(color='none', label=r'$\alpha_{xx}$')]
patches_coly = [m_patches.Patch(color='none', label=r'$\alpha_{yy}$')]
patches_colz = [m_patches.Patch(color='none', label=r'$\alpha_{zz}$')]

for i,(frame,color,label) in enumerate(zip(frames,colors,labels)):
    lx = ax.scatter(frame["natoms"],bohr_to_ang(frame["axx"]),marker="o",
            label='x', fc='none',ec=color,s=ms,lw=lw)
    ly = ax.scatter(frame["natoms"],bohr_to_ang(frame["ayy"]),marker="+",
            label='y', fc=color,s=ms,lw=lw)
    lz = ax.scatter(frame["natoms"],bohr_to_ang(frame["azz"]),marker="x",
            label='z', fc=color,s=ms,lw=lw)

    patches_col0.append(m_patches.Patch(color='none',label=label))
    patches_colx.append(lx)
    patches_coly.append(ly)
    patches_colz.append(lz)

patches = list()
patches.extend(patches_col0)
patches.extend(patches_colx)
patches.extend(patches_coly)
patches.extend(patches_colz)

#annotation
mid=int(len(t)/3)
ax.annotate(f'{sl0[1]:.2f}',
        xy=(t[mid],slopeCurve(t[mid],sl0[0],sl0[1])),
        xycoords='data',fontsize=FS,color=cs,
        xytext=(0,10),textcoords='offset points',
        ha='center')
ax.annotate(f'{slxy[1]:.2f}',
        xy=(t[mid],slopeCurve(t[mid],slxy[0],slxy[1])),
        xycoords='data',fontsize=FS,color=cs,
        xytext=(0,8),textcoords='offset points',
        ha='center')
ax.annotate(f'{slz[1]:.2f}',
        xy=(t[mid],slopeCurve(t[mid],slz[0],slz[1])),
        xycoords='data',fontsize=FS,color=cs,
        xytext=(0,12),textcoords='offset points',
        ha='center')


#legend
lg = ax.legend(ncol=n_cols,handles=patches,handletextpad=-1.7)

for i, text in enumerate(lg.get_texts()):
    if i < 5:
        pass
    elif i == 5:
        text.set_color('black')
    elif 6 <= i < 10:
        text.set_color('none')
    elif i == 10:
        text.set_color('black')
    elif 11 <= i < 15:
        text.set_color('none')
    elif i == 15:
        text.set_color('black')
    else:
        text.set_color('none')

#set xlim
ax.set_xlim(xmin=xmin)

#set ylim
ax.set_ylim(ymin=ymin)

#set log scale
ax.set_xscale('log')
ax.set_yscale('log')

#set labels
ax.set_xlabel(x_label,fontsize=FS)
ax.set_ylabel(y_label,fontsize=FS)

#show minor ticks
if minor_ticks:
    ax.minorticks_on()

#tick parameters
ax.tick_params(which='major',length=major_tick)
ax.tick_params(which='minor',length=minor_tick)
ax.tick_params(axis='x',which='minor',length=major_tick)
ax.xaxis.set_major_formatter(FormatStrFormatter('% .0f'))
ax.xaxis.set_minor_formatter(FormatStrFormatter('% .0f'))

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
