#!/usr/bin/python3

import re
from pathlib import Path

class MoleculeData(object):
    """
    Object which will contain the different values extracted from the
    .log and .xyz files.
    """

    def __init__(self,path):

        self.path = path
        self.data = self.read_data()
        self.name = self.read_name()
        self.molecule = self.read_mol()
        self.natoms = self.read_natoms()
        self.freq = self.read_freq()
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

    def read_mol(self):
        fname = self.name
        mol = re.findall(r'(^\S+)_p',fname)
        return mol[0]

    def read_natoms(self):
        parsed = self.data
        for line in parsed:
            if line.startswith("XYZ file"):
                fname = re.findall(r':\s(.+.xyz)',line)
            else:
                continue
        parent = Path(self.path).parent
        xyzpath = str(parent) + "/" + fname[0]
        with open(xyzpath) as f:
            natoms = f.readline().strip('\n')
        return int(natoms)

    def read_freq(self):
        parsed = self.data
        for line in parsed:
            if line.startswith("Imaginary frequency"):
                freq = re.findall(r'\d+[.]\d+',line)
            else:
                continue
        return float(freq[0])

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
