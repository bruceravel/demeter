
Data import
===========

:demeter:`athena` is very versatile in how she reads in data files. Pretty much any
data in the form of columns of numbers can be successfully read. With a
few exceptions, :demeter:`athena` relies upon :demeter:`ifeffit`'s ``read_data()`` command to
handle the details of data import. :demeter:`ifeffit` is clever about recognizing
which part of a file is columns of numbers and which part is not. In the
following, I'll explain how the ``read_data()`` command interprets
files, explain the limits on its and :demeter:`athena`'s abilities to interpret a
data file, and discuss the kinds of manipulations of data that can and
cannot be performed by :demeter:`athena` as data are imported.

:demeter:`athena` expects data of one of a few types. Column data in which the
columns represent such things as the energy grid and the scalars
measured during the experiment are the most common sort of data that
most people use import into :demeter:`athena`. :demeter:`athena`'s column selection dialog is
used to convert the raw scalars into |mu| (E) data. Other common kinds of
data files that might be read into :demeter:`athena` are files that contain |mu| (E) or
chi(k) data in columns or the output files from Feff, xmu.dat and
chi.dat.

Here is an example of a data file that will make :demeter:`athena` as happy as can
be. There are some header lines, followed by a line of dashes, followed
by a line of column labels, followed by lines containing columns of
data.

::

    # X15B  project: MT 9/23/04
    # original file: STD1.001
    # unpacked from original data as a sequence of 4-byte floats
    # -----------------------------------------------------------
    #   energy           I0          narrow        wide
        2400.0020    60183.3008       38.5000       83.0000
        2401.5088    60241.0508       41.5000       82.0000
        2403.0078    60347.5508       40.0000       83.7500
        2404.5039    60531.0508       42.2500       78.2500
      ... etc ...

In this example of a perfectly formatted file, the header lines, the
line of dashes, and the column labels line are all preceded by a hash
(``#``) mark. :demeter:`ifeffit` is thus able to recognize these as
header lines. Since :demeter:`ifeffit` recognizes them as such,
:demeter:`athena` will store them in the project along with the
data. Because there is a line of dashes and because it is followed
immediately by column labels, :demeter:`athena` is able to use these
labels in the column selection dialog. A few other common US keyboard
symbols, such as ``%`` or ``\*``, will also be understood as marking header
lines.

The numbers in the columns can be integers, floats (such as ``1.234``,
``-1.234``, .\ ``1234`` or ``-.1234``), or exponentials (such as
``1.23e45`` or ``-1.23E-45``). Anything interpretable as a number in the
C programming language will be interpretable in this context. The
columns of numbers go to the end of the file. There is no text following
the data.

When data is recorded as described above, it will be fully utilized by
:demeter:`athena`. The headers will be recorded, the column labels will be used,
the data will be interpreted. :demeter:`athena` can, however, accommodate
significant deviation from the format described above.

-  If the header lines are not marked by a # or some other recognizable
   marking character, :demeter:`ifeffit` will not be able to recognize headers or
   column labels. As long as no text follows the data, the columns will
   still be understood as columns of data and the data can be imported
   by :demeter:`athena`.

-  If the line of dashes is missing, again the headers and column labels
   will not be recognized, but the columns of data will be.

-  If no headers are in the file, the columns of data will still be
   understood as data.

:demeter:`athena` expects that the data are recorded as a function of energy and
that one of the columns contains energy values. The assumption is that
the first column is the energy column, but that can be changed in the
column selection dialog. :demeter:`athena` works in eV. If data are recorded in
keV, there is a menu in the column selection dialog that must be set
accordingly.

Here are some operations that can be performed as data is imported.

#. Data from a multi-element detector can be summed on the fly.

#. Data from a multi-element detector can be imported such that each
   detector channel is imported into its own data group.

#. Data can be negated, i.e. multiplied by -1, or multiplied by an
   arbitrary constant

#. A reference channel can be read from the the same file.

#. Data can be preprocessed. That is, data can be truncated, deglitched,
   aligned to a standard, and have its parameters constrained to a
   standard

Here are some operations that can be handled using `the Plugin
architecture <../other/plugin.html>`__.

#. Data can be imported as a function of pixel position on an area or
   linear detector.

#. Conversion from wavelength to energy.

#. Conversion from encoder reading or motor steps to energy.

#. Conversion of data in a binary format

#. Dead-time corrections using columns from the data file.

#. Any math expression more complicated than sums of columns in the
   numerator and denominator, e.g. plugins allow you to multiply the If
   column by 7 and divide by the sine of the I0 column, if that's what
   you really want.

If some of the criteria for the data file format are not met, for
example if there is text following the data columns or if you need to
perform one of the operations not yet supported, you will need to
process you data before trying to import into :demeter:`athena`.

There are examples of data files that :demeter:`athena` will process
before sending off to :demeter:`ifeffit` for import. An example is the
data file format from beamline X10C at NSLS. Files from that beamline
cannot be imported as written by :demeter:`ifeffit`'s ``read_data()``
command. :demeter:`athena` will recognize such a file and process it
as needed before importing it. This can be done with other
beamlines. You should contact Bruce if you are the beamline scientist
or a frequent user of some beamline which writes data in a way that
``read_data()`` cannot import.

As a final comment, I would encourage beamline scientists and the
authors of data acquisition software to consider their users when
designing data file formats. While I certainly will not say that
beamlines should be required to accommodate :demeter:`athena` or even
that beamline staff have any obligation to recommend :demeter:`athena`
to their users, the truth is that :demeter:`athena` is becoming an
increasingly common tool in the EXAFS community. The format that best
serves :demeter:`athena` is actually a fine format that can be
imported by a very wide variety of EXAFS software, plotting software,
spreadsheets, and other programs. It's a good format and your users
would be well served by your adopting it.

.. toctree::
   :maxdepth: 2

   columns
   projsel
   multiple
   ref
   preproc
