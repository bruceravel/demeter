..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Output formats
==============

:demeter:`demeter` offers a large number of output formats for the
various kinds of data handled by the various kinds of objects.



Single object column data files
-------------------------------

There are a number of ways to save Data, Path, and path-like objects
into column data files that can be plotted using other plotting programs
or imported into a spreadsheet program.

The available single object output types are:

**xmu**
    This file has 7 columns : energy, data as |mu| (E), background,
    pre-edge, post-edge line, derivative, and second derivative for a
    Data object.
**norm**
    This file has 7 columns: energy, data as normalized |mu| (E), normalized
    background, flattened |mu| (E), flattened background, derivative of the
    normalized |mu| (E), and second derivative of the normalized |mu| (E) for a
    Data object.
**chi**
    This file has 6 columns: wavenumber, |chi| (k), k |chi| (k), 
    k\ :sup:`2` |chi| (k), k\ :sup:`3` |chi| (k),
    and the window function in k for a Data, Path, or pathlike object.
**r**
    This file has 6 columns: R, real part of |chi| (R), imaginary part,
    magnitude, phase, and the window function in R for a Data, Path, or
    pathlike object. The current value of k-weighting in the Plot object
    is used to generate the data for this file.
**q**
    This file has 6 columns: q, real part of |chi| (q), imaginary part,
    magnitude, phase, and the window function in k for a Data, Path, or
    pathlike object. The current value of k-weighting in the Plot object
    is used to generate the data for this file.

.. code-block:: perl

   $data_object -> save('xmu',  'myfit.dat')
   $path_object -> save('chir', 'mypath.dat')


Column data file headers
~~~~~~~~~~~~~~~~~~~~~~~~

The header of the fit and bkgsub file types is generated using the
``data_parameter_report`` method which, in turn, takes its formatting
from the data\_report.tmpl `template file <highlevel/dispose.html>`__.

.. todo:: The following is out of date, now using XDI headers

This line of code:

.. code-block:: perl

   print $data_object -> data_parameter_report;

generates this text:

::

    .  Element=Au   Edge=l3
    Background parameters
    .  E0=11919.166  Eshift=0  Rbkg=1.6
    .  Standard=None
    .  k-weight=1  Edge step=0.8548872
    .  Fixed step=no    Flatten=yes
    .  Pre-edge range: [ -150 : -30 ]
    .  Pre-edge line: 2.404416 - 0.000174619 * energy
    .  Normalization range: [ 150 : 869.877293080001 ]
    .  Post-edge polynomial: 4.337632 - 0.000197019 * en - 5.71097e-09 * en^2
    .  Spline range (energy): [ 0.000 : 969.877 ]   Clamps: 0/24
    .  Spline range (k): [ 0.000 : 15.955 ]
    Foreward FT parameters
    .  Kweight=1   Window=kaiser-bessel   Phase correction=0
    .  k-range: [ 2 : 13 ]   dk=1
    Backward FT parameters
    .  R-range: [ 1 : 3 ]
    .  dR=0.2   Window=kaiser-bessel
    Plotting parameters
    .  Multiplier=1   Y-offset=0.0000


Fit result column data files
----------------------------

The results of a fit can be saved in one of two special column data
files:

**fit**
    This file of 5 or 6 columns uses the fitting space for the first
    column (i.e. wavenumber for a fit in k or q; distance for a fit in
    R), followed by the data, the fit, the residual, the background if
    it was fitted, and the appropriate window function. This is only for
    a Data object that has been used in a fit.

**bkgsub**
    This file has 3 columns: k, |chi| (k) with the background function
    subtracted, and the k-space window. This is only for a Data object
    that has been used in a fit.

The ``save`` method takes an additional argument used only for the fit
type. It specifies what form of the data and the other parts to write to
the file. It can take a value of ``k``, ``k1``, ``k2``, ``k3``,
``rmag``, ``rre``, ``rim``, ``qmag``, ``qre``, or ``qim`` to indicate
the space, the k-weighting for k-space output, or the part of the
complex function for R- or q-space output. The default (no argument) is
``k``, i.e. un-k-weighted |chi| (k).

.. code-block:: perl

   $dobject->save("fit", "cufit.fit");
   $dobject->save("fit", "rmag.fit", 'rmag');
   $dobject->save("fit", "rre.fit", 'rre');
   $dobject->save("fit", "rim.fit", 'rim');


Column data file headers
~~~~~~~~~~~~~~~~~~~~~~~~

The header of the fit and bkgsub file types is generated using the
``fit_parameter_report`` method which, in turn, takes its formatting
from the fit\_report.tmpl `template file <highlevel/dispose.html>`__.

This line of code:

