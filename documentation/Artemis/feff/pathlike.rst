..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


The Path-like tab
=================

One of the powerful features in :demeter:`artemis` is the ability to
define :quoted:`path-like` objects. A path-like object is one which
can be treated like a normal path from :demeter:`feff`. It can be used
in a fit and it can be plotted.  It is not, however, the result of a
normal :demeter:`feff` calculation. Instead, :demeter:`feff` has been
run in some special way to generate a theoretical |chi| (k) spectrum
for something different from all the items listed on the Paths tab.

:demeter:`artemis` defines a number of kinds of path-like
objects. Controls for generating these things are divided into
different pages accessible by the menu at the top of the Path-like
tab. The first item in that menu is for defining :guilabel:`SSPaths`.

.. _fig-feffpathlike:
.. figure:: ../../_images/feff-pathlike.png
   :target: ../_images/feff-pathlike.png
   :align: center

   The Pathlike tab.


Single Scattering Paths
-----------------------

The concept of a :quoted:`Single Scattering Path` (or
:quoted:`SSPath`) is that it uses the potentials from a
:demeter:`feff` calculation to compute the single scattering
contribution from an atom that exists in that :demeter:`feff`
calculation but at a distance not represented in the list of cartesian
coordinates.


.. _fig-feffplotss:
.. figure:: ../../_images/feff-plotss.png
   :target: ../_images/feff-plotss.png
   :align: center

   Plot of a path-like object.


In the example shown, a :demeter:`feff` calculation has been run
on LaCoO\ :sub:`3`, a trigonal perovskite-like material with 6 oxygen
scatterers at 1.93 |AA|, 8 La scatterers at 3.28 |AA| or 3.34 |AA|, and 6 Co
scatterers at 3.83 |AA|.

Suppose we had some reason to wonder what a Co scatterer at a distance
of 3 |AA| would look like in a fit. (For example, we might suspect
that some phase segregation happened during synthesis, resulting in
some CoO.) In that case, the distance on the :guilabel:`SSPath` page
would be set to 3.0 |AA| and the Co scatterer would be selected from
the group of radio buttons.  This group of radio buttons corresponds
to the list of unique potentials in the input data for
:demeter:`feff`.

The method for associating this :guilabel:`SSPath` with data will be
explained in the `next chapter <../path/index.html>`__. For now, we
simply jump ahead and compare the normal Co scatterer at 3.83 |AA|
(blue) with the SSPath computed at 3 |AA| (red).

Use of :guilabel:`SSPath` for modeling scatterers at such a long
distance is much superior to using a `quick first shell theory
<../path/pathlike.html>`__. The advantage of this approach is that it
uses well constructed scattering potentials – i.e. potentials from a
real structure – to make the special path. Using the quick first shell
technique on a path this long results in poorly constructed
potentials. This is explained in detail in `the extended discussions
chapter <../extended/qfs.html>`__.

The SSPath is discussed in

.. bibliography:: ../artemis.bib
   :filter: title % "Muffin"
   :list: bullet



FSPaths
-------

Model the effect of variable forward scattering angle in nearly
collinear multiple scattering paths.

.. todo:: FSPaths have not yet been implemented.



Histogram paths
---------------

.. todo:: Document the histogram system.

