..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Path-like objects
=================

:demeter:`demeter` offers a number of specialized objects that are
extensions of the concept of a Path. Each of these can be treated in
many ways just like a normal Path object |nd| all of them can be
plotted in the normal manner and most of them can be used as part of a
fitting model.  However, each encapsolates a useful concept and offers
a bit of high-level functionality beyond the normal use of
:demeter:`feff` and :demeter:`ifeffit`.

The different kinds of path-like objects are:

**VPath**
    A :quoted:`virtual path` is a collection of actual paths that are summed
    together before plotting. A VPath is only a visualisation tool and
    cannot be part of a fit.
**FSPath**
    A :quoted:`first shell path` is a tool for modeling first shell data with
    one single scattering path.
**FPath**
    A :quoted:`filtered path` is created from |chi| (k) data and can be used as
    fitting standard. This can be used to make an empirical fitting
    standard from measured |chi| (k) data. It has also been used to condense
    the contributions from a histogram representing structural disorder
    into a single path-like object.
**SSPath**
    A :quoted:`single scattering path` uses one scattering potential from an
    existing :demeter:`feff` calculation to make a single scattering path at an
    arbitrary distance.
**MSPath**
    A :quoted:`multiple scattering path` uses one or more scattering potentials
    from an existing :demeter:`feff` calculation to make a multiple scattering path
    from an arbitrary collection of atoms.
**ThreeBody**
    A :quoted:`three-body path` uses one or more scattering potentials from an
    existing :demeter:`feff` calculation to make a double and a triple scattering
    path from an arrangement of three atoms.
**Forward**
    A forward path is a tool for modeling the effect of changing
    scattering angle on a collection of three atoms in a nearly
    collinear arrangement. This includes the contribution for the triple
    scattering path and a set of double scattering paths which are used
    to do a interpolative approximation of the effect of changing
    scattering angle on the double scattering path.
**StructuralUnit**
    A :quoted:`structural unit` is a collection of paths, path-like
    objects, and GDS objects that represent a structural moiety in a
    fit.  The idea is that a structural unit can be incorporated into
    a fit to represent some aspect of the structural model.

.. note:: MSPath, ThreeBody, Forward, and StructuralUnit objects have not yet been implemented.

---------------------

**Contents**

.. toctree::
   :maxdepth: 2

   vpath.rst
   fspath.rst
   fpath.rst
   sspath.rst
   mspath.rst
   threebody.rst
   forward.rst
   su.rst
