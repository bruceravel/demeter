..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: guess
.. role:: lguess

Local guess parameters and the characteristic value
===================================================

:demeter:`demeter` offers two very high level tools for efficiently
parametrizing fits, particularly multiple data set fits. These are
called :quoted:`local guess parameters` and the
:quoted:`characteristic value`. Here is the the multiple data set fit
to copper metal `that we saw before <fit/collection.html>`__, but
modified to use these two tools.

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter qw(:ui=screen);

    my @common = (fft_kmin   => 3,    fft_kmax   => 14,
                  bft_rmax   => 1.0,  bft_rmax   => 4.3,
                  fit_k1     => 1,    fit_k3     => 1,);

    ## make a Data object and set the FT and fit parameters
    my ($data_010k, $data_150k) = $prj->records(1, 2);
    $data_010k -> set(name=>'10 K copper data',  cv=>10,  @common);
    $data_150k -> set(name=>'150 K copper data', cv=>150, @common);

    ## run a Feff calculation on copper metal
    my $feff = Demeter::Feff -> new(file => "cu_metal.inp");
    $feff -> set(workspace => "cu_workspace/", screen => 0,);
    $feff -> potph -> pathfinder;
    my @list_of_paths = $feff -> list_of_paths;

    ## define a set of parameters
    my @gds =  (Demeter::GDS -> new(gds => 'lguess', name => 'alpha', mathexp => 0),
                Demeter::GDS -> new(gds => 'guess',  name => 'amp',   mathexp => 1),
                Demeter::GDS -> new(gds => 'guess',  name => 'enot',  mathexp => 0),
                Demeter::GDS -> new(gds => 'guess',  name => 'theta', mathexp => 500),
                Demeter::GDS -> new(gds => 'set',    name => 'sigmm', mathexp => 0.0005),
               );

    ## assign paths to the first data set
    my @paths_010k = ();
    foreach my $i (0 .. 4) {
      my $j = $i+1;
      $paths_010k[$i] = Demeter::Path -> new();
      $paths_010k[$i]->set(data     => $data_010k,
                           sp       => $list_of_paths[$i];
                           name     => "[cv]K, path $j",
                           s02      => 'amp',
                           e0       => 'enot',
                           delr     => 'alpha*reff',
                           sigma2   => 'debye([cv], theta) + sigmm',
                          );
    };

    ## clone all the paths from the first data set and assign them to the second
    my @paths_150k = ();
    foreach my $i (0 .. 4) {
      my $j = $i+1;
      $paths_150k[$i] = $paths_010k[$i] -> Clone(data => $data_150k);
    };

    ## do the fit
    my $fitobject = Demeter::Fit -> new(gds   => \@gds,
                                        data  => [$data_010k, $data_150k],
                                        paths => [@paths_010k, @paths_150k],
                                       );
    $fitobject -> fit;
    ## after-fit chores follow ...

At lines 10 and 11, the ``cv`` attribute is set for each Data object.
This is the :quoted:`characteristic value` for each data set, a
user-defined number that somehow relates to the XAS data contained in
the Data object. In this case, it is the temperature at which each
data were measured. In general, the ``cv`` should be something that is
meaningful to you within the context of your fitting model. It need
not be a number. The ``cv`` could be used, for instance, to assign
different parameters to different data sets. It's a simple tool, but
it can be used creatively to do interesting things in a fitting model.

The ``cv`` is then used at line 32 as part of each Path's name and at
line 36 as the temperature argument to the ``debye`` function. As
:demeter:`demeter` digs through the collection of Paths in the Fit
object, it will notice the use of the characteristic value and
substitute in the value of ``cv`` of the associated Data object.

This is not only useful for multile data set fits, it is also useful
when applying a specific fitting model to a sequence of data sets. Each
data set can have a characteristic value that will then be used
correctly by the fitting model for each fit in the sequence.

At lines 19, a new kind of GDS parameter is defined. An
:lguess:`lguess`, or :quoted:`local guess`, is a token that tells
:demeter:`demeter` to create a :guess:`guess` parameter for every Data
object which has a Path which uses the :lguess:`lguess` parameter.  In
this example, ``alpha`` is intended to represent the volumetric
expansion coefficient of the copper lattice at each temperature. We
want to allow this volumetric coefficient to float freely for each
data set.

As :demeter:`demeter` digs through the Fit object, a uniquely named
:guess:`guess` parameter will be created for each data set and any
path parameter math expressions will be rewritten to use that
:guess:`guess` parameter. in this example, the :lguess:`lguess`
``alpha`` will be expaneded into two :guess:`guess` parameters called
``alpha_10`` and ``alpha_150``. (The ``cv`` is used if it is defined,
otherwise the ``group`` attribute is used after the underscore.) The
generated :guess:`guess` parameters will be reported in the log file.

In the `earlier multiple data set example <fit/collection.html>`__, it
was necessary to redefine the ``delr`` and ``sigma2`` path parameters
after cloning Paths for use with the data set at 150 K. Using these two
tools, those redefinitions were not necessary.

Obviously, both the :lguess:`lguess` and the characteristic value are
efficiency tools.  They are intended to make fitting models easier to
write and more flexile to reuse.  Neither adds new functionality that
would be unavailable in other ways, but both should make the use of
:demeter:`demeter` easier and less error-prone.

.. caution:: An :quoted:`ldef` or :quoted:`local def` parameter has
   not yet been implemented. Thus, :lguess:`lguess` parameters can
   only be used in path parameter math expressions. Attempting to use
   an :lguess:`lguess` parameter in the math expression for another
   GDS parameter will result in an error which will stop your program.

