#!/usr/bin/python3

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as m_patches
import seaborn as sns
pd.options.mode.chained_assignment = None  # default='warn'

#GLOBAL CONSTANTS
DATAPATH = "./data/fullerenes_data_B3LYP.csv"
df = pd.read_csv(DATAPATH)
df0 = df[df["pt_group"] == "Ih"]
df1 = df[(df["pt_group"] == "D5h") | (df["pt_group"] == "D5d")]
df2 = df[(df["pt_group"] == "D2") | (df["pt_group"] == "D6d")]
df3 = df[(df["pt_group"] == "D3h") | (df["pt_group"] == "D3d")]

#Plot parameters
#xmin=55
#xmax=315
ymin=-25
#ymax=2500
acs_w=240
acs_h=180
left_padding=0.13
figname="graph_pol"
minor_ticks=True
show_grid=False
single_graph=False
show_annot=True
save_plot=False
show_plot=True
acs_format=True
x_label=r'N'
y_label=r'Polarizabilities ($\AA^3$)'

#Functions
def bohr_to_ang(pol):
    return pol/6.748228

def iso_pol(df):
    return np.average(df[["axx","ayy","azz"]])

def ani_pol(df):
    x=df["axx"]
    y=df["ayy"]
    z=df["azz"]
    return ((0.5*((x-y)**2+(x-z)**2+(y-z)**2))**0.5)

#Data processing
frames = [df0,df1,df2,df3]
for frame in frames:
    frame["iso_pol"] = frame.apply(iso_pol, axis=1)
    frame["ani_pol"] = frame.apply(ani_pol, axis=1)

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

#Prepare plot
n_cols = 3
palette = sns.color_palette("colorblind")
colors = [palette[i] for i in range(4)]
labels = [r'$I_h$',r'C$_{60+10n}$',r'C$_{60+12n}$',r'C$_{60+18n}$']
sns.set_palette(palette)
fig, ax = plt.subplots()

patches_col0 = [m_patches.Patch(color='w',label=r'')]
patches_col_iso = [m_patches.Patch(color='none', label=r'$\overline{\alpha}$')]
patches_col_ani = [m_patches.Patch(color='none', label=r'$\Delta\alpha$')]

for i,(frame,color,label) in enumerate(zip(frames,colors,labels)):
    liso = ax.scatter(frame["natoms"],bohr_to_ang(frame["iso_pol"]),marker="o",
            label='i',facecolor='none',edgecolor=color,s=ms,linewidths=lw)
    lani = ax.scatter(frame["natoms"],bohr_to_ang(frame["ani_pol"]),marker="x",
            label='a',facecolor=color,s=ms,linewidths=lw)

    patches_col0.append(m_patches.Patch(color='none',label=label))
    patches_col_iso.append(liso)
    patches_col_ani.append(lani)

patches = list()
patches.extend(patches_col0)
patches.extend(patches_col_iso)
patches.extend(patches_col_ani)

#annotations
if show_annot:
    natoms = df0["natoms"].values.tolist()
    annotations = ["C$_{"+str(nato)+"}$" for nato in natoms]
    for xi, yi, text in zip(df0["natoms"], bohr_to_ang(df0["iso_pol"])
                            , annotations):
        if xi == 60:
            ax.annotate(text,
                    xy=(xi,yi), xycoords='data',
                        xytext=(-1,4), textcoords='offset points',
                        ha='right',va='bottom')

#Legend
lg = ax.legend(ncol=n_cols,handles=patches,handletextpad=-1.5)

for i, text in enumerate(lg.get_texts()):
    if i < 5:
        pass
    elif i == 5:
        text.set_color('black')
    elif 6 <= i < 10:
        text.set_color('none')
    elif i == 10:
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
