..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Aggregate Feff calculation
==========================

If crystal data has two or more inequivalent sites occupied by the same
kind of atom, some additional functionality is enabled when one of the
inequivalent sites is selected as the absorber. As you can see in the
following screenshot, the :button:`Aggregate,light` button is available, as are
controls for setting the `fuzzy degeneracy <../extended/fuzzy.html>`__
parameters.

.. _fig-feffzirconolite:
.. figure:: ../../_images/feff-zirconolite.png
   :target: ../_images/feff-zirconolite.png
   :align: center

   Crystal data for CaZrTi\ :sub:`2`\ O\ :sub:`7` with a Ti atom selected,
   enabling the aggregate calculation controls.

In the aggregate :demeter:`feff` calculation, the path finder is run
for each inequivalent position containing the same central atom. The
path lists are merged together, weighted by fractional population of
the site in the unit cell, before running the check for `fuzzy
degeneracy <../extended/fuzzy.html>`__. The weighting by population
fraction means that a bin of paths can be occupied by a non-integer
number of atoms.

In the example of CaZrTi\ :sub:`2`\ O\ :sub:`7`, there are three Ti
sites. The are 8 :guilabel:`Ti1` atoms in the unit cell and 4 each of
:guilabel:`Ti2` and :guilabel:`Ti3`.  Thus half the Ti atoms are from
site 1 and a quarter each from sites 2 and 3. Each Ti site is
surrounded by 6 oxygen atoms at a variety of
distances. :guilabel:`Ti1` has O atoms at 1.843 |AA|, 1.880 |AA|,
1.927 |AA|, 1.987 |AA|, 2.0007 |AA|, and 2.023 |AA|. :guilabel:`Ti2`
has 2 O atoms at each of 1.786 |AA|, 2.050 |AA|, 2.498 |AA|.
:guilabel:`Ti3` has 2 O atoms at each of 1.975 |AA|, 1.877 |AA|, 1.975
|AA|. In short, the Ti K edge of CaZrTi\ :sub:`2`\ O\ :sub:`7` is a
mess!

Using a bin size of 0.1 |AA| and combining the three sites together
weighted by their fractional populations in the unit cell, we end up
with 4 distances. There are 2.5 O atoms at 1.852 |AA|, 2.5 O atoms at
1.984 |AA|, 0.5 O atoms at 2.050 |AA|, and 0.5 O atoms at 2.498 |AA|.

Instead of having to parameterize 12 different Ti-O distances, keeping
track of fractional populations when parameterizing the S\ :sup:`2`\
:sub:`0` values for each path, the aggregate :demeter:`feff`
calculation requires managing only 4 paths.

For a complete discussion of the the aggregate :demeter:`feff`
calculation, see

.. bibliography:: ../artemis.bib
   :filter: author % "Ravel" and year == '2014'
   :list: bullet
