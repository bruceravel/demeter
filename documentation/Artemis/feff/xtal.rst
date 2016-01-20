..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Crystal data
============

The crystal cell data |nd| including lattice constants and angles, the
space group symbol, and the elements of the shift vector |nd| are placed
in text boxes for easy editing. The coordinates of the unique sites
are listed in the grid at the bottom of the window. The absorber is
chosen by clicking one of the boxes on the :guilabel:`Core` column.

Remember that :demeter:`feff` considers numbers with 5 digits of
precision after the decimal point. ``0.333`` is not the same thing as
``0.33333``. You may, however, enter things like ``1/3`` and avoid the
precision issue entirely.

As a new feature compared to earlier versions of :demeter:`atoms`,
there are two radial distances. The cluster size determines the extent
of the cluster expanded into the feff.inp. This should usually be set
to something rather large, 9 |AA| is often a good default.  This
probably (but not always!) assures that the cluster in the
:file:`feff.inp` file is adequately large to include all unique
potentials and has all atom types sufficiently well bounded that the
muffin tin potentials are likely to be be computed reasonably well.

The second distance will set the value of ``RMAX`` in the
:file:`feff.inp` file.  In general, you do not want this to be much
larger than the extent of the data you intend to analyze. 5 |AA| or 6
|AA| is usually the largest sensible value for longest path. The
reason for this is that the pathfinder part of :demeter:`feff` has
been rewritten for this version of :demeter:`artemis`.  While the new
pathfinder implementation offers a number of useful new features, it
is substantially slower than :demeter:`feff`'s native pathfinder. In
any case, there is no benefit to computing paths that you will never
use in your fit.

The absorption edge for the calculation is chosen from the menu to the
left of the lattice constant area. This is usually determined from the
input data, but may need to be explicitly selected. If not specified
in the :file:`atoms.inp` file, the edge will be set to K for element
lighter than Ce (Z=58), and to L\ :sub:`III` for heavier elements.

The style menu is another new feature in this version of
:demeter:`atoms`. It is used to set how the list of unique potentials
is determined from the elements in the atoms list. The choices are

 **elements**
    Each unique element species is assigned a potential number.
 **tags**
    Each unique tag is assigned a potential number.
 **sites**
    Each crystallographic site is assigned a potential number.

Remember that :demeter:`feff` only allows for 7 unique potentials
other than the absorber. The tags and sites options can often result
in more than 7 potnatials, which will result in an unrunnable
:file:`feff.inp` file. Specifying unique potentials by tags is a good
way of differentiating between dissimilar atoms of the same
species. For example, in an oxygenyl species, it is often useful to
give the axial oxygen atoms a different potential from the remaining
oxygens by using the tags option.

Here is an example of an :file:`atoms.inp` file for sodium uranyl
acetate, which contains two very short axial oxygen atoms double
bonded to the uranium atoms at about 1.8 |AA| and a number of
equatorial oxygen atoms at a much longer distance. The axial and
equatorial oxygen positions are distinguished by their tags and will
given separate unique potentials when using the tags style.

::

    title        Templeton et al.
    title        Redetermination and Absolute configuration of Sodium Uranyl(VI) triacetate.
    title        Acta Cryst 1985 C41 1439-1441
    space = P 21 3
    a =   10.6890        b =      10.6890        c =      10.6890
    alpha =       90.0   beta =   90.0   gamma =  90.0
    core =       U       edge =  L3
    atoms
    ! elem   x          y          z       tag        occ
      U     0.42940    0.42940    0.42940  U             1.00000
      Na    0.82860    0.82860    0.82860  Na            1.00000
      O     0.33430    0.33430    0.33430  Oax           1.00000
      O     0.52420    0.52420    0.52420  Oax           1.00000
      O     0.38340    0.29450    0.61100  Oeq           1.00000
      O     0.54640    0.24430    0.50070  Oeq           1.00000
      C     0.47860    0.22600    0.59500  C             1.00000
      C     0.50880    0.12400    0.68620  C             1.00000

The assignment of potential indeces is explained in detail and with
examples in `a later chapter <../extended/ipots.html>`__.


Polarization
------------

A :demeter:`feff` calculation considering linear polarization can be
triggered by setting one or more non-zero values for the polarization
vector.

This vector sets the value of the ``POLARIZATION`` keyword in the
resulting :file:`feff.inp`. The value written in the :file:`feff.inp`
file is the value that will be used in the pathfinder and when
computing the path contributions. That is, if you edit the
``POLARIZATION`` in the :file:`feff.inp` file, the edited value will
take precedence over the value specified here.

.. caution:: :demeter:`feff`'s ``ELLIPTICITY`` keyword is not
   supported at this time.  That means the trick of modeling
   :quoted:`polarization in the plane` is not yet supported by
   :demeter:`artemis`.


