..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: guess
.. role:: def


Path parameters
===============

Each path page offers a set of text boxes for entering the math
expressions associated with each of the path parameters.  A path
parameter is a math expression that is used to evaluate one of the
terms in the EXAFS equation for that path.

**label**

  This is a text string that is used to identify the path.  It is used
  in the log file and in other places.  :demeter:`artemis` generates a
  useful string from the contents of the path, including the nominal
  path length, the degeneracy, and the number of legs of the path.

**N**

  The coordination number.  This **must** be a pure number.  It **may
  not** be a math expression or a variable.  This is choice made in
  :demeter:`artemis` to avoid confusion between N and S\ :sub:`0`\
  :sup:`2`.

  Typically, this is the path degeneracy.  Another common value for N
  is 1, in which case the coordination number is handled by the math
  expression for S\ :sub:`0`\ :sup:`2`.

**S02**

  Nominally, this path parameter represents the amplitude reduction
  factor S\ :sub:`0`\ :sup:`2`.  In practice, it is used for all
  aspects of the fitting model that effect the amplitude of the path.
  If you have :guess:`guess` parameters or :def:`def` parameters that
  represent, for example, a dopant or vacancy concentration or an
  unknown coordination number, those parameters are used as parts of
  the math expression for this path parameter.

|Delta| E\ :sub:`0`

  This is an adjustment to the E\ :sub:`0` used to evaluate the
  wavenumber of the theory.  As a fitting parameter, it is useful to
  think of |Delta|\ E as the parameter which aligns the energy (or
  wavenumber) grids of the data and the theory.

|Delta|\ R

  This is an adjustment of the half path length of the path.  For a
  single scattering path, it is an adjustment of the inter-atomic
  distance.

|sigma|\ :sup:`2`

  The mean square variation in path length.  In practice, this
  parameter often encapsulates both static and thermal disorder.

**Ei**

  An adjustment to the :quoted:`imaginary energy`.  This is a way of
  encapsulating an adjustment to the mean free path length of the
  photo-electron.  A :guess:`guess` parameter for Ei is, in general,
  highly correlated with other amplitude terms.

**3rd**

  A third cumulant for the path.  This is a skew deviation from
  Gaussian disorder for the scattering path.  A :guess:`guess`
  parameter for the third cumulant will be highly correlated with
  |Delta|\ R and |Delta|\ E:sub:`0`.

**4th**

  A fourth cumulant for the path.  This is a curtosis deviation from
  Gaussian disorder for the scattering path.  A :guess:`guess`
  parameter for the fourth cumulant will be highly correlated with
  |sigma|\ :sup:`2` and other amplitude parameters.


There is discussion of working with path parameters and math
expressions in `the next section <mathexp.html>`_ and in `the section
on GDS parameters
<../gds.html#creating-parameters-from-math-expressions-on-the-path-page>`_.
