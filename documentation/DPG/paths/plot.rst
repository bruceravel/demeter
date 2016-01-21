
Plotting individual paths
=========================

Data, Path, and the various `path-like objects <../pathlike/index.tt>`__
can all be plotted using a very consistent interface. This is made
possible due to two attributes which are inherited by every object from
the base class -- ``data`` and ``plottable``.

The ``data`` attribute points to the Data object which is used to
provide parameters for the Fourier transforms. For a data object, this
attribute points to itself. For example, to change the lower bound of
the Fourier transform range, you are able to do something like this:

That construct is guaranteed to do what you want for any Data, Path or
path-like object.

The ``plottable`` attribute is boolean and is used to distinguish Data,
Path, and path-like objects from other object types in the :demeter:`demeter`
system. Trying to plot something that cannot be plotted, like the sample
below, will trigger an error and probably cause your program to exit,
but it certainly will not behave in some strange and unexpected manner.

ScatteringPath objects are not plottable objects (and, so, have their
``plottable`` set to 0). To visualize the contribution from the
scattering geometry described by a ScatteringPath object, you must
create a Path object. Revisiting the example of plotting the first few
paths in a :demeter:`feff` calculation:

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data::Prj -> new("athena.prj") -> record(3);

    my $feff = Demeter::Feff -> new(file => "feff/feff.inp");
    $feff -> set(workspace => "feff/", screen => 0,);
    $feff -> potph;
    $feff -> pathfinder;

    my @list_of_paths = @{ $feff-> pathlist };
    my @paths;
    foreach (@list_of_paths[0..5]) {
      push @paths, Demeter::Path->new(parent => $feff,
                                      data   => $data,
                                      sp     => $_);
    };
    ## plot data and paths together in R space
    $_ -> plot('r') foreach ($data, @paths);

Data is imported from an :demeter:`athena` project file at line 4
(using chained method calls!) and a :demeter:`feff` calculation is
made between lines 6 and 9.  Path objects are created at lines 14 to
16 in a loop over the first few ScatteringPath objects from the
:demeter:`feff` calculation. Finally at line 19, everything is plotted
in R space.

Note that the syntax for plotting Data and Path objects is
identical. Of course, different things are required to get Data and
Path objects ready to be plotted, but those interface details are
handled by :demeter:`demeter`. For the programmer, the chore is easy.
