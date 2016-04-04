..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


.. role:: blueatom
.. role:: redatom
.. role:: greenatom
.. role:: yellowatom
.. role:: brownatom
.. role:: pinkatom

Fuzzy degeneracy
================



How the path finder works
-------------------------

Given a list of atomic coordinates for a cluster of atoms, multiple
scattering paths can be found from those atoms.

.. _fig-pathfinder:
.. figure:: ../../_images/pathfinder.png
   :target: ../_images/pathfinder.png
   :align: center

   Constructing generations of multiple scattering paths.

A `heap <https://en.wikipedia.org/wiki/Heap_%28data_structure%29>`_ is
a tree-shaped data structure. Each node is guaranteed to represent a
shorter path length than all nodes below it.  The top node is, thus,
guaranteed to be the shortest path.  For more details, see


.. bibliography:: ../artemis.bib
   :filter: author % 'Zabinsky'
   :list: bullet


#. Find all paths (:blueatom:`0` :redatom:`i` :blueatom:`0`),
   :redatom:`i` |neq| :blueatom:`0` in the cluster. These paths are
   represented by the two-leg diagram in :numref:`Fig. %s
   <fig-pathfinder>`.  Put each such path in a heap.

#. For each such path, add a leg with :yellowatom:`j` |neq|
   :redatom:`i` and :yellowatom:`j` |neq| :blueatom:`0`. Put all
   (:blueatom:`0` :redatom:`i` :yellowatom:`j` :blueatom:`0`) in the
   heap. These paths are represented by the three-leg diagram in
   :numref:`Fig. %s <fig-pathfinder>`.

#. Up to some order of scattering, populate the heap with
   (:blueatom:`0` :redatom:`i` ... x :blueatom:`0`)

#. Test each path (:blueatom:`0` :redatom:`i` ... x :blueatom:`0`)
   for magnitude. If small, discard
   and do not consider any 
   (:blueatom:`0` :redatom:`i` ... x y :blueatom:`0`)

#. Use up all atoms in the cluster and up to some order of scattering
   (:demeter:`feff`'s default is 7 legs).



.. _fig-heap:
.. figure:: ../../_images/heap.png
   :target: ../_images/heap.png
   :align: center

   A schematic of a heap.


Construct the path list by repeatedly pulling the top path from the
heap until the heap is empty. When the top node is removed, the
remaining nodes rearrange themselves such that heap retains the
property that each node represents a shorter path than all those below
it.

The resulting path list is guaranteed to be sorted by increasing path
length. The list is then examined to find :quoted:`degenerate`
paths. Degenerate paths are ones that contribute identically to the
EXAFS. A simple example would be the single scattering paths from the
various atoms in the first coordination shell. Since each atom is the
same distance away from the absorber, each contributes identically to
the EXAFS. Thus these paths are degenerate. After being screened for
degeneracy, the path list is presented to the user.


The pathfinder in Feff and Artemis
----------------------------------

One of the features of :demeter:`artemis` is a rewrite of :demeter:`feff`'s pathfinder.

The new path finder has two huge advantages over :demeter:`feff`'s:

#. User configurable fuzzy degeneracy. :demeter:`feff` considers paths
   that differ in length by 0.00001 |AA| to be non-degenerate.
   :demeter:`artemis` can group together these nearly degenerate
   paths.

#. The scattering geometries of the degenerate paths are stored and
   are available for use and examination.  :demeter:`feff` discards
   the details of the degenerate paths.

The first point |nd| the use of fuzzy degeneracy |nd| is the topic of
this section.

:demeter:`feff`'s path finder, however, has its advantages over
:demeter:`artemis`':

#. As it is written in a compiled language, it is considerably faster.
   Fortunately, the path finder does not need to be run very often.

#. :demeter:`feff` uses its fast plane wave calculation to approximate
   the importance of path. Low importance paths can be removed from
   consideration, as can all higher order paths built from that path.
   :demeter:`artemis` does not have access to the plane wave
   calculation, so it must consider rather more paths than
   :demeter:`feff`'s pathfinder.  :demeter:`artemis` relies instead on
   some simple heuristics to trim the tree of paths.

#. :demeter:`feff`'s path finder considers up to seven-legged
   paths. :demeter:`artemis` can do five- and six-legged paths, but it
   is slow.  In any case, it is rather unusual to need more than
   four-legged paths in an EXAFS analysis.  (Cubic metals analyzed
   beyond about 6 |AA| and cyanide bridged structures like prussian
   blue are two examples.)

.. todo:: :demeter:`artemis`' path finder does not currently handle
   ellipticity.  So that's another advantage at the moment for
   :demeter:`feff`'s path finder.



An example of using fuzzy degeneracy
------------------------------------

As the path finder organizes all the scattering geometries it finds
among the atoms in the input atoms list, it will make a fuzzy
comparison to sort the paths into nearly-degenerate bins. That is, all
paths whose lengths are within a small margin will be considered
degenerate. The width of this bin is set by the
:configparam:`Pathfinder,fuzz` preference.

Consider this :file:`feff.inp` file (made from `this crystal data
<https://raw.github.com/bruceravel/XAS-Education/master/Examples/Xtal/PbFe12O19.inp>`__):

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

Using the default :configparam:`Pathfinder,fuzz` parameter of 0.03
|AA|, will give these paths. Note that the ``Fe4`` and ``Fe5``
scatterers, which differ by about 0.11 |AA|, get merged into a single
scattering path. This path has a value of R\ :sub:`eff` that is the
average of the constituent paths and a degenaracy that is the sum of
the constituent paths.

::

    #     degen   Reff       scattering path    I   Rank  legs   type
     0001   6    2.834  ----  @ O.1    @        2  100.00  2  single scattering
     0002   6    2.942  ----  @ O.2    @        2   89.88  2  single scattering
     0003   3    3.391  ----  @ Fe2.1  @        2   34.83  2  single scattering
     0004  12    3.655  ----  @ Fe5.1  @        2  100.00  2  single scattering

Resetting the :configparam:`Pathfinder,fuzz` to 0.01 separates those
two nearly degenerate paths into separate scattering paths.

::

    #     degen   Reff       scattering path    I   Rank  legs   type
     0001   6    2.834  ----  @ O.1    @        2  100.00  2  single scattering
     0002   6    2.942  ----  @ O.2    @        2   89.88  2  single scattering
     0003   3    3.391  ----  @ Fe2.1  @        2   34.83  2  single scattering
     0004   6    3.649  ----  @ Fe5.1  @        2   57.63  2  single scattering
     0005   6    3.661  ----  @ Fe4.1  @        2   57.15  2  single scattering

To make the pathfinder neglect fuzzy degeneracy, thus behaving like
:demeter:`feff`'s pathfinder, set :configparam:`Pathfinder,fuzz` to 0.

Fuzzy degeneracy is discussed in

.. bibliography:: ../artemis.bib
   :filter: author % "Ravel" and year == '2014'
   :list: bullet
