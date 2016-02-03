..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Using path-like objects
=======================

Another of the new features in the version of :demeter:`artemis` is
the ability to make interesting things that are constructed from tools
that :demeter:`feff` provides, but which are not paths in the
traditional sense of being strictly associated with one of the
:file:`feffNNNN.dat` files that comes from a normal execution of
:demeter:`feff`.

Some of these path-like objects are directly associated with a
particular :demeter:`feff` calculation. For example, an SSPath created
on the Path-like tab on the :demeter:`feff` window is created directly
from the scattering potentials from that :demeter:`feff`
calculation. Similarly, a histogram-based path-like object also uses a
particular :demeter:`feff` calculation.

Other path-like objects either have a hidden relationship with a
:demeter:`feff` calculation or none at all. The path from a quick
first shell theory calculation does have a :demeter:`feff` calculation
associated with it, but it is done in a way that the user never
interacts with that calculation. The quick first shell path does not
have an entry in the :demeter:`feff` list on the Main window. An
empirical standard, as the name implies, is derived from data and
therefor is not associated with any :demeter:`feff` calculation.

Although each of these path-like objects derives from a different
place than a typical path, :demeter:`artemis` presents them to the
user identically. Each kind of path-like object is displayed using all
the same controls as a normal path and each is parametered and used in
a fit in the same way.

-  `Information about SSPaths <../feff/pathlike.html#single-scattering-paths>`_

-  Information about histograms (*not written yet*)

-  `Information about the quick first shell theory <../extended/qfs.html>`_

-  `Information about empirical standards <../extended/empirical.html>`_


