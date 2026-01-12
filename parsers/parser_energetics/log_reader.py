#!/usr/bin/python3

import re
from pathlib import Path

class MoleculeData(object):
    """
    Object which will contain the different values extracted from the
    .log file.
    """

    def __init__(self,path):

        self.path = path
        self.data = self.read_data()
        self.name = self.read_name()
        self.natoms = self.nb_atoms()
        self.ptgroup = self.pt_group()
        self.homo = self.energy()[0]
        self.lumo = self.energy()[1]
        self.ie = self.ionization()
        self.En = self.tot_energy("GROUND STATE")
        self.Eca = self.tot_energy("CATION STATE")
        self.Ean = self.tot_energy("ANION STATE")
        self.axx = self.pol_tensor()[0]
        self.ayy = self.pol_tensor()[1]
        self.azz = self.pol_tensor()[2]
        self.dipole = self.permanent_dipole()


    def read_data(self):
        with open(self.path,'r') as f:
            lines = [line.rstrip() for line in f]
        return lines

    def read_name(self):
        name = Path(self.path).stem
        return name

    def nb_atoms(self):
        natoms = [int(s) for s in re.findall(r'\d+',self.name)][0]
        return natoms

    def pt_group(self):
        parsed = self.data
        for line in parsed:
            if line.startswith("This point group has been found:"):
                gr = re.findall(r'\b\S+$',line)[0]
        return gr

    def energy(self):
        parsed = self.data
        for line in parsed:
            if line.startswith("HOMO"):
                energies = re.findall(r'\s.?\d+[.]\d+',line)
                homo = float(energies[0])
                lumo = float(energies[1])
        return [homo,lumo]

    def ionization(self):
        parsed = self.data
        for line in parsed:
            if line.startswith("Ionization energy:"):
                ienergy = float(re.findall(r'\d+[.]\d+',line)[0])
        return ienergy

    def tot_energy(self,label):
        parsed = self.data
        parse = False
        for line in parsed:
            if label in line:
                parse = True
            elif parse:
                if line.startswith("Total Energy"):
                    tenergy = float(re.findall(r'\s.?\d+[.]\d+',line)[1])
                    parse = False
            else:
                continue
        return tenergy

    def pol_tensor(self):
        parsed = self.data
        parse = False
        for line in parsed:
            if line.startswith("Diagonalized polarizability tensor (bohr^3):"):
                parse = True
            elif parse:
                pol = re.findall(r'\d+[.]\d+',line)
                axx = float(pol[0])
                ayy = float(pol[1])
                azz = float(pol[2])
                parse = False
            else:
                continue
        return [axx,ayy,azz]

    def permanent_dipole(self):
        parsed = self.data
        for line in parsed:
            if line.startswith("Magnitude (Debye)"):
                dipole = float(re.findall(r'\d+[.]\d+',line)[0])
        return dipole
