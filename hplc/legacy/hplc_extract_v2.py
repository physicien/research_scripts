#!/usr/bin/python3

import re
import os
import argparse
import numpy as np
import pandas as pd
from scipy.optimize import least_squares
from pybaselines import Baseline
from scipy.signal import find_peaks, peak_widths
from scipy.special import erf
import matplotlib.pyplot as plt
import seaborn as sns

#GLOBAL LIST
header1 = ["time","potential"]
header2 = ["mol","solvent","distribution","A","x0","sigma","alpha"]
mol_list = list()

#FUNCTIONS
def merge_intervals(intervals):
    starts = intervals[:,0]
    ends = np.maximum.accumulate(intervals[:,1])
    valid = np.zeros(len(intervals) + 1, dtype=bool)
    valid[0] = True
    valid[-1] = True
    valid[1:-1] = starts[1:] >= ends[:-1]
    return np.vstack((starts[:][valid[:-1]], ends[:][valid[1:]])).T

def proto_regions(p,w,r):
    shift = 0
    reg_min = np.clip(p-np.ceil(w+shift),0,len(r)-1)
    reg_max = np.clip(p+np.ceil(w+shift),0,len(r)-1)
    return merge_intervals(np.stack((reg_min,reg_max),axis=-1).astype(int))

def find_regions(s):
    _prom_p = 0.05*s.max()
    _prom_n = 0.9*(-s).max()
    _peaks_p, _ = find_peaks(s,prominence=_prom_p)
    _peaks_n, _ = find_peaks(-s,prominence=_prom_n,height=0.4)
    _widths_p = peak_widths(s, _peaks_p, rel_height=0.5)[0]
    _widths_n = peak_widths(-s, _peaks_n, rel_height=0.5)[0]
    _peaks = np.append(_peaks_p,_peaks_n)
    _widths = np.append(_widths_p,_widths_n)
#    _max_half_window = np.mean(_widths[_widths<100])/2
    _max_half_window = np.max(_widths[_widths<len(s)/50])
#    _max_half_window = np.clip(_widths.max(),10,100)
#    print(_widths)
    print(_max_half_window)
    print(len(s))
    return [proto_regions(_peaks,_widths,s),_max_half_window]

#Gaussian function
def gauss(x, params):
    amp, x0, sigma = params
    return amp*np.exp(-(x-x0)**2/(2*sigma**2))

#Skew-normal function
def skew_norm(x,params):
    amp, loc, scale, alpha = params
    _x = alpha*(x-loc)/scale
    norm = np.sqrt(2*np.pi*scale**2)**-1* np.exp(
            -((x-loc)**2)/(2*scale**2)
            )
    cdf = 0.5*(1+erf(_x/np.sqrt(2)))
    return amp*2*norm*cdf

#Least squares equation
def lsq_eq(p,fct,x,y):
    return fct(x,p) - y

def peaks_params(s):
    _prom_p = 0.05*s.max()
    _prom_n = 0.5*(-s).max()
    _peaks_p, _ = find_peaks(s,prominence=_prom_p)
    _peaks_n, _ = find_peaks(-s,prominence=_prom_n,height=0.1)
    _widths_p = peak_widths(s, _peaks_p, rel_height=0.5)[0]
    _widths_n = peak_widths(-s, _peaks_n, rel_height=0.5)[0]
    _peaks = np.append(_peaks_p,_peaks_n)
    _widths = np.append(_widths_p,_widths_n)
    return [_peaks,_widths]

def lsq_gauss_fit(x,y):
    _peaks, _widths = peaks_params(y)
    main_peak_i = np.absolute(y[_peaks]).argmax()
    _i = _peaks[main_peak_i]
    A0 = y[_i]
    tau0 = x[_i]
    sigma0 = x[_i + int(_widths[main_peak_i]/2)] - x[_i]
    p0 = [A0, tau0, sigma0]
    if A0 < 0:
        bA = [-np.inf,0]
    else:
        bA = [0,np.inf]
    bounds = ([bA[0],tau0-0.1,0],[bA[1],tau0+0.1,np.inf])
    res_robust = least_squares(lsq_eq, p0, loss="soft_l1",
                              f_scale=0.1, args=(gauss,x,y),
                               bounds=bounds)
    return res_robust.x

def lsq_skew_norm_fit(x,y):
    _peaks, _widths = peaks_params(y)
    main_peak_i = np.absolute(y[_peaks]).argmax()
    _i = _peaks[main_peak_i]
    A0 = y[_i]
    tau0 = x[_i]
    sigma0 = x[_i + int(_widths[main_peak_i]/2)] - x[_i]
    p0 = [A0, tau0, sigma0, 0]
    if A0 < 0:
        bA = [-np.inf,0]
    else:
        bA = [0,np.inf]
    bounds = ([bA[0],tau0-0.1,0,-np.inf],[bA[1],tau0+0.1,np.inf,np.inf])
    res_robust = least_squares(lsq_eq, p0, loss="soft_l1",
                               f_scale=0.1, args=(skew_norm,x,y),
                               bounds=bounds)
    return res_robust.x


#PARSER
#Create parser
parser = argparse.ArgumentParser(prog='hplc_parser',\
        description='Parse data from .txt file')

#File is required
parser.add_argument("filename",
        help="the .inp data file")

parser.add_argument('-s','--show',
        default=0, action='store_true',
        help='show the plot window')

parser.add_argument('-o','--output_csv',
        default=0, action='store_true',
#        type=str,
        help='output data to <ARG>.csv')

parser.add_argument('-os','--output_stats',
        type=str,
        help='output stats to <ARG>.csv')

parser.add_argument('-n','--nofit',
        default=1, action='store_false',
        help='do not fit the chromatogram')

