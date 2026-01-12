#!/usr/bin/python3

import re
from pathlib import Path

class DataReader(object):
    """
    Object which will contain the different values extracted from the .txt file.
    """

    def __init__(self,path):

        self.path = path
        self.txt = self.read_txt()
        self.name = self.read_name()
        self.experiment = self.txt[1]
        self.data = self.read_data()

    def read_txt(self):
        with open(self.path,'r') as f:
            lines = [line.rstrip() for line in f]
        return lines

    def read_name(self):
        name = Path(self.path).stem
        return name

    def read_voltammetry(self):
        pot_list=list()
        current_list=list()
        pattern = r"^(-?\d+\.\d+),\s+" + \
                    r"(-?\d+\.\d+[eE][+-]?\d+)"
        parsed = self.txt
        for line in parsed:
            if re.search(pattern,line):
                pot_list.append(float(line.strip().split(',')[0]))
                current_list.append(float(line.strip().split(',')[1]))
        data = {
                "potential": pot_list,
                "current": current_list,
                }
        return data

    def read_amperometric(self):
        time_list=list()
        current_list=list()
        pattern = r"^(-?\d+\.\d+[eE][+-]?\d+),\s+" + \
                    r"(-?\d+\.\d+[eE][+-]?\d+)"
        parsed = self.txt
        for line in parsed:
            if re.search(pattern,line):
                time_list.append(float(line.strip().split(',')[0]))
                current_list.append(float(line.strip().split(',')[1]))
        data = {
                "time": time_list,
                "current": current_list,
                }
        return data

    def read_tafel(self):
        pot_list=list()
        current_list=list()
        logiA_list=list()
        pattern = r"^(-?\d+\.\d+),\s+" + \
                    r"(-?\d+\.\d+[eE][+-]?\d+),\s+" + \
                    r"(-?\d+\.\d+[eE][+-]?\d+)"
        parsed = self.txt
        for line in parsed:
            if re.search(pattern,line):
                pot_list.append(float(line.strip().split(',')[0]))
                current_list.append(float(line.strip().split(',')[1]))
                logiA_list.append(float(line.strip().split(',')[2]))
        data = {
                "potential": pot_list,
                "current": current_list,
                "log(i/A)": logiA_list
                }
        return data

    def read_data(self):
        fpath = self.path
        if "Voltammetry" in self.experiment:
            try:
                data = self.read_voltammetry()
            #file not found -> exit here
            except IOError:
                print(f"'{fpath}'" + " not found")
                sys.exit(1)
        elif "Amperometric" in self.experiment:
            try:
                data = self.read_amperometric()
            #file not found -> exit here
            except IOError:
                print(f"'{fpath}'" + " not found")
                sys.exit(1)
        elif "Tafel" in self.experiment:
            try:
                data = self.read_tafel()
            #file not found -> exit here
            except IOError:
                print(f"'{fpath}'" + " not found")
                sys.exit(1)
        else:
            print(r"warning! The file %s couldn't be opened." % fpath)
            sys.exit(1)
        return data

