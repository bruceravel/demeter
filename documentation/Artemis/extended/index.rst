
Extended discussions
====================

This section is a catch-all for topics of data analysis and the
operation of :demeter:`artemis` that simply did not fit in other parts
of this users' guide.


*Topics related to fitting EXAFS data*

 Quick first shell theory
    An in-depth discussion of how the `quick first shell theory
    tool <../extended/qfs.html>`__ works, what it is used for, and how
    it can be misused.

 Characteristic values
    An explanation of the `characteristic
    value <../extended/cv.html>`__, or CV, Data attribute. This is a
    tool for building expressive, flexible, and powerful models for
    multiple data set fitting problems.

 Geometric parametrization of bond length
    A discussion of `parametrizations of bond length <../extended/delr.html>`__.

 Modeling the disorder parameter
    A discussion of `parametrizations of the disorder
    parameter <../extended/ss.html>`__, |sigma|\ :sup:`2`.

 Using constraints and restraints
    A discussion of `model building <../extended/constraints.html>`__ in
    :demeter:`ifeffit` and :demeter:`artemis`.

 Using empirical standards
    A discussion of `the use of empirical
    standards <../extended/empirical.html>`__ is implemented in :demeter:`artemis`.


*Topics related to Feff*

 Unique potentials
    The `Atoms page <../feff/index.html>`__ offers three ways of styling
    the potential indeces of the :demeter:`feff` input data. They are
    `explained <../extended/ipots.html>`__ by example using crystal
    data.

 The pathfinder and fuzzy degeneracy
    An `explanation <../extended/ipots.html>`__ of the pathfinder and of
    the concept of fuzzy degeneracy.

 Handling dopants in Feff calculations
    How `dopants <../extended/dopants.html>`__ can be introduced in to
    :demeter:`feff` calculations and :demeter:`artemis` fitting models.


.. todo:: Pages are needed explaining: (1) Histograms, (2) background
   co-refinement (3) constraints and restraints


----------------



.. toctree::
   :maxdepth: 2

   qfs.rst
   cv.rst
   delr.rst
   ss.rst
   constraints.rst
   bvs.rst
   empirical.rst
   ipots.rst
   fuzzy.rst
   dopants.rst
   fivesix.rst

