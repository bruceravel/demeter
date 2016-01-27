..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Plotting and basic data processing
==================================

Types of plots
--------------

Once you have imported data, you will want to start doing interesting
things with it. :quoted:`Interesting things` are, of course, the topic
of the rest of this programming guide. The first interesting thing to
discuss is plotting.

One might think that topics such as background removal, normalization,
and Fourier transforms are discussion-worthy. In fact,
:demeter:`demeter` goes to great lengths to assure that you do not
need to ever worry about having to explicitly do any of those data
processing chores.  Certainly methods exist for doing those data
processing chores, but it should never be necessary to call them
explicitly.  (If you find a case where you need to do so, please
consider that as a bug and report it to Bruce.)

:demeter:`demeter` keeps track of the state of the Data object and
will re-perform data processing steps as necessary. For example, if
you change the value of one of the back-Fourier transform range
attributes, :demeter:`demeter` will know that the back-transform must
be recomputed the next time the |chi| (q) data is in some way
used. Similarly, if a background removal attribute is changed, then
:demeter:`demeter` will know that all steps of data processing must be
re-done.

:demeter:`demeter` is also aware of what data processing steps must be
up-to-date in order to properly perform any method, including
plotting. Thus if you do this:

.. code-block:: perl
      
   $data -> plot('k');

:demeter:`demeter` knows to check wether the background removal,
normalization, and forward transform are up to date and to perform
them if they are not.

Plotting in the four spaces is quite straightforward:

**plot in energy**
   .. code-block:: perl
      
       $data->plot('E');

**plot in k**
   .. code-block:: perl
      
       $data->plot('k');

**plot in R**
   .. code-block:: perl
      
       $data->plot('R');

**plot in back-transform k**
   .. code-block:: perl
      
       $data->plot('q');

There are also a number of pre-defined, specialty plots. 

.. todo:: Show examples of rmr, r123, k123, and kq.

**plot the magnitude and real part of chi(R)**
   .. code-block:: perl
      
       $data->plot('rmr');

**plot chi(k) with k-weights of 1, 2, and 3, scaled to be the same size**
   .. code-block:: perl
      
       $data->plot('k123');

**plot chi(R) with k-weights of 1, 2, and 3, scaled to be the same size**
   .. code-block:: perl
      
       $data->plot('R123');

**plot in chi(k) with the real part of chi(q)**
   .. code-block:: perl
      
       $data->plot('kq');

**quad plot with data in all four spaces**
   .. code-block:: perl
      
       $data->plot('quad');


   .. _fig-quadplot:

   .. figure:: ../../_images/plot_quad.png
      :target: ../_images/plot_quad.png
      :align: left

      This quad plot shows data on an Fe foil in all four spaces. The
      current value of k-weighting in the Plot object is used in this
      kind of plot.  *This kind of plot cannot be made with the pgplot
      plotting backend.*


There are two more pre-packaged plot types which are specifically about
visualizing merged data and its standard deviation:

.. code-block:: perl

   $data->plot('stddev');
   $data->plot('variance'); 

See `the section on merged data <../mue/merge.html>`__ for details of
those two plot types.

Finally, it is plossible to plot |chi| (k) data in energy. This is done by
setting the ``chie`` attribute of the Plot object to a true value. When
that attribute is true and the data are plotted in k, the x-axis values
will instead be absolute energy.

.. code-block:: perl

    $data -> po -> set(kweight => 2, space => 'k', chie => 1);
    $data -> plot;

Note that the argument of the ``plot`` method is case insensitive.
Little attempt is made to glean meaning from that argument.  If it is
not one of the strings shown above, the ``plot`` method will likely
return an error.



Plotting and overplotting
-------------------------

The ``plot`` method typically will overplot data, that is add a new
trace to the existing plot. If you wish to start a new plot, you must
explicitly do so, as shown on line 8 of this example.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $prj = Demeter::Data::Prj -> new(file=>'iron_data.prj');
    my ($data1, $data2) = $prj -> records(1,2);
    $_ -> plot('k') foreach ($data1, $data2);
    sleep 3;
    $data1 -> po -> start_plot;
    $_ -> plot('R') foreach ($data1, $data2);

The quad plot is an exception, however. There is an implicit
``start_plot`` when a quad plot is made.

The details of the funny syntax using the ``po`` method is explained in
`the section on the Plot object <../highlevel/plot.html>`__.



The singlefile plotting backend
-------------------------------