.. code-block:: perl

   print $data_object -> fit_parameter_report;

generates this text:

::

    Demeter fit file -- Demeter 0.4.1
    : file                = cu10k.chi
    : name                = My copper data
    : k-range             = 3.000 - 14.000
    : dk                  = 1
    : k-window            = hanning
    : k-weight            = 1,2,3
    : R-range             = 1.6 - 4.3
    : dR                  = 0.0
    : R-window            = hanning
    : fitting space       = r
    : background function = no
    : phase correction    = 0



Multiple object column data files
---------------------------------

:demeter:`demeter` offers the ``save_many`` method as a way to export
many Data, Path, and pathlike objects to a single column data file
which can be easily imported into a plotting or spreadsheet
program. The x-axis of the export space will be in the first column,
followed by one column for each object exported. Those columns will be
in the order specified in the method call.

.. code-block:: perl

      $data->save_many("many.out", 'chik3', $paths[0], $paths[1], $carbon); 

The first argument is the output file name. The second argument is the
kind of data to write out (see the list below). The remaining arguments
are Data, Path, or pathlike objects to wrtie to the file. The calling
object (which san be any Data, Path, or pathlike object) will be added
to the front of the list of objects to export. Care is taken not to
export the caller twice if it also appears in the argument list and the
caller appears in the second column of the output file.

Every item in the list is interpolated (if necessary) to the grid of the
caller.

The available types are as follows (note that trying to write energy
data with Path or pathlike objects in the argument list will trigger an
error):

- ``xmu``: save |mu| (E) for all objects in the argument list.

- ``norm``: save normalized |mu| (E) for all objects in the argument list.

- ``der``: save the derivative of |mu| (E) for all objects in the argument
  list.

- ``nder``: save the derivative of normalized |mu| (E) for all objects in
  the argument list.

- ``sec``: save the second derivative of |mu| (E) for all objects in the
  argument list.

- ``nsec``: save the second derivative of normalized |mu| (E) for all
  objects in the argument list.

- ``chi``: save unweighted |chi| (k) for all objects in the argument list.

- ``chik``: save k\ :sup:`1`\ -weighted |chi| (k) for all objects in the argument list.

- ``chik2``: save k\ :sup:`2`\ -weighted |chi| (k) for all objects in the argument
  list.

- ``chik3``: save k\ :sup:`3`\ -weighted |chi| (k) for all objects in the argument
  list.

- ``chir_mag``: save the magnitude of |chi| (R) for all objects in the
  argument list.

- ``chir_re``: save the real part of |chi| (R) for all objects in the
  argument list.

- ``chir_im``: save the imaginary part of |chi| (R) for all objects in the
  argument list.

- ``chiq_mag``: save the magnitude of |chi| (q) for all objects in the
  argument list.

- ``chiq_re``: save the real part of |chi| (q) for all objects in the
  argument list.

- ``chiq_im``: save the imaginary part of |chi| (q) for all objects in the
  argument list.



Athena project files
--------------------

You can export an :demeter:`athena` project files from a group of data
objects like so:

.. code-block:: perl

   $data->write_athena("myproject.prj", @list_of_data);

The first argument is the filename for the project file. This is
followed by a list additional data objects to export. The caller will be
the first group in the project file, followed by the addition data in
the order supplied. If the caller is also in the list, it will not be
written twice to the project file.

This is, in every way, a normal :demeter:`athena` project file that
can be imported by :demeter:`athena` or :demeter:`artemis`.



Serialization files
-------------------

Every :demeter:`demeter` object type has a serialization format. The purpose of
this is to freeze the state of an object to disk in a form that can be
easily reimported to recover the state of the object.

These files use the `YAML data serialization <http://www.yaml.org/>`__
format. YAML is a fairly simple, text-only way of recording state of
an object. Although you should never need to do so, you can examine or
even edit a YAML file with any text editor. To save a little space,
:demeter:`demeter` compresses the files using the same algorithm as
the `gzip program <http://www.gzip.org/>`__. This kind of compressed
file can be read by most compression or archiving programs on all
platforms.

An object is written to a yaml file using the ``freeze`` method. It's
argument is the name of the output file.

.. code-block:: perl

      $data->freeze("data.yaml"); 

You can import one of these serialization using the ``thaw`` method.
It's argument is the name of the file to import. It returns the object.

.. code-block:: perl

      $new_object = $data->thaw("data.yaml"); 



Log files
---------

The Fit object has a ``logfile`` method.



Project files
-------------

Project files are zip files filled with YAML files and other things.



Atoms and feff I/O
------------------

:demeter:`atoms` and :demeter:`feff` I/O



Scripts
-------

:demeter:`demeter` and :demeter:`ifeffit` scripts

