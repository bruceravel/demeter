
Feff
====

:demeter:`ifeffit` ships with a free copy of :demeter:`feff`. Although
deep support for :demeter:`feff8` is on the long range list of
objectives for :demeter:`demeter`, currently only :demeter:`feff6` is
well supported. This seems reasonable as :demeter:`demeter` currently
have no special capabilities for XANES or other inner shell
spectroscopy analysis beyond basic, :demeter:`athena`-level
functionality.


.. _fig-feff6:
.. figure:: ../../_images/feff6.png
   :target: ../_images/feff6.png
   :align: center

   This is a rough flow diagram for :demeter:`feff6`. The
   configuration of atoms in the :file:`feff.inp` file is used to
   compute the potentials in the *potph* part of :demeter:`feff6` and
   to find all possible scattering geometries with the cluster in the
   *pathfinder* part. The output files from those two parts,
   :file:`phase.bin` and :file:`paths.dat`, are used by *genfmt* to
   compute the :file:`feffNNNN.dat` files, each of which contains the
   contribution to the EXAFS from an individual scattering
   geometry. The various scattering contributions are then summed by
   *ff2chi* to make the theoretical |chi| (k).


When run outside of :demeter:`demeter`, :demeter:`feff6` is usually
treated as a single program that starts by reading an input file and
ends by writing out :file:`feffNNNN.dat` files containing the
contributions from each individual scattering path. In fact,
:demeter:`feff` runs in five distinct steps:

#. Read the :file:`feff.inp` file

#. Compute the atomic potentials (called *potph* in the internal
   language of the :demeter:`feff` program)

#. Find all possible scattering paths with the cluster defined by the
   :file:`feff.inp` file (*pathfinder*)

#. Using the geometric information from the paths finder and the atomic
   potentials, compute the contribution from each scattering path
   (*genfmt*)

#. Sum the contributions from the scattering paths into a calculated
   |chi| (k) (*ff2chi*)

In :demeter:`ifeffit` and in the older version of :demeter:`artemis`,
we simply drop *ff2chi*.  :demeter:`ifeffit` is a high-functionality
replacement for *ff2chi*. It takes all the contributions computed by
the :demeter:`feff` calculation and adds them up with parameterization
for the path parameters.

That was the only part of :demeter:`feff6` that was unused in old
:demeter:`artemis`.  When you imported a :file:`feff.inp` file into
:demeter:`artemis`, :demeter:`feff6` was run all the way through the
*genfmt* stage. Hidden somewhere out of the way were all the oputput
files from :demeter:`feff`.  This is why old :demeter:`artemis`
project files are so very large. It is because they contain the
:file:`phase.bin` file and possibly hundreds of :file:`feffNNNN.dat`
files -- one for each scattering path computed in each :demeter:`feff`
calculation performed.

:demeter:`feff`, however, does not have to be run this way.  Using the
``CONTROL`` keyword, you can specify which parts of :demeter:`feff`
actually run.  Each of *potph*, *pathfinder*, *genfmt*, and *ff2chi*
can be turned on and off individually, so long as the all the
necessary input information is somehow available.  For example, to run
just *genfmt*, you must somehow have already calculated the
:file:`phase.bin` and :file:`paths.dat` files.

An aside about :demeter:`feff`'s *pathfinder*: it is fast, but is
missing useful features. One missing feature is that, when it
determines which scattering geometries are degenerate (i.e. they
provide the same contributions to the EXAFS), it throws each
degenerate path away. That is, the :file:`feffNNNN.dat` file for the
first coordination shell in an BCC metal tells you the coordinates of
one such scattering atom and it tells you that the degeneracy is 8. It
does not, however, retain the coordinates of the other 7 atoms. The
other shortcoming of the *pathfinder* is that it treats scattering
paths as non-degenerate if their half path lengths differ by 0.00001
|AA| or more. That is, in most cases, a ridiculously tight tolerance
which leads to a substantial proliferation of very similar paths.

OK, back to how :demeter:`feff` is use in :demeter:`artemis`. In the
new :demeter:`artemis`, I take a much more fine-grained approach.
:demeter:`feff` is never run from beginning to end.  When
:demeter:`feff` is run, the *potph* part is run and the resulting
:file:`phase.bin` file is saved.

Then the *pathfinder* is run, but not :demeter:`feff`'s *pathfinder*.
The *pathfinder* has been completely rewritten as part of
:demeter:`demeter` The new *pathfinder* is missing one important
feature. It has no way of doing :demeter:`feff`'s quick and dirty
estimation of path amplitude, the so-called curved-wave importance
factor, thus :demeter:`demeter`'s *pathfinder* does not have that way
of discarding obviously small paths and all higher-order scattering
paths based on that geometry. Also, :demeter:`demeter`'s *pathfinder*
is pretty slow compared to :demeter:`feff`'s. However,
:demeter:`demeter`'s *pathfinder* retains information about all
scattering geometries that contribute to the degeneracy of a path. In
the future, this will allow propagattion of distortions to the
starting structure through all the scattering paths.

Secondly, :demeter:`demeter`'s *pathfinder* introduces something
called :quoted:`fuzzy degeneracy`. This is a configurable parameter
that defines a length scale below which paths of similar length are
considered degenerate. The default is 0.03 |AA|, but can be set as you
wish. Thus paths that differ in length by less than 0.03 |AA| are
considered degenerate and the resulting path is computed at the
average length of the paths that are considered degenerate.

So, the *pathfinder* introduces a number of new features. But the
really powerful bit is how :demeter:`artemis` interacts with
*genfmt*. Basically, *genfmt* is run on demand the first time that the
corresponding :file:`feffNNNN.dat` file is needed (perhaps for a fit,
perhaps for a plot). When the current instance of :demeter:`demeter`
is finished (say, by quitting :demeter:`artemis`) all the
:file:`feffNNNN.dat` files are deleted. The next time you fire up your
program, they will be recalcualted. It turns out that the call to
*genfmt* is so fast that it is better to recompute the
:file:`feffNNNN.dat` files rather than carry them around. Thus
:demeter:`artemis` project files are much, much smaller.  The
:file:`feffNNNN.dat` files are given names based on random strings, so
there is no chance of accidentally over-writing them if you happen to
re-run earlier parts of :demeter:`feff`. The way this on-demand
calcualtion of :file:`feffNNNN.dat` files works is by having
:demeter:`demeter` generate short replacements for the
:file:`paths.dat` file which contain only the single path that you
want to calculate. The :file:`paths.dat` file is deleted immediately
after it is used.

This approach makes it very easy to define interesting abstractions of
paths. For instance, suppose you want to consider the possibility that
one of the atoms in your material is at a position very different from
the examples in the cluster. This approach makes it easy to compute
that. It's called an SSPath.

There are a number of other tricks that this capability will enable,
including things like considering variation in scattering angle of a MS
path or consideration of arbitrary radial distribution functions.

---------------------

**Contents**

.. toctree::
   :maxdepth: 2

   input.rst
   potph.rst
   pathfinder.rst
   intrp.rst
