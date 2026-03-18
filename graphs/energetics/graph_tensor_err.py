#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as m_patches
import seaborn as sns
pd.set_option('display.max_rows', None)

#GLOBAL CONSTANTS
DATAPATH1 = "./data/fullerenes_data_BLYP.csv"
dfA = pd.read_csv(DATAPATH1)
DATAPATH2 = "./data/fullerenes_data_B3LYP.csv"
dfB = pd.read_csv(DATAPATH2)

dfA[["exx","eyy","ezz"]] = (dfA[["axx","ayy","azz"]] - \
        dfB[["axx","ayy","azz"]])/dfB[["axx","ayy","azz"]]

df0 = dfA[dfA["pt_group"] == "Ih"]
df1 = dfA[(dfA["pt_group"] == "D5h") | (dfA["pt_group"] == "D5d")]
df2 = dfA[(dfA["pt_group"] == "D2") | (dfA["pt_group"] == "D6d")]
df3 = dfA[(dfA["pt_group"] == "D3h") | (dfA["pt_group"] == "D3d")]

#plot parameters
#xmin=55
#xmax=315
ymin=-0.015
#ymax=2500
acs_w=240
acs_h=180
left_padding=0.135
figname="graph_tensori_err"
minor_ticks=True
show_grid=False
single_graph=False
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'N'
y_label="Polarizability tensor signed error"

#functions
def bohr_to_ang(pol):
    return pol/6.748228

#Data processing
frames = [df0,df1,df2,df3]

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
n_cols = 4
palette = sns.color_palette("colorblind")
colors = [palette[i] for i in range(4)]
labels = [r'$I_h$',r'C$_{60+10n}$',r'C$_{60+12n}$',r'C$_{60+18n}$']
sns.set_palette(palette)
fig, ax = plt.subplots()

patches_col0 = [m_patches.Patch(color='w', label=r'')]
patches_colx = [m_patches.Patch(color='none', label=r'$\alpha_{xx}$')]
patches_coly = [m_patches.Patch(color='none', label=r'$\alpha_{yy}$')]
patches_colz = [m_patches.Patch(color='none', label=r'$\alpha_{zz}$')]

for i,(frame,color,label) in enumerate(zip(frames,colors,labels)):
    lx = ax.scatter(frame["natoms"],frame["exx"],marker="o",
            label='x', fc='none',edgecolor=color,s=ms,lw=lw)
    ly = ax.scatter(frame["natoms"],frame["eyy"],marker="+",
            label='y', fc=color,s=ms,lw=lw)
    lz = ax.scatter(frame["natoms"],frame["ezz"],marker="x",
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

#annotations
if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, text in zip(df0["natoms"], df0["exx"]
                            , annotations):
        if xi == 60:
            ax.annotate(text,
                    xy=(xi,yi), xycoords='data',
                        xytext=(-1,4), textcoords='offset points',
                        ha='right',va='bottom')

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

#set ylim
ax.set_ylim(bottom=ymin)

#set labels
ax.set_xlabel(x_label,fontsize=FS)
ax.set_ylabel(y_label,fontsize=FS)

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
