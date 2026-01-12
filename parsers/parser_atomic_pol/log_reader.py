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
        parsed = self.data
        for line in parsed:
            if line.startswith("XYZ file"):
                mol = re.findall(r':\s(.+).xyz',line)
            else:
                continue
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

class AtomicData(object):
    """
    Object which will contain the different values extracted from the
    .log, .out and .xyz files.
    """

    def __init__(self,path):

        self.path = path
        self.log = self.read_log()
        self.name = self.read_name()
        self.data_out = self.read_data_out()
        self.data_xyz = self.read_data_xyz()
        self.atoms = self.read_atoms()
        self.atom_dip = self.read_dipole()
        self.atom_pol = self.read_polarizabilities()

    def read_log(self):
        with open(self.path,'r') as f:
            lines = [line.rstrip() for line in f]
        return lines

    def read_name(self):
        name = Path(self.path).stem
        return name

    def read_data_out(self):
        name = re.findall(r'(^.+_p)_\d+',self.name)
        parent = Path(self.path).parent
        out_path = str(parent) + "/POL_" + name[0] + ".out"
        with open(out_path,'r') as f:
            lines = [line.rstrip() for line in f]
        return lines

    def read_data_xyz(self):
        parsed = self.log
        for line in parsed:
            if line.startswith("XYZ file"):
                xyzfile = re.findall(r':\s(.+.xyz)',line)
            else:
                continue
        parent = Path(self.path).parent
        xyz_path = str(parent) + "/" + xyzfile[0]
        with open(xyz_path,'r') as f:
            lines = [line.rstrip() for line in f]
        return lines

    def read_atoms(self):
        atoms_list = list()
        pattern = r'([A-Z][a-z]?)\s+(-?\d+.\d+)\s+(-?\d+.\d+)\s+(-?\d+.\d+)'
        parsed = self.data_xyz
        for line in parsed:
            xyz_data = re.findall(pattern,line)
            if xyz_data:
                elem = xyz_data[0][0]
                xx = float(xyz_data[0][1])
                yy = float(xyz_data[0][2])
                zz = float(xyz_data[0][3])
                atom = [elem,xx,yy,zz]
                atoms_list.append(atom)
            else:
                continue
        return atoms_list

    def read_dipole(self):
        dipole_list = list()
        pattern = r"^\s+?\d+-[A-Z][a-z]?\s+:\s+(-?\d+.\d+)"\
                "\s+(-?\d+.\d+)\s+(-?\d+.\d+)\s+\("
        parsed = self.data_out
        parse = False
        for line in parsed:
            if line.startswith("ATOMIC DIPOLE MOMENTS"):
                parse = True
            elif parse:
                dip = re.findall(pattern,line)
                if dip:
                    dx = float(dip[0][0])
                    dy = float(dip[0][1])
                    dz = float(dip[0][2])
                    dipole_list.append([dx,dy,dz])
                if line.startswith("Total dipole moment (a.u.):"):
                    parse = False
            else:
                continue
        return dipole_list

    def read_polarizabilities(self):
        pol_list = list()
        pattern = r"^\s+?\d+-[A-Z][a-z]?\s+:\s+(-?\d+.\d+)\s+(-?\d+.\d+)"\
                "\s+(-?\d+.\d+)\s+(-?\d+.\d+)\s+(-?\d+.\d+)\s+(-?\d+.\d+)"
        parsed = self.data_out
        parse = False
        for line in parsed:
            if line.startswith("ATOMIC POLARIZABILITIES"):
                parse = True
            elif parse:
                pol = re.findall(pattern,line)
                if pol:
                    xx = float(pol[0][0])
                    yy = float(pol[0][1])
                    zz = float(pol[0][2])
                    xy = float(pol[0][3])
                    xz = float(pol[0][4])
                    yz = float(pol[0][5])
                    pol_list.append([xx,yy,zz,xy,xz,yz])
                if line.startswith("Sum polar. (a.u.)"):
                    parse = False
            else:
                continue
        return pol_list

