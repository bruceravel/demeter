..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The basics of data processing
=============================

This chapter introduces you to data import using :demeter:`demeter`
and provides an overview of the most basic data processing and
plotting chores. At the end of this chapter, you will be able to
import XAS data from a variety of sources and make attractive plots of
one or more data sets in any of energy, k-space, R-space, or
back-transform k-space.

The sections of this chapter deal with importing data from each of the
following kinds of files.

-  ASCII data file containing columns of energy and |mu| (E)

-  ASCII data file containing columns of wavenumber and |chi| (k)

-  ASCII data file containing columns of energy and detector readings

-  :demeter:`athena` project files

-  ASCII data file containing columns of energy and detector readings
   for multiple channels of data

-  Data files from beamlines that cannot be imported using any of the
   above.

These is also a section explaining how to deal with data coming from a
source that is not addressed by any of the above, for instance, data
conatined in a spreadsheet file or data being genereated algorithmically
by a program.

The final section provides an overview of :demeter:`demeter`'s plotting
capabilities.

As you will see in every example to follow, a :demeter:`demeter`
program is just a perl program which makes extensive use of the
capabilities of the :demeter:`demeter` library, which is itself
written in perl.  A :demeter:`demeter` program requires a small amount
of boilerplate at the beginning. Just put the following line at the
top of your perl program and you are using :demeter:`demeter`:

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

Note that the `strict <http://perldoc.perl.org/strict.html>`__ and
`warnings <http://perldoc.perl.org/warnings.html>`__ pragmas are
imported automatically when :demeter:`demeter` is imported.  That is,
:demeter:`demeter` requires that your programs conform to these two
pragmas.  That is such an inherently good idea that :demeter:`demeter`
insists upon it.  Exporting these two perl pragmata is accomplished in
the same manner as for `Modern::Perl
<https://metacpan.org/pod/Modern::Perl>`_ (see `lines 38 and 39
<https://metacpan.org/source/CHROMATIC/Modern-Perl-1.20150127/lib/Modern/Perl.pm#L38>`_).

---------------------

**Contents**

.. toctree::
   :maxdepth: 2

   mue.rst
   chi.rst
   columns.rst
   athena.rst
   mc.rst
   special.rst
   other.rst
   plot.rst
