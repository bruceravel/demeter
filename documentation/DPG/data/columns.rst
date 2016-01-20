
Column data files
=================

The most common situation for data import involves raw data from a
beamline. In this case, :demeter:`demeter` assumes that your data are
in columns, that one of the columns represents energy, and that two or
more of the remaining columns represent signals on the various
detectors. You must explicitly specify which column is which when you
define the Data object.

Transmission data
-----------------

This first example is for a file containing transmission XAS data:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new();
    $data -> set(file        => "data/fe.060.dat",
                 name        => 'Fe 60K',
                 energy      => '$1', # column 1 is energy
                 numerator   => '$2', # column 2 is I0
                 denominator => '$3', # column 3 is It
                 ln          => 1,    # these are transmission data
                );
    $data -> plot('E');

The details of how to turn the columns into |mu| (E) data are given at
lines 7 to 10. The energy column is identified as the first column in
the data file. The manner in which the columns are identified,
i.e. the use of the dollar sign (``$``) is borrowed from the Gnuplot
plotting program.  This introduces a potential stumbling block in a
perl script. The ``$`` symbol is, of course, the sigil denoting a
scalar in perl and things like ``$1`` and ``$2`` are the text
capturing special variables (see `the perlvar document
<http://perldoc.perl.org/perlvar.html>`__ for details). It is
therefore necessary to single-quote the column specifiers to avoid
having the ``$`` symbols iterpolated, as they would be with double
quotes. Another useful syntax for column speficiation would be to use
`the non-interpolating quote operator
<http://perldoc.perl.org/perlop.html#Quote-and-Quote-like-Operators>`__,
like so:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new();
    $data -> set(file        => "data/fe.060.dat",
                 name        => 'Fe 60K',
                 energy      => q{$1}, # column 1 is energy
                 numerator   => q{$2}, # column 2 is I0
                 denominator => q{$3}, # column 3 is It
                 ln          => 1,     # these are transmission data
                );

Once the file is imported and the column information is given, the Data
object can be used for other things, such as plotting or using in a fit.
Using the Data object in various ways will be discussed in later
sections of the document.

That these are transmission data is indicated by the value of the
``ln`` attribute. Set to 1, the columns will be processed as
transmission data, i.e. |mu| (E)=ln(I\ :sub:`0`/I\ :sub:`t`) . Set to
0 (or unspecified as zero is the default), the columns will be
processed as fluorescence data, i.e.  |mu| (E)=I\ :sub:`f`/I\
:sub:`0`.

In this example, the I₀ detector is in column 2 of the data file and the
I\ :sub:`t` detector is in column 3.

--------------

 

Fluorescence data
-----------------

The next example is for a file containing fluorescence XAS data:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new();
    $data -> set(file        => 'soil.dat',
                 name        => 'dilute soil sample',
                 energy      => '$1',  # column 1 is energy
                 numerator   => '$4',  # column 4 is If
                 denominator => '$2',  # column 2 is I0
                 ln          => 0,     # these are fluorescence data
                );

Here the ``ln`` attribute is set to 0 to indicate that these are
fluorescence data. The ``numerator`` attribute is set to the column
containing the fluorescence detector and the ``denominator`` attribute
is set to the I\ :sub:`0` column. Again, once the file is imported and
the columns are set, the Data object is ready for use.

 

Multi-element detector fluorescence data
----------------------------------------

When fluorescence data is measured using a multi-element detector (MED),
you will want to sum up the detector channels before dividing by I\ :sub:`0`.
This is accomplished by adding multiple channels in the ``numerator``
attribute:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new();
    $data -> set(file        => 'soil.dat',
                 name        => 'dilute soil sample',
                 energy      => '$1',
                 numerator   => '$4+$5+$6+$7',  # four fluo channels
                 denominator => '$2',
                 ln          => 0,
                );

This will add up the contents of columns 4 through 7 then divide by
column 2.

You may also wish to import each channel of the MED into individual Data
groups so each channel may be examined, processed, and plotted
individually. An efficient way of doing so is explained in `the section
on multichannel data <mc.html>`__.


 

Preprocessing column data on the fly
------------------------------------

You may have some reason to do a bit of additional processing of the
columns in the data file. As an example, the `data handling section of
the Ifeffit FAQ <http://cars9.uchicago.edu/iffwiki/FAQ/Data_Handling>`__
explains how to import data from the Ferrel Lytle database which were
recorded as a function of motor position for the monochromator angle.
For data like thse, it is necessary to convert motor position to energy
using some knowledge of the monochromator crystal and motor and a few
fundamental constants. This can be implemented in DEMETER like so:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    ## d-spacing = 1.92017    steps/deg = 4000    hc = 12398.61    rads->degs = 57.29577951
    my $data = Demeter::Data -> new();
    $data -> set(file        => "lytle.dat",
                 name        => 'Fe 60K',
                 energy      => '12398.61 / (2*1.92017) / sin($1/(57.29577951*4000))',
                 numerator   => '$2',
                 denominator => '$3',
                 ln          => 1,
                );
    $data -> plot('E');

As another example, you might wish to do a simple deadtime correction
for MED data based on the measured input and output count-rates of the
detectors. This information is often recorded as columns in the data
file so that this deadtime correction can be applied as needed. The
basic concept of the deadtime correction is that the ratio of the input
and output count-rates for the entire energy range of the detector is an
accurate measure of the lost count rate in any region of interest (ROI)
of the detector. Thus the counts in the ROI can be corrected by
multiplying by the measured input/output ratio. This can be implemented
for a single channel like so:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new();
    $data -> set(file        => 'soil.dat',
                 name        => 'dilute soil sample, DT corrected',
                 energy      => '$1',
                 numerator   => '$4*$8/$12',
                 denominator => '$2',
                 ln          => 0,
                );

In this example, column 4 contains the signal in the ROI for one of the
detector channels, column 8 contains the input count rate for the
channel, and column 12 contains the output count rate for that channel.

Note that there is no simple way to recover the signal in the ROI
channel once this pre-processing is done. If you wish to compare
dead-time corrected data with the uncorrected data, you should create
two separete Data objects. This is best accomplished using the efficient
technique explained in `the section on multichannel data <mc.html>`__.
