..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


VPath object
============

A fit can involve a lot of paths. It is often useful to make a plot
showing your data and its fit along with some of the paths that were
used in the fit. This quickly becomes unweildy for a complex fit with
lots of small paths. A plot showing each individual path will be messy
and won't effectively convey how the large number of small paths
contribute to the fit.

The VPath, or :quoted:`virtual path`, is a solution to this
problem. The VPath is a user-defined collection of normal Path objects
which can be bundled together, summed, then plotted as such. The VPath
serves no purpose in the construction of a fitting model, but it can
be very useful for visualizing the results of a fit.

It works like this:

.. code-block:: perl

    my $vpath = Demeter::VPath->new(name => "my virtual path");
    $vpath -> include($path1, $path2, $path3);
    $vpath -> plot('R');

The VPath is created like any object, using the ``new`` method. It can
be given a name, which, like the name of a Data or Path object, will be
used in the legend of any plot.

The collection of paths is created using the ``include`` method. This
method takes one or more Path objects, in this case ``$path1``,
``$path2``, and ``$path3`` contain references to Path objects. The
``include`` method is cumulative. You can call it repeatedly, each time
adding another Path to the collection.

Finally, the VPath object is plotted just like any Data or Path
object.  :demeter:`demeter` is careful to keep each element of the
VPath up to date with respect to the fit and will make the summation
in k-space just before Fourier transforming (if plotting in R or q)
and making the plot.

The use of the VPath to make interesting plots is demonstrated in the
example of a `uranyl ion in solution <../examples/uranyl.html>`__. That
example also demonstrates the cumulative use of the ``include`` method.
