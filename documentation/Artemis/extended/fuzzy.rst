`The Artemis Users' Guide <../index.html>`__

+--------------------------------------+--------------------------------------+
| «\ `DEMETER <http://bruceravel.githu |
| b.io/demeter/>`__\ »                 |
|                                      |
| «\ `IFEFFIT <https://github.com/newv |
| ille/ifeffit>`__\ »                  |
|                                      |
| «\ `xafs.org <http://xafs.org>`__\ » |
|                                      |
| Back: `Unique                        |
| potentials <../extended/ipots.html>` |
| __                                   |
|       Up: `Extended                  |
| topics <../extended/index.html>`__   |
|    Next: `Handling                   |
| dopants <../extended/dopants.html>`_ |
| _                                    |
+--------------------------------------+--------------------------------------+

| |[Artemis logo]|
|  `Home <../index.html>`__
|  `Introduction <../intro.html>`__
|  `Starting Artemis <../startup/index.html>`__
|  `The Data window <../data.html>`__
|  `The Atoms/Feff window <../feff/index.html>`__
|  `The Path page <../path/index.html>`__
|  `The GDS window <../gds.html>`__
|  `Running a fit <../fit/index.html>`__
|  `The Plot window <../plot/index.html>`__
|  `The Log & Journal windows <../logjournal.html>`__
|  `The History window <../history.html>`__
|  `Monitoring things <../monitor.html>`__
|  `Managing preferences <../prefs.html>`__
|  `Worked examples <../examples/index.html>`__
|  `Crystallography for EXAFS <../atoms/index.html>`__
|  `Extended topics <../extended/index.html>`__
|   ↪ `Quick first shell theory <../extended/qfs.html>`__
|   ↪ `Characteristic value <../extended/cv.html>`__
|   ↪ `Modeling bond length <../extended/delr.html>`__
|   ↪ `Modeling disorder <../extended/ss.html>`__
|   ↪ `Constraints and restraints <../extended/constraints.html>`__
|   ↪ `Bond valence sums <../extended/bvs.html>`__
|   ↪ `Using empirical standards <../extended/empirical.html>`__
|   ↪ `Unique potentials <../extended/ipots.html>`__
|   ↪ Fuzzy degeneracy
|   ↪ `Handling dopants <../extended/dopants.html>`__
|   ↪ `5 and 6 legged paths <../extended/fivesix.html>`__

The pathfinder and fuzzy degeneracy
===================================

--------------

 

How the path finder works
-------------------------

Given a list of atomic coordinates for a cluster of atoms:

|pathfinder.png| A heap is a tree-shaped data structure. Each node is
guaranteed to represent a shorter path length than all nodes below it.
The top node is, thus, guaranteed to be the shortest path. See S.I.
Zabinsky, et al., *Phys. Rev.*, **B66:22**, (1995) p. 2995-3009\ `(DOI:
10.1103/PhysRevB.52.2995) <http://dx.doi.org/10.1103/PhysRevB.52.2995>`__
for more details.

#. Find all paths (0i0), i≠0 in the cluster. These paths are represented
   by the two-leg diagram to the right. Put each such path in a heap.

#. For each such path, add a leg with j≠i, j≠0. Put all (0ij0) in the
   heap. These paths are represented by the three-leg diagram to the
   right.

#. Up to some order of scattering, populate the heap with (0i...x0).

#. Test each path (0i...x0) for magnitude. If small, discard and do not
   consider any (0i...xy0).

