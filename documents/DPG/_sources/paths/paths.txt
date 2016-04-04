..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Calculating individual scattering paths
=======================================

After the path finder is run, the Feff object has its ``pathlist``
attribute filled with a reference to a list of ScatteringPath objects.
The ScatteringPath object is an abstract representation of a
scattering path. In :demeter:`demeter`, the ScatteringPath object is
somewhat like a :file:`feffNNNN.dat` is to :demeter:`ifeffit` |nd| it
does indeed describe the path, but it needs to imported and
parametrized before it can be used to make a plot or a fit.

The ScatteringPath object has attributes which describe all the geometry
of the path, including degeneracy, leg lengths, and scattering angles.
It also has a way of reconstructing the specific geometry of each
degenerate path that gets combined when the path finder determines path
degeneracy.

The methods of the ScatteringPath object include a way of generating
the :file:`feffNNNN.dat` file containing :demeter:`feff` calculation
of the scattering amplitude and phase shift for the path. The
calculation of the :file:`feffNNNN.dat` file is done on-the-fly by
:demeter:`demeter` and is written to temporary file in the directory
specified by the ``workspace`` attribute of the Feff object from which
the ScatteringPath object was created.  That path file has a randomly
generated name. The use of random names for the path files is intended
to sever the link between the index of the path in :demeter:`feff`
path list and the path file. That number has been used in earlier
versions of :demeter:`artemis`, but has proven troublesome in many
situations. As you will see in later chapters, :demeter:`demeter`
tries to emphasize semantic descriptions of paths, eschewing the path
index.

:demeter:`demeter` never saves :file:`feffNNNN.dat` files when it
saves a fitting model to a project file (nor does
:demeter:`artemis`). The recalculation of the :file:`feffNNNN.dat`
file is sufficiently fast that it is done when needed.

The main use of the ScatteringPath object is as the value of the ``sp``
attribute of the Path object. Here is an example of plotting the 6
shortest paths from a :demeter:`feff` calculation.

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter;

    my $feff = Demeter::Feff -> new(file => "feff/feff.inp");
    $feff -> set(workspace => "feff/", screen => 0,);
    $feff -> potph;
    $feff -> pathfinder;

    my @list_of_paths = @{ $feff-> pathlist };
    foreach (@list_of_paths[0..5]) {
        my $this = Demeter::Path->new(parent => $feff,
                                      sp     => $_);
        $this -> plot('r');
    };

At line 9, the reference to the list of ScatteringPath objects is read
into a normal array (the ``@{ }`` syntax `dereferences
<http://perldoc.perl.org/perlref.html#Using-References>`_ the
array).  The first 6 elements of this array is then looped over and a
Path object is created using those 6 ScatteringPath objects. Each Path
object is then plotted at line 13.


 

Writing ``feffNNNN.dat`` files
------------------------------

As demonstrated above, generation of the individual
:file:`feffNNNN.dat` files is something that happens behind the
scenes. :demeter:`demeter` goes to great lengths to ensure that you do
not need to worry about those files. It is certainly possible to write
large, complex fitting programs with :demeter:`demeter` without ever
even thinking about those files.

That said, sometimes you may want to generate :file:`feffNNNN.dat`
files. The Feff object provides the ``genfmt`` method. This is the
method used behind the scenes to generate path files as needed for
plotting or fitting. This behind-the-scenes chore is quite
efficient. The individual path file is saved during an instance of the
:demeter:`demeter` program so it can be reused without being recalculated. Even
in a scenario where a single ScatteringPath object is used to define
two or more Path objects (see `the histogram example
<../examples/histogram.tt>`__ for an example where this is used to
great effect), :demeter:`demeter` is clever enough to only compute the
path file once.

In a scenario where you wish to generate :file:`feffNNNN.dat` files, you can do
something like this:

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl  use Demeter;

    ## Deserialize feff.yaml;
    my $feff = Demeter::Feff -> new(yaml => "feff/feff.yaml");
    $feff->pathsdat(); # all paths
    #$feff->pathsdat(1,2,6,9); # the first four SS paths
    $feff->genfmt;

