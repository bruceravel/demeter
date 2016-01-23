
Deglitching data
================

.. todo:: Make a figure that shows the result of the actual code
          snippet.

:quoted:`Deglitching` is the process of removing spurious points from
data. This is a slightly scary, slightly arbitrary procedure. There
is, after all, no obvious definition of what consititutes a spurious
point. If, however, you have reason to want to remove data points,
this is how it's done.

:demeter:`demeter`'s deglitching procedure is very simple. Given one
or more energy values, the data point closest in energy to each
supplied value will be removed from the data. Deglitching, therefore,
changes the representation of the data within both :demeter:`demeter`
and :demeter:`ifeffit`.

In this example, some data are imported at lines 4-10 and plotted at
line 12. At line 14, two points are removed from the data. Note that
this method operates on the object itself. It *does not* return a new
object. Finally at line 15 the deglitched data are plotted over the
original data.

Multiple arguments can be given to the ``deglitch`` method. Each
argument is interpeted as an energy value and the point closest is
removed from the data.

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter;
    print "Reading and plotting uhup.003\n";
    my $d0 = Demeter::Data -> new(file        => "path/to/uhup.003",
                                  name        => 'HUP',
                                  energy      => '$1', # column 1 is energy
                                  numerator   => '$3', # column 3 is I0
                                  denominator => '$4', # column 4 is It
                                  ln          => 1,    # these are transmission data
                   );

    $d0 -> plot('e');
    $d0 -> name("HUP, deglitched");
    $d0 -> deglitch(17385.686, 17655.5);
    $d0 -> plot('e');


.. _fig-deglitchpointremoved:
.. figure:: ../../_images/deglitch_pointremoved.png
   :target: ../_images/deglitch_pointremoved.png
   :align: left

   Here are the data from the code example above with one of the four
   glitchy point removed.  In the case of these data, the glitches are
   due to a signal problem at the beamline and obviously represent
   spurious points.

.. linebreak::

The ``deglitch`` method is not the easiest thing to
use. :demeter:`demeter` has no built in way of identifying potential
spurious points.  This method is the most bare-boned implementation
possible. :quoted:`Here are some data points, remove them!` This
method is intended to be the backend of some kind of interactive,
graphical deglitching tool, like the one in :demeter:`athena`.

