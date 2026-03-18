#!/usr/bin/python3

import numpy as np
#np.warnings.filterwarnings('ignore', category=np.VisibleDeprecationWarning)

NDIM = 3

class HessianData(object):
    """
    Object which will contain the unperturbed xyz coordinates and the
    normal modes parsed from a hessian file.
    """

    def __init__(self,path):

        self.path = path
        self.data = self.read_data()
        atoms = self.format_atoms()
        self.natom = atoms[0]
        self.symbol = atoms[1]
        self.atoms = atoms[2]
        self.normal_modes = self.format_normal_modes()
        self.freq = self.format_freq()


    def read_data(self):
        with open(self.path,'r') as f:
            lines = [line.rstrip() for line in f]
        return lines


    def i_or_f(self,x):
        """
        Formats the raw parsed data according to the length of the string.
        """
        if "." in x:
            result = float(x)
        else:
            result = int(x)
        return result


    def format_matrix(self,parsed):
        """

        """
        mat = [[]]
        for line in parsed:
            if all([isinstance(item, int) for item in line]):
                mat[0].extend(line)
            else:
                i = line[0]+1
                if len(mat) < i+1:
                    mat.append([])
                mat[i].extend(line[1:])
        return mat


    def format_atoms(self):
        parsed = self.data
        atoms = []
        symbols = []
        current_line = []
        parse = False
        for line in parsed:
            if line.startswith("$atoms"):
                parse = True
            elif parse:
                if line.startswith("$actual_temperature"):
                    atoms.append(current_line)
                    current_line = []
                    parse = False
                else:
                    current_line.append(line.splitlines())
            else:
                continue
        atoms = [x for x in atoms[0] if x != []]
        natom = int(atoms[0][0])
        atoms = [x[0].split() for x in atoms][1:]
        symbols = np.array([x[0] for x in atoms])
        atoms = np.array([x[2:] for x in atoms]).astype(float)
        return natom, symbols, atoms


    def format_normal_modes(self):
        """
        Format the raw normal modes taken from the ORCA output.

        Args:
            parsed (list): List of raw parsed lines taken from the output file.

        Returns:
            ???
        """
        parsed = self.data
        normal_modes = []
        current_mode = []
        parse = False
        for line in parsed:
            if line.startswith("$normal_modes"):
                parse = True
            elif parse:
                if line.startswith("#"):
                    normal_modes.append(current_mode)
                    current_mode = []
                    parse = False
                else:
                    current_mode.append([self.i_or_f(x) for x in line.split()])
            else:
                continue
        normal_modes = [x for x in normal_modes[0] if x != []]
        normal_modes = self.format_matrix(normal_modes[1:])
        normal_modes = np.array(normal_modes)[1:].transpose()
        return normal_modes.reshape(len(normal_modes),self.natom,NDIM)

    def format_freq(self):
        parsed = self.data
        freq = []
        current_line = []
        parse = False
        for line in parsed:
            if line.startswith("$vibrational_frequencies"):
                parse = True
            elif parse:
                if line.startswith("$normal_modes"):
                    freq.append(current_line)
                    current_line = []
                    parse = False
                else:
                    current_line.append(line.splitlines())
            else:
                continue
        freq = [x for x in freq[0] if x != []]
        freq = [x[0].split() for x in freq][1:]
        freq = np.array([x[1] for x in freq]).astype(float)
        return freq
