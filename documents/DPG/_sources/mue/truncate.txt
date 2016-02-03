..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Truncating data
===============

Truncating is the process of removing data from one end or the other
of a data set. The ``Truncate`` method takes two arguments. The first
is either of the words ``before`` or ``after`` and indicates whether
data is to be removed from the front or back end of the data. The
second argument is the energy value before/after which all data points
are removed.

Truncating changes the representation of the data within both
:demeter:`demeter` and :demeter:`ifeffit`.  (But not on disk --
:demeter:`demeter` never alters the original data.)  This method *does
not* return a new object.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;
    my $d0 = Demeter::Data -> new(file        => "$where/data/fe.060",
                                  name        => '60K',
                                  ln          => 1,
                                  energy      => q{$1},
                                  numerator   => q{$2},
                                  denominator => q{$3});
    $d0 -> plot('E');

    $d0 -> Truncate('after', 7500);
    $d0 -> plot('E');

In the example above, all points after 7500 eV are removed from the
data. Here is an example of removing points from the front end of the
data.


.. code-block:: perl

  $d0 -> Truncate('before', 7050);

.. _fig-truncate:
.. figure:: ../../_images/truncate.png
   :target: ../_images/truncate.png
   :align: left

   These are the data as plotted by the example script above.


.. linebreak::