Although the :program:`PGPLOT` and :program:`Gnuplot` plotting
backends work just fine, sometimes you would like to be able to
replicate a particular plot in another plotting program. To that end,
:demeter:`demeter` provides a special plotting backend called the
:quoted:`SingleFile` backend. This will replicate a plot form of a
column data file. The data in those columns include whatever
y-offsets, energy shifts, or scaling factors were included in the
plot. The plot can then be replicated in another program simply by
importing and plotting the columns.

Here is an example. The fit is the standard copper fit. At the end, the
data, the fit, the window, and the paths are plotted usin the gnuplot
backend. Then, at line 67, the “SingleFile” backend is used to output
that plot to a file.

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter qw(:ui=screen);
    print "Sample fit to copper data demonstrating the singlefile plotting backend.\n";

    my $data = Demeter::Data -> new();
    $data->set_mode(screen  => 0, backend => 1);
    $data ->set(file       => "../../cu/cu10k.chi",
                fft_kmin   => 3,        fft_kmax   => 14,
                fit_space  => 'r',
                fit_k1     => 1,        fit_k3     => 1,
                bft_rmin   => 1.6,      bft_rmax   => 4.3,
                fit_do_bkg => 0,
                name       => 'My copper data',
               );

    my @gds =  (Demeter::GDS -> new(gds => 'guess', name => 'alpha', mathexp => 0),
                Demeter::GDS -> new(gds => 'guess', name => 'amp',   mathexp => 1),
                Demeter::GDS -> new(gds => 'guess', name => 'enot',  mathexp => 0),
                Demeter::GDS -> new(gds => 'guess', name => 'theta', mathexp => 500),
                Demeter::GDS -> new(gds => 'set',   name => 'temp',  mathexp => 300),
                Demeter::GDS -> new(gds => 'set',   name => 'sigmm', mathexp => 0.00052),
               );

    my $feff = Demeter::Feff->new(file=>'../../cu/orig.inp', screen=>0, workspace=>'temp/');
    $feff -> rmax(5);
    $feff -> run;
    my @sp = @{ $feff->pathlist };

    my @paths = ();
    foreach my $i (0 .. 4) {
      $paths[$i] = Demeter::Path -> new();
      $paths[$i]->set(data     => $data,
                      sp       => $sp[$i],
		      s02      => 'amp',
		      e0       => 'enot',
		      delr     => 'alpha*reff',
		      sigma2   => 'debye(temp, theta) + sigmm',
		     );
    };

    my $fit = Demeter::Fit -> new(gds   => \@gds,
                                  data  => [$data],
                                  paths => \@paths
                                 );

    $fit -> fit;

    ## plot normally using gnuplot
    $data->po->set(plot_data => 1, plot_fit  => 1,
                   plot_bkg  => 0, plot_res  => 0,
                   plot_win  => 1, plot_run  => 0,
                   kweight   => 2,
                   r_pl      => 'm', 'q_pl'    => 'r',
                  );
    $data->po->space('R');
    $data -> plot_with('gnuplot');
    my $step = 0;  # stack the plot interestingly...
    foreach my $obj ($data, @paths,) {
        $obj -> plot;
        $step -= 0.8;
        $data -> y_offset($step);
    };
    $data -> y_offset(0);
    $data -> pause;

    ## replicate that plot in a single file
    $data->plot_with('singlefile');           # 1: switch to single file backend
    $data -> po -> prep(file=>'nifty_plot.dat', standard=>$data, space=>'R');

    $step = 0;
    foreach my $obj ($data, @paths,) {        # 5: make the plot
        $obj -> plot;
        $step -= 0.8;
        $data -> y_offset($step);
    };
    $data -> y_offset(0);
    $data -> po -> finish;
    $data -> unset_standard;

Note that at line 68, some additional information is provided to make
the SingleFile output, including the name of the output file. A Data
object with data included in the file is set as the SingleFile standard.
The x-axis in the file will be the x-axis of that Data object. in the
case of a plot in energy, all other data will be interpolated onto that
energy grid.

The plot is then remade at lines 70-76. The ``finish`` method is called
at line 77 to actually write out the file. It is good practice to unset
the standard, as at line 78, to avoid future confusion.

The ``prep`` method at line 68 is a convenience method which does the
following:

.. code-block:: perl

   $data->po->space('R');
   $data->standard;
   $data->po->file('nifty_plot.dat');
   $data->po->start_plot;

Other odds and ends
-------------------

The ``plotkey`` atribute of the Data object is a convenient way to
override the label of a plotted object. Normally, the ``name`` attribute
is used for this purpose, but it is sometimes useful to not rename an
object but still provide a specific bit of text to use as a plotting
label.

