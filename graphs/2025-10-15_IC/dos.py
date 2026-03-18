# -*- coding: utf-8 -*-
#Import modules
import numpy as np
import matplotlib.pyplot as plt

width = 3.5
height = 4.8

#Define energy conversion factor (hartree to eV)
HA_TO_EV=27.211386245988

#fermiEnergyC60=0.04902945 #en Ha
fermiEnergyC60=0.05251 #en Ha
fermiEnergyC100=0.06937726 #en Ha

#Extract data arrays from DOS files
fileArrayC60=np.loadtxt('data/C60_EBAND_DOS_dt3o_DS3_DOS')
fileArrayC100=np.loadtxt('data/C100_EBAND_DOS_dt3o_DS3_DOS')

#Get energy arrays (x-axis)
energyTabC60=(fileArrayC60[:,0]-fermiEnergyC60)*HA_TO_EV
energyTabC100=(fileArrayC100[:,0]-fermiEnergyC100)*HA_TO_EV

#Get DOS arrays (y-axis)
dosTabC60=fileArrayC60[:,1]/HA_TO_EV
dosTabC100=fileArrayC100[:,1]/HA_TO_EV

#Plot results
plt.rcParams['figure.figsize'] = [width, height]
plt.plot(dosTabC60,energyTabC60,label='C60')
plt.plot(dosTabC100,energyTabC100,label='C100')
plt.xlim((-1,50))
plt.ylim((1.0,1.72))
plt.xlabel('DOS (states/eV)')
plt.ylabel('Energy (eV)')
plt.legend()
#plt.savefig('dos_with_eigs.svg')
plt.show()
