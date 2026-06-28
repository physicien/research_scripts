# -*- coding: utf-8 -*-
"""
Code that generates beDeft-compatible files containing the xyz coordinates of a
molecular system displaced in the positive and negative directions along a
specified normal mode. These files are required to perform the numerical
evaluation of derivatives using a central-difference scheme.
"""

import numpy as np
import argparse
import cclib
import periodictable

# Create parser
parser = argparse.ArgumentParser()

parser.add_argument("molecule",
                    type=str,
                    help='name of the molecule'
                    )

parser.add_argument('-m','--mode',
                    type=int,
                    default=0,
                    help='label of the normal mode'
                    )

parser.add_argument('-d','--delta',
                    type=float,
                    default=0.0,
                    help='delta displacement in angstrom'
                    )

# Parse the arguments
args = parser.parse_args()

# GLOBAL VARIABLES
molecule = args.molecule
filename = f"FRQ_{molecule}_f.out"
imode = args.mode
delta = args.delta

# Functions
def get_displacement(delta, mode, freq_cm1, n_quanta=0):
    """
    Computes a Cartesian displacement employed in the central-difference scheme.

    Parameters
    ----------
    delta : float
        Magnitude of the displacement, expressed in units of a typical
        phonon-averaged displacement.
    mode : array-like, shape (M, N, 3)
        Normal modes of the molecule, where M is the number of normal modes
        and N is the number of atoms. Commonly, M = 3N - 6 (or 3N - 5 for
        linear molecules).
    freq_cm1 : float
        Normal-mode frequency in cm-1.
    n_quanta : int, optional
        Vibrational quantum number. The default value is 0.

    Returns
    -------
    displacement : array-like, shape (M, N, 3)
        The resulting Cartesian displacement (in Angstrom).

    """
    # hbar in J*s
    hbar = 1.054571818e-34
    # Speed of light in cm/s
    c = 2.99792458e10
    # Mass of 1 AMU in kg
    amu_kg = 1.66053906892e-27
    
    # Characteristic oscillator length (in Angstroms)
    # b = sqrt(hbar / (2 * pi * nu * c))
    # b[ang] = C / sqrt(nu[cm-1])
    C = np.sqrt(hbar/(2*np.pi*c*amu_kg * 2 * 12.01))*1e10
    b = C/np.sqrt(freq_cm1)

    # Scale for n quantas (turning point of the harmonic oscillator)
    scale = np.sqrt(2 * n_quanta + 1) * b

    # Displacement
    displacement = delta * scale * (mode / np.linalg.norm(mode))
    return displacement


def inputwrite(system, atoms, coordinates, fragment=None):
    """
    Writes the xyz coordinates of a molecular fragment in a format compatible
    with beDeft.

    Parameters
    ----------
    system : str
        Name of the molecular system.
    atoms : array-like, shape (N,)
        Chemical element corresponding to each atom in the molecule.
    coordinates : array-like, shape (N,3)
        Cartesian coordinates of the atoms in the molecule.
    fragment : str, optional
        Tag used to alter the output filename for different fragments of
        the same system. If `None` (default), the filename remains unchanged.

    Returns
    -------
    None

    """
    if fragment is not None:
        name = system + "_" + fragment
    else:
        name = system
    fname = name + ".inp"
    with open(fname, "w", encoding="utf-8") as f:
        # headers
        f.write("[[\n")
        f.write("<system {}>\n".format(system))
        f.write('<fragment name="{}">\n'.format(name))
        f.write('<atoms unit="angstrom">\n')

        # atoms
        for i, atom in enumerate(atoms):
            f.write(f"{atom}")
            for coor in coordinates[i]:
                f.write(f"{coor:>20.10f}")
            f.write("\n")

        # footers
        f.write("</atoms>\n")
        f.write("</fragment>\n")
        f.write("</system>\n")
        f.write("]]")

# Parser
file = cclib.parser.ccopen(filename)
moldata = file.parse()

labels = moldata.atomnos
elements = np.array([periodictable.elements[l] for l in labels])
coords = np.asarray(moldata.atomcoords[-1]).reshape(-1,3)

modes = moldata.vibdisps
freqs_cm1 = moldata.vibfreqs

mode = modes[imode]
freq_cm1 = freqs_cm1[imode]

displacement = get_displacement(delta, mode, freq_cm1)

# No displacement
inputwrite(molecule, elements, coords)

# Positive displacement
frag_p = f"{imode:0>3}_p"
dp = coords + displacement
inputwrite(molecule, elements, dp, fragment=frag_p)

# Negative displacement
frag_m = f"{imode:0>3}_m"
dn = coords - displacement
inputwrite(molecule, elements, dn, fragment=frag_m)