#. Use up all atoms in the cluster and up to some order of scattering
   (FEFF's default is 7 legs).

|heap.png| Construct the path list by repeatedly pulling the top path
from the heap until the heap is empty. When the top node is removed, the
remaining nodes rearrange themselves such that heap retains the property
that each node represents a shorter path than all those below it.

The resulting path list is guaranteed to be sorted by increasing path
length. The list is then examined to find “degenerate” paths. Degenerate
paths are ones that contribute identically to the EXAFS. A simple
example owuld be the single scattering paths from the various atoms in
the first coordination shell. Since each atom is the same distance away
from the absorber, each contributes identically to the EXAFS. Thus these
paths are degenerate. After being screened for degeneracy, the path list
is presented to the user.

--------------

 

The pathfinder in Feff and Artemis
----------------------------------

One of the features of ARTEMIS is a rewrite of FEFF's pathfinder.

The new path finder has two huge advantages over FEFF's:

#. User configurable fuzzy degeneracy. FEFF considers paths that differ
   in length by 0.00001 Å to be non-degenerate. ARTEMIS can group
   together these nearly degenerate paths.

#. The scattering geometries of the degenerate paths are stored and are
   available for use and examination. FEFF discards the details of the
   degenerate paths.

The first point – the use of fuzzy degneracy – is the topic of this
section.

FEFF's path finder, however, has its advantages over ARTEMIS':

#. As it is written in a compiled language, it is considerably faster.
   Fortunately, the path finder does not need to be run very often.

#. FEFF uses its fast plane wave calculation to approximate the
   importance of path. Low importance paths can be removed from
   consideration, as can all higher order paths built from that path.
   ARTEMIS does not have access to the plane wave calculation, so it
   must consider rather more paths than FEFF's pathfinder. ARTEMIS
   relies instead on some simple heuristics to trim the tree of paths.

#. FEFF's path finder considers up to seven-legged paths. ARTEMIS
   currently stops at four-legged paths. This could be fixed in ARTEMIS,
   but without FEFF's plane wave approximation, the cost of computing so
   many paths would be prohibitive. In any case, it is rather unusual to
   need more than four-legged paths in an EXAFS analysis. (Cubic metals
   analyzed beyond about 6 Å and cyanide bridged structures like
   prussian blue are two examples.)

| |To do!| ARTEMIS' path finder does not currently handle polarization
and ellipticity. So that's another advantage at the moment for FEFF's
path finder.
|  As for the speed issue, I have some ideas for improving ARTEMIS'
performance. While it will never be as fast as FEFF, I should be able to
close the gap somewhat.

--------------

 

An example of using fuzzy degeneracy
------------------------------------

As the path finder organizes all the scattering geometries it finds
among the atoms in the input atoms list, it will make a fuzzy comparison
to sort the paths into nearly-degenerate bins. That is, all paths whose
lengths are within a small margin will be considered degenerate. The
width of this bin is set by the ♦Pathfinder → fuzz preference.

Consider this feff.inp file (made from `this crystal
data <https://raw.github.com/bruceravel/XAS-Education/master/Examples/Xtal/PbFe12O19.inp>`__):

::

     TITLE magnetoplumbite  PbFe_12O_19

     HOLE      4   1.0   * FYI: (Pb L3 edge @ 13035 eV, second number is S0^2)
     *         mphase,mpath,mfeff,mchi
     CONTROL   1      1     1     1
     PRINT     1      0     0     0

     RMAX      5.0
     *NLEG      4

     POTENTIALS
      * ipot   Z      tag
         0     82     Pb        
         1     82     Pb        
         2     26     Fe        
         3     8      O         


     ATOMS                  * this list contains 84 atoms
     *   x          y          z     ipot tag           distance
        0.00000    0.00000    0.00000  0  Pb1           0.00000
        1.65468    0.00003    2.30070  3  O.1           2.83394
       -0.82737   -1.43298    2.30070  3  O.1           2.83394
        1.65468    0.00003   -2.30070  3  O.1           2.83394
       -0.82737   -1.43298   -2.30070  3  O.1           2.83394
       -0.82737    1.43304    2.30070  3  O.1           2.83397
       -0.82737    1.43304   -2.30070  3  O.1           2.83397
        2.63123   -1.31552    0.00000  3  O.2           2.94176
       -0.17634   -2.93647    0.00000  3  O.2           2.94176
        2.63123    1.31558    0.00000  3  O.2           2.94179
       -2.45494   -1.62092    0.00000  3  O.2           2.94179
       -2.45494    1.62098    0.00000  3  O.2           2.94182
       -0.17634    2.93653    0.00000  3  O.2           2.94182
        1.69537   -2.93647    0.00000  2  Fe2.1         3.39074
       -3.39080    0.00003    0.00000  2  Fe2.1         3.39079
        1.69537    2.93653    0.00000  2  Fe2.1         3.39079
        0.83581   -1.44767    3.24399  2  Fe5.1         3.64935
        0.83581   -1.44767   -3.24399  2  Fe5.1         3.64935
       -1.67167    0.00003    3.24399  2  Fe5.1         3.64937
        0.83581    1.44772    3.24399  2  Fe5.1         3.64937
       -1.67167    0.00003   -3.24399  2  Fe5.1         3.64937
        0.83581    1.44772   -3.24399  2  Fe5.1         3.64937
        3.39074    0.00006    1.38042  2  Fe4.1         3.66097
       -1.69542   -2.93644    1.38042  2  Fe4.1         3.66097
        3.39074    0.00006   -1.38042  2  Fe4.1         3.66097
       -1.69542   -2.93644   -1.38042  2  Fe4.1         3.66097
       -1.69542    2.93656    1.38042  2  Fe4.1         3.66107
       -1.69542    2.93656   -1.38042  2  Fe4.1         3.66107
                ... (more atoms follow)
     END

Using the default ♦Pathfinder → fuzz parameter of 0.03 Å, will give
these paths. Note that the ``Fe4`` and ``Fe5`` scatterers, which differ
by about 0.11 Å, get merged into a single scattering path. This path has
a value of R\ :sub:`eff` that is the average of the constituent paths
and a degenaracy that is the sum of the constituent paths.

::

    #     degen   Reff       scattering path    I   Rank  legs   type
     0001   6    2.834  ----  @ O.1    @        2  100.00  2  single scattering
     0002   6    2.942  ----  @ O.2    @        2   89.88  2  single scattering
     0003   3    3.391  ----  @ Fe2.1  @        2   34.83  2  single scattering
     0004  12    3.655  ----  @ Fe5.1  @        2  100.00  2  single scattering

Resetting the ♦Pathfinder → fuzz to 0.01 separates those two nearly
degenerate paths into separate scattering paths.

::

    #     degen   Reff       scattering path    I   Rank  legs   type
     0001   6    2.834  ----  @ O.1    @        2  100.00  2  single scattering
     0002   6    2.942  ----  @ O.2    @        2   89.88  2  single scattering
     0003   3    3.391  ----  @ Fe2.1  @        2   34.83  2  single scattering
     0004   6    3.649  ----  @ Fe5.1  @        2   57.63  2  single scattering
     0005   6    3.661  ----  @ Fe4.1  @        2   57.15  2  single scattering

To make the pathfinder neglect fuzzy degeneracy, thus behaving like
FEFF's pathfinder, set ♦Pathfinder → fuzz to 0.

| 

--------------

--------------

| DEMETER is copyright © 2009-2015 Bruce Ravel — This document is
copyright © 2015 Bruce Ravel

|image4|    

| This document is licensed under `The Creative Commons
Attribution-ShareAlike
License <http://creativecommons.org/licenses/by-sa/3.0/>`__.
|  If DEMETER and this document are useful to you, please consider
`supporting The Creative
Commons <http://creativecommons.org/support/>`__.

.. |[Artemis logo]| image:: ../../images/Artemis_logo.jpg
   :target: ../diana.html
.. |pathfinder.png| image:: ../../images/pathfinder.png
   :target: ../../images/pathfinder.png
.. |heap.png| image:: ../../images/heap.png
   :target: ../../images/heap.png
.. |To do!| image:: ../../images/todo.png
.. |image4| image:: ../../images/somerights20.png
   :target: http://creativecommons.org/licenses/by-sa/3.0/
