..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


SSPath object
=============

The SSPath, or :quoted:`single scattering path`, is, like the FSPath,
derived from the Path object and so can be used just like a Path in a
fit or a plot. Unlike a Path object, which is associated with a
particular scattering geometry from the cluster of atoms used in the
:demeter:`feff` calculation, the SSPath is a generalized single
scattering path computed using a particular scattering potential from
the :demeter:`feff` calculation, but with the scattering atom in an
arbitrary location and at a specified distance.

The problem this is intended to solve is one for which the
:demeter:`feff` calculation is only an approximation of the actual
structure. In this case, one purpose of the EXAFS analysis is to
determine the extent to which the measured structure differs from the
model structure. The paths used in the fit are parameterized to
somehow determine these differences.

Sometimes, in the course of pursuing the analysis project, it is useful
to examine the prospect of of a particular scattering atom at a distance
that does not exist in the model structure. In practice and without
DEMETER, this is kind of tricky. You must either find a different model
structure which does have the desired atom at approximately the desired
distance or have detailed knowledge of the inner workings of FEFF to
know how to generate theory for that trial scatterer.

The SSPath object makes this data analysis trick very easy. In an
existing :demeter:`feff` calculation and its associated Feff object, a
set of scattering potentials have been defined and calculated. In the
:file:`feff.inp` file, these are the ``ipot``\ s, or unique potential
indices, in the ``POTENTIALS`` list.

To define an SSPath, you must specify the Feff object, the potential
index of the desired scatterer, and the distance.  Here is the SSPath
used in the example of the `uranyl ion in
solution <../examples/uranyl.html>`__.

.. code-block:: perl

      my $sspath = Demeter::SSPath->new(parent => $feff,
                                        data   => $data,
                                        name   => "hydration sphere",
                                        ipot   => 3,
                                        reff   => 3.5,
                                       ); 

As you can read in the section on `that
example <../examples/uranyl.html>`__, the SSPath is used to model the
possibility of scattering from the oxygen atoms in the hydration sphere
around the ion in solution. The arguments to the ``new`` method shown
above are the bare requirements for creating an SSPath. In this case,
unique potential 3 is the equatorial oxygen atom. Thus, the
approximation is made that the scattering potential of the existing kind
of oxygen atom is enough like this test scatterer that its potential can
be used.

Once created (or, indeed, as arguments during creation, the SSPath is
parametrized exactly like any normal Path, i.e.:

.. code-block:: perl

      $fspath -> set(s02 => 'Nhydr * amp', enot=>'e0hydr'); 

Once created, the SSPath is used in a plot or a fit just like a normal
Path object.
