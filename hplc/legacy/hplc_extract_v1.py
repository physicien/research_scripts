#!/usr/bin/python3

import numpy as np
import pandas as pd
from scipy.optimize import curve_fit
import argparse
import matplotlib.pyplot as plt
import re
import os

#GLOBAL LIST
header1 = ["time","potential"]
header2 = ["mol","solvent","H","x0","sigma","max_intensity","A","FWHM"]
mol_list = list()

#FUNCTIONS
#Gaussian function
def gauss(x, H, A, x0, sigma):
    return H + A*np.exp(-(x -x0)**2/(2*sigma**2))

#Gaussian fit
def gauss_fit(x,y):
    mean = sum(x*y)/sum(y)
    sigma = np.sqrt(sum(y*(x-mean)**2)/sum(y))
    popt, pcov = curve_fit(gauss, x, y, p0=[min(y), max(y), mean, sigma])
    return popt

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
data =  np.loadtxt(path,skiprows=7)
xdata = data[:,0]
ydata = data[:,1]

#if output_csv is given - csv generation
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

data_fit = data[(data[:,0]>xmin_fit) & (data[:,0]<xmax_fit)]
#data_fit2 = data_fit[(data_fit[:,0]<4.35) | (data_fit[:,0]>4.51)]
xdata_fit = data_fit[:,0]
ydata_fit = data_fit[:,1]

#Curve fit with data
if fit_data:
    H, A, x0, sigma = gauss_fit(xdata_fit,ydata_fit)
    sigma = abs(sigma)
    FWHM = 2.35482*sigma

    print('The offset of the gaussian baseline is', H)
    print('The center of the gaussian fit is', x0)
    print('The sigma of the gaussian fit is', sigma)
    print('The maximum intensity of the gaussian fit is', H + A)
    print('The Amplitude of the gaussian fit is', A)
    print('The FWHM of the gaussian fit is', FWHM)

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
                "H": H,
                "x0": x0,
                "sigma": sigma,
                "max_intensity": H+A,
                "A": A,
                "FWHM": FWHM
                }
        mol_list.append(data_gauss)
        df = pd.DataFrame(mol_list)
        df.to_csv(outname+"_"+mol+".csv", index=False, header=header2)


if args.show:
    plt.plot(xdata, ydata, 'ko', label='data',ms=2)
    if fit_data:
        plt.plot(xdata, gauss(xdata, *gauss_fit(xdata_fit, ydata_fit)),
                '--r', label='fit')

    plt.legend()
    plt.xlabel('Time (min.)')
    plt.ylabel('Intensity (a.u.)')
    plt.show()
