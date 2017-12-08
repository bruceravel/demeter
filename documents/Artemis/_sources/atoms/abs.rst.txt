..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Absorption calculations and experimental corrections
====================================================

Included in :demeter:`atoms` is absorption data for the elements from
various sources. Using this and the crystallographic information from
:file:`atoms.inp`, :demeter:`atoms` is able to make several
calculations useful for XAFS analysis. It approximates the absorption
depth and edge step size of the material at the edge energy of the
core atom and estimates three corrections needed for the analysis of
XAFS data. These corrections are the :quoted:`McMaster correction`,
the energy response of the I\ :sub:`0` chamber in a fluorescence
experiment, and the self-absorption of a thick material in a
fluorescence experiment. All of these numbers are written at the top
of the output file. For more information on these calculations see

.. bibliography:: ../artemis.bib
   :filter: journal % "Handbook"
   :list: bullet




Absorption Calculation
----------------------

Proper sample preparation for an XAFS experiment requires knowledge of
the absorption depth and edge step size of the material of interest. The
statistics of data collection can be optimized by choosing the correct
sample thickness. It is also necessary to avoid distortions to the data
due to thickness and large particle size effects.

:demeter:`atoms` calculates the total cross section of the material above the edge
energy of the central atom and divides by the unit cell volume. The
number obtained, |mu|\ :sub:`total`, has units of cm\ :sup:`-1`. Thus, if
``x`` is the thickness of the sample in cm, the x-ray beam passing
through the sample will be attenuated by exp(|mu|\ :sub:`total` \* ``x``).

:demeter:`atoms` also calculates the change in cross section of the
central atom below and above the absorption edge and divides by the
unit cell volume.  This number, |Delta|\ |mu|, multiplied by the
sample thickness in cm gives the approximate edge step in a
transmission experiment.

The density of the material is also reported. This number assumes that
the bulk material will have the same density as the unit cell. It is
included as an aid to sample preparation.


McMaster Correction
-------------------

Typically, XAFS data is normalized to a single number representing the
size of the edge step. While there are compelling reasons to use this
simple normalization, it can introduce an important distortion to the
amplitude of the |chi| (k) extracted from the absorption data. This
distortion comes from energy response of the bare atom absorption of
the central atom. This is poorly approximated away from the edge by a
single number. Because this affects the amplitude of |chi| (k) and not
the phase, it can be corrected by including a Debye-Waller factor and
a fourth cumulant in the analysis of the data. These two
:quoted:`McMaster corrections` are intended to be additive corrections
to any thermal or structural disorder included in the analysis of the
XAFS.

:demeter:`atoms` uses data from Elam to construct the bare atom
absorption for the central atom. :demeter:`atoms` then regresses a
quadratic polynomial in energy to the natural logarithm of the
constructed central atom absorption.  Because energy and
photo-electron wave number are simply related, E is proportional to k\
:sup:`2`, the coefficients of this regression can be related to the
XAFS Debye-Waller factor and fourth cumulant. The coefficient of the
term linear in energy equals ``sigma_MM^2`` and the coefficient of the
quadratic term equals ``4/3 * sigma_MM^4``. The values of
``sigma_MM^2`` and ``sigma_MM^4`` are written at the top of the output
file.

.. bibliography:: ../artemis.bib
   :filter: author % "Elam"
   :list: bullet

For a discussion of the cumulant expansion in EXAFS, see

.. bibliography:: ../artemis.bib
   :filter: author % "Bunker" and year == "1983"
   :list: bullet




I0 Correction
-------------

The response of the I\ :sub:`0` chamber varies with energy during an XAFS
experiment. In a fluorescence experiment, the absorption signal is
obtained by normalizing the I\ :sub:`f` signal by the I\ :sub:`0` signal. There
is no energy response in the I\ :sub:`f` signal since all atoms
fluoresce at set energies. The energy response of I\ :sub:`0` is ignored by this
normalization. At low energies this can be a significant effect. Like
the McMaster correction, this effect attenuates the amplitude of |chi| (k)
and is is well approximated by an additional Debye-Waller factor and
fourth cumulant.

:demeter:`atoms` uses the values of the ``nitrogen``, ``argon`` and
``krypton`` keywords in :file:`atoms.inp` to determine the content of
the I\ :sub:`0` chamber by pressure.  It assumes that the remainder
of the chamber is filled with helium.  It then uses McMaster's data
to construct the energy response of the chamber and regresses a
polynomial to it in the manner described above.  ``sigma_I0^2`` and
are also written at the top of the output file and intended as
additive corrections in the analysis.



Self-Absorption Correction
--------------------------

If the thickness of a sample is large compared to absorption length of
the sample and the absorbing atom is sufficiently concentrated in the
sample, then the amplitude of the |chi| (k) extracted from the data taken on
it in fluorescence will be distorted by self-absorption effects in a way
that is easily estimated. The absorption depth of the material might
vary significantly through the absorption edge and the XAFS wiggles. The
correction for this effect is well approximated as

::

       1 + mu_abs / (mu_background+mu_fluor)

where |mu|\ :sub:`background` is the absorption of the non-resonant atoms
in the material and |mu|\ :sub:`fluo` is the total absorption of the
material at the fluorescent energy of the absorbing atom. :demeter:`atoms`
constructs this function using the McMaster tables then regresses a
polynomial to it in the manner described above. ``sigma_self^2`` and
``sigma_self^4`` are written at the top of the output file and
intended as additive corrections in the analysis. Because the size of
the edge step is affected by self-absorption, the amplitude of
|chi| (k) is attenuated when normalized to the edge step. Since the
amplitude is a measure of S\ :sup:`2`\ :sub:`0`, this is an important
effect. The number reported in :file:`feff.inp` as the amplitude
factor is intended to be a multiplicative correction to the data or to
the measured S\ :sup:`2`\ :sub:`0`.

