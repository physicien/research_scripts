#!/usr/bin/python3
from ase.io import read, write
from ase.optimize import FIRE
#from ase.md.velocitydistribution import MaxwellBoltzmannDistribution
#from ase.md.verlet import VelocityVerlet
from ase import units
from ase.calculators.kim import KIM
import os

#Working directory
save_dir = "opt_positions"
os.makedirs(save_dir, exist_ok=True)

#Set up crystal and calculator
atoms = read("c100_crystal.cif")
calc = KIM("hNN_WenTadmor_2019Grx_C__MO_421038499185_001")
atoms.calc = calc

#Relaxation
#MaxwellBoltzmannDistribution(atoms, temperature_K=300)
#dyn = VelocityVerlet(atoms, 2 * units.fs)
dyn = FIRE(atoms, trajectory=os.path.join(save_dir, 'c100.traj'))
dyn.run(fmax=0.05)
atoms.write(os.path.join(save_dir, "c100_opt.cif"))

#for i in range (20000):
#    if i%100==0:
#        print(i)
#    dyn.run(60)
#    energy = atoms.get_total_energy()
#    forces = atoms.get_forces()
#    atoms.write(os.path.join(save_dir, "step_{:06}.xyz".format(i)))