parser.add_argument('-nb','--nobaseline',
        default=1, action='store_false',
        help='do not correct the baseline')

parser.add_argument('-x0','--startx',
        type=float,
        help='start fitting the gaussian at x min')

parser.add_argument('-x1','--endx',
        type=float,
        help='end fitting the gaussian at x min')

#Parse arguments
args = parser.parse_args()

#change values according to arguments
fit_data = args.nofit
do_bl = args.nobaseline

#check if startx and endx are equal - exif if true.
if args.startx is not None and args.endx is not None and args.startx == args.endx:
    print("Warning. x0 and x1 are equal. Exit.")
    sys.exit(1)

#check if startx < 0 - exit if true.
if args.startx:
    if args.startx < 0:
        print("Warning. x0 < 0. Exit.")
        sys.exit(1)

#check if endx < 0 - exit if true.
if args.endx:
    if args.endx < 0:
        print("Warning. x1 < 0. Exit.")
        sys.exit(1)

#Data processing
path = args.filename
print(path)
data =  np.loadtxt(path,skiprows=7)
xdata = data[:,0]
ydata_ini = data[:,1]
signal = np.copy(ydata_ini)

#determine the parameter value for the baseline correction
regions, max_half_window = find_regions(signal)

#baseline correction
if do_bl:
    baseline_fitter = Baseline(x_data=xdata)
    baseline, params = baseline_fitter.custom_bc(
            signal,
            "snip",
            regions=regions,
            sampling=2,
            method_kwargs={"max_half_window": max_half_window,
                            "decreasing": True,
                            "smooth_half_window": 5,
                            },
            lam=1e0
            )
    ydata = data[:,1] - baseline
else:
    ydata = data[:,1]
ajusted_data = np.array([xdata,ydata]).T

#if output_csv is given - csv generation of the chromatogram
if args.output_csv:
    filename = os.path.splitext(os.path.basename(path))[0]
    df = pd.DataFrame(data)
    df.to_csv(filename+".csv", index=False, header=header1)

#if startx argument is given - x-axis range
if args.startx:
    xmin_fit = args.startx
else:
    xmin_fit = min(xdata)

#if endx argument is given - x-axis range
if args.endx:
    xmax_fit = args.endx
else:
    xmax_fit = max(xdata)

data_fit = ajusted_data[(xdata>xmin_fit) & (xdata<xmax_fit)]
xdata_fit = data_fit[:,0]
ydata_fit = data_fit[:,1]

#Curve fit with data
if fit_data:
    x_robust = np.arange(xdata_fit.min()-0.1, xdata_fit.max()+0.1, 0.001)
    #Gaussian curve fit
    p_lsq_g = lsq_gauss_fit(xdata_fit,ydata_fit)
    y_robust_g = gauss(x_robust,p_lsq_g)
    A_g, x0_g, sigma_g = p_lsq_g
    sigma_g = abs(sigma_g)

#    FWHM = 2.35482*sigma_g
    print('The Amplitude of the gaussian fit is', A_g)
    print('The center of the gaussian fit is', x0_g)
    print('The sigma of the gaussian fit is', sigma_g,"\n")
#    print('The FWHM of the gaussian fit is', FWHM)

    #Skew-Normal curve fit
    p_lsq_sn = lsq_skew_norm_fit(xdata_fit,ydata_fit)
    y_robust_sn = skew_norm(x_robust,p_lsq_sn)
    A_sn, x0_sn, sigma_sn, alpha_sn = p_lsq_sn
    sigma_sn = abs(sigma_sn)
    
    print('The Amplitude of the skew-normal fit is', A_sn)
    print('The center of the skew-normal fit is', x0_sn)
    print('The sigma of the skew-normal fit is', sigma_sn)
    print('The skew parameter of the skew-normal fit is', alpha_sn)

    #if output_stats is given - csv generation
    if args.output_stats:
        mol = args.output_stats
        path = args.filename
        filename = os.path.basename(path)
        outname = re.match(r"(^.+).txt",filename).group(1)
        solvent = re.match(r"(^.+)__LPYE",filename).group(1)
        data_gauss = {
                "mol": mol,
                "solvent": solvent,
                "distribution":"Gaussian",
                "A": A_g,
                "x0": x0_g,
                "sigma": sigma_g,
                "alpha": 0
                }
        data_skew_norm = {
                "mol": mol,
                "solvent": solvent,
                "distribution":"Skew-Normal",
                "A": A_sn,
                "x0": x0_sn,
                "sigma": sigma_sn,
                "alpha": alpha_sn
                }
        mol_list.append(data_gauss)
        mol_list.append(data_skew_norm)
        df = pd.DataFrame(mol_list)
        df.to_csv(outname+"_"+mol+".csv", index=False, header=header2)


if args.show:
    palette = sns.color_palette("colorblind")
    sns.set_palette(palette)

    plt.plot(xdata, ydata_ini, marker='.', ls='', c=palette[7],
             label='raw data',ms=3)
    if do_bl:
        plt.plot(xdata, ydata, ls='-',c=palette[5], lw=1.5,
                label='ajusted data')
        plt.plot(xdata, baseline, ls='--',c=palette[0], lw=2.0,
                label='baseline')
    if fit_data:
        plt.plot(x_robust, y_robust_g, ls='--', c=palette[2], lw=2.0,
                 label='robust gaussian fit')
        plt.plot(x_robust, y_robust_sn, ls='-.', c=palette[3], lw=2.0,
                 label='robust skew-normal fit')

    plt.legend()
    plt.xlabel('Time (min.)')
    plt.ylabel('Intensity (a.u.)')
    plt.show()
#    filename = os.path.splitext(os.path.basename(path))[0]
#    plt.savefig(f"images/{filename}.png")
#    print("")
