..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Path parameters
===============

Once the ScatteringPath object is imported, the next step to setting up
a Path object for use in a fit is to set the path parameters. The
available path parameters are

``label``
    A text string describing the path.
``degen``
    The path degeneracy. This typically is set the degeneracy of the
    ScatteringPath object when the ``sp`` attribute is set, but can be
    modified by the user as part o fthe fitting model.
``s02``
    Nominally, this is the amplitude reduction factor, but can be
    parameterized to include any amplitude effects in the fitting model.
``e0``
    The energy shift, which changes the zero of k.
``delr``
    A change in the path length.
``sigma2``
    The mean square disorder parameters, |sigma|\ :sup:`2`.
``ei``
    An adjustment to the “simaginary energy”, which has the effect of
    adjusting the broadening due to core-hole lifetime, instrumental
    resolution, etc. This has usings of eV.
``third``
    The third cumulant of the partial pair distribution.
``fourth``
    The fourth cumulant of the partial pair distribution.
``dphase``
    A constant offset to the scattering phase shift. Note that this
    should only be used for fits to |chi| (k) data derived from a DAFS or
    reflectivity-XAFS measurement. For normal XAFS, this path parameter
    has no physical intepretation.

Except for ``label`` which takes a descriptive string and ``degen``
which takes a number, all the path parameter attributes take text
strings which are for interpretion as math expressions by
:demeter:`ifeffit`.

The accessor methods for each of these path parameters is label in the
list above. For example:

.. code-block:: perl

  ## get path parameter math expression:
  printf "deltaR=%s and sigma2=%s\n", $path->delr, $path->sigma2;
  ## set a path parameter:
  $path->s02("(1-x) * amp");

For the path parameter attributes that take math expression text
strings, there is another set of attributes that have the same names
but with ``_value`` appended to the end. Whenever a Path object is
plotted, used in a fit, or other wise evaluated in :demeter:`ifeffit`,
the evaluation of the math expression is stored in the ``_value``
attribute. Although you can set one of the ``_value`` attributes, that
will usually have no effect as the value will be overwritten the next
time :demeter:`demeter` uses the path.  However, the ``_value``
attributes are very useful for obtaining the evaluations of the math
expressions:

.. code-block:: perl

      ## get path parameter math expression:
      printf "deltaR evaluated to =%.5d\n", $path->delr_value; 

In fact, this is done repeatedly during the construction of `the
logfile <../fit/after.html>`__.



Other methods
-------------



The R method
~~~~~~~~~~~~

The ``R`` method is used to return the fitted half path length, that is
the sum of R\ :sub:`eff` and ``delr``.

.. code-block:: perl

  printf "half path length is %.5d\n", $path->R;

The paragraph method
~~~~~~~~~~~~~~~~~~~~

This method returns a multiline text string reporting on the
evaluation of the Path's math expressions. This text looks very much
like the text that :demeter:`ifeffit` returns when you use
:demeter:`ifeffit`'s ``show @group`` command.

.. code-block:: perl

        print $path_object -> paragraph; 

The make\_name method
~~~~~~~~~~~~~~~~~~~~~

This method is used to construct a descriptive label for the path and
is called when the :file:`feffNNNN.dat` file is imported. Since that
usually happens behind the scenes, it is very rarely necessry to call
this method. However, it is important to understand how this method
works as it can be used to configure how the Path object gets
labeled. This is determined using the :configparam:`Pathfinder,name`
configuration parameter. The default value of this parameter is
``%P``, which means that the default label is the the interpretation
list of the associated ScatteringPath object with the absorber tokens
removed from the ends.

- ``%i``: Replaced by the path index used by :demeter:`ifeffit` for
  this path.  Note that this may not be constant throughout a
  session.

- ``%I``: Like the ``%i`` tag, but zero padded to be 4 characters
  wide.

- ``%p``: Replaced with the return value of the ScatteringPath
  ``intrplist`` method.

- ``%P``: Like the ``%p`` but with the absorber tokens removed from
  both ends.

- ``%r``: The R\ :sub:`eff` of the path. In the case of a fuzzily
  degenerate path, the average R\ :sub:`eff` value of the fuzzily
  degenerate paths is reported.

- ``%n``: The number of legs of the path.

- ``%d``: The (fuzzy) degeneracy of the Path.

- ``%t``: The description of the scattering geometry as determined by
  :demeter:`demeter`'s path finder.

- ``%m``: The importance of this Path as determined by
  :demeter:`demeter`'s path finder.

- ``%g``: The group name used in :demeter:`ifeffit` to hold the arrays
  of this path.

- ``%f``: The name of the associated Feff object.

- ``%%``: A literal percent sign.

This line resets the default Path label to a string that includes the
half path length and the path degeneracy

.. code-block:: perl

   $path_object -> co -> set_default("pathfinder", "label", '%r (%d)';

Uncertainties in path parameters
--------------------------------

.. todo:: Propagation of uncertainties into path parameter math
	  expressions is a missing feature of :demeter:`demeter`.