The ``pathsdat`` method writes a paths.dat file to the Feff object's
``workspace``.  This is the file that the *genfmt* part of
:demeter:`feff` uses to define the geometries of the scattering paths
that go into the :file:`feffNNNN.dat` files. Without an argument, as
at line 6, all paths found by the path finder are written to the
:file:`paths.dat` file. With an argument, as commented out at line 7,
only the paths listed will be written out.  The path files then
generated by the ``genfmt`` method will be named :file:`feffNNNN.dat`
with the ``NNNN`` replaced by the zero-padded path index.  This
behavior is very similar to the normal behavior of :demeter:`feff`
(with the exception of the ability to prescribe a truncated path
list).

As great as it is that :demeter:`demeter` can replicate the stodgy old
behavior of :demeter:`feff`, I strongly recommend that you avoid doing
so.


 

Examining the degenerate paths
------------------------------

Along with fuzzy degeneracy, the ability to remember the entire list of
scattering geometries contributing to the degeneracy of a path is one of
the major new features DEMETER's path finder. If you ever want to
examine the degenerate list, you can do something like this:

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    ## Deserializing feff.yaml;
    my $feff = Demeter::Feff -> new("feff/feff.yaml");
    my @list_of_paths = $feff->pathlist;

    ### The 6 scattering geometries that contribute to path #2:
    my $sp = $list_of_paths[1];
    my $j=1000;
    foreach my $s ($sp->all_strings) {
      print $sp -> pathsdat(index=>++$j, string=>$s, angles=>1);
    };

What gets printed out is something like this, which is in the form of a
:file:`paths.dat` file and can be used by the *genfmt* part of :demeter:`feff`.

::

      1001    2   6.000  index, nleg, degeneracy, r= 3.6100
          x           y           z     ipot  label      rleg      beta        eta
        3.610000    0.000000    0.000000   1 'Cu_2  '     3.6100  180.0000    0.0000
        0.000000    0.000000    0.000000   0 'abs   '     3.6100  180.0000    0.0000
      1002    2   6.000  index, nleg, degeneracy, r= 3.6100
          x           y           z     ipot  label      rleg      beta        eta
       -3.610000    0.000000    0.000000   1 'Cu_2  '     3.6100  180.0000    0.0000
        0.000000    0.000000    0.000000   0 'abs   '     3.6100  180.0000    0.0000
      1003    2   6.000  index, nleg, degeneracy, r= 3.6100
          x           y           z     ipot  label      rleg      beta        eta
        0.000000    3.610000    0.000000   1 'Cu_2  '     3.6100  180.0000    0.0000
        0.000000    0.000000    0.000000   0 'abs   '     3.6100  180.0000    0.0000
      1004    2   6.000  index, nleg, degeneracy, r= 3.6100
          x           y           z     ipot  label      rleg      beta        eta
        0.000000   -3.610000    0.000000   1 'Cu_2  '     3.6100  180.0000    0.0000
        0.000000    0.000000    0.000000   0 'abs   '     3.6100  180.0000    0.0000
      1005    2   6.000  index, nleg, degeneracy, r= 3.6100
          x           y           z     ipot  label      rleg      beta        eta
        0.000000    0.000000    3.610000   1 'Cu_2  '     3.6100  180.0000    0.0000
        0.000000    0.000000    0.000000   0 'abs   '     3.6100  180.0000    0.0000
      1006    2   6.000  index, nleg, degeneracy, r= 3.6100
          x           y           z     ipot  label      rleg      beta        eta
        0.000000    0.000000   -3.610000   1 'Cu_2  '     3.6100  180.0000    0.0000
        0.000000    0.000000    0.000000   0 'abs   '     3.6100  180.0000    0.0000

In truth, :demeter:`demeter` does not do much with the list of degerate scattering
geometries at this time. In the future, I hope to incorporate an ability
to propagate a strctural distortion through the degerate paths to
examine the effect of broken degeneracy on the calculated or fitted
|chi| (k).

