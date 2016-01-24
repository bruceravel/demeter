..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Multichannel data files
=======================

Often data files contain multiple columns of data that can be
independently processed as |mu| (E) data. One way of handling that
situation is to simply point several Data objects at the same file,
specifying different columns for each object. That is fine and it
certainly works, but it makes inefficient use of :demeter:`ifeffit`.

Each time that a Data object imports its data file, it makes temporary
arrays in :demeter:`ifeffit` to hold the contents of each column. The creation and
destruction of a possibly large number of unused arrays is noticeably
time consuming. To get around the problem of repeatedly creating the
same set of temporary arrays, use the Data::MultiChannel object.


Importing multi-element detector data
-------------------------------------

Like the `Data::Prj object <athena.html>`__, The Data::MultiChannel
object is a transitional object from which Data objects are created.

In this example, a four-element detector was used to measure
fluorescence data and each data channel is imported into an individual
Data object. Once all the channels are imported, they are plotted in
energy for direct comparison.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $file = 'med_data.000'
    my $mc = Demeter::Data::MultiChannel->new(file   => $file, energy => '$1', );
    $data[0] = $mc->make_data(numerator   => '$4', denominator => '$2',
                              ln          =>  0,   name        => 'MED Channel 1', );
    $data[1] = $mc->make_data(numerator   => '$5', denominator => '$2',
                              ln          =>  0,   name        => 'MED Channel 2', );
    $data[2] = $mc->make_data(numerator   => '$6', denominator => '$2',
                              ln          =>  0,   name        => 'MED Channel 3', );
    $data[3] = $mc->make_data(numerator   => '$7', denominator => '$2',
                              ln          =>  0,   name        => 'MED Channel 4', );
    $_ -> plot('E') foreach @data;

The Data::MultiChannel object is defined at line 5. This object is
inherited from the normal Data object, which allows it to use the Data
object's existing methods for file import. Although the
Data::MultiChannel object has all the same attributes as the Data
object, the only two that matter are ``file`` and ``energy``. The column
containing the energy must be specified so that the data can be sorted
(:demeter:`demeter` deals gracefully with data that are not in monotonically
ascending order, which sometimes happens in some impementations of quick
XAS). This value for the ``energy`` attribute is pushed onto the Data
object created using the ``make_data`` method.

The ``make_data`` method is used to generate a Data object from the
Data::MultiChannel object. You **must** specify the ``numerator``,
``denominator``, and ``ln`` attributes as arguments of the ``make_data``
method. You can specify any other Data attributes in the same manner as
the Data creator method, ``new``.

Once created by ``make_data``, these Data objects are identical in every
way to Data objects created in other ways.

Of course, another option is to use a normal Data object to import MED
data and do the summation on the fly, like so

.. code-block:: perl

      $data = Demeter::Data->new(numerator   => '$4+$5+$6+$7', denominator => '$2',
                                 ln          => 0,             name        => 'MED data' ); 

The performance penalty discussed above wouold not be a problem for the
on-the-fly summation. However, importing each individual channel into
its own Data object is certainly better done with the Data::MultiChannel
transitional object.


 

Importing data and reference
----------------------------

Another common use of the Data::MultiChannel object is to import the
reference channel from a normal XAS data file. Here is an example:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $file = 'fe2o3.000'
    my $mc = Demeter::Data::MultiChannel->new(file   => $file, energy => '$1', );

    $data = $mc->make_data(numerator   => '$2', denominator => '$3',
                           ln          => 1,    name        => 'Fe2O3' );
    $ref  = $mc->make_data(numerator   => '$3', denominator => '$4',
                           ln          => 1,    name        => '  Ref Fe2O3 (Fe foil)' );
    $data -> reference($ref);

In this example, the data are from a transmission experiment with a
reference foil between the I\ :sub:`t` and I\ :sub:`r` detectors. In
this case, |mu| (E) for the reference is ln(I\ :sub:`t`/I:sub:`r`), which
are in columns 3 and 4. Line 11 then sets up the data/reference
relationship so that energy shifts applied to the reference will also be
applied to the data.


 

Multicolumn transmission data
-----------------------------

Using the four-channel ionization chamber described in B. Ravel, et al.,
*J. Synchrotron Rad.*, **17**, (2010) p. 380 yields files which contain
four independent transmission measurements on a common energy axis. For
each measurement, there is a I\ :sub:`0` and an I\ :sub:`t` column. The following
script disentangles these columns by constructing the four measurements,
plotting the four XANES spectra, and writing out an :demeter:`athena` project file.

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter; # qw(:plotwith=gnuplot);
    use File::Basename;

    my $datafile = shift(@ARGV);    # take file name from command line
    my $mc = Demeter::Data::MultiChannel->new(file   => $file, energy => '$1', );
    $mc -> po -> set(title => $datafile, e_norm=>1, e_markers=>0, emin=>-40, emax=>60);
    $mc -> po -> start_plot;

    my @data;
    print "channel 1, ";
    $data[0] = $mc->make_data(numerator   => '$2', denominator => '$6',
                              ln          =>  1,   name        => 'channel 1', ) -> plot('e');
    print "channel 2, ";
    $data[1] = $mc->make_data(numerator   => '$3', denominator => '$7',
                              ln          =>  1,   name        => 'channel 2', ) -> plot('e');
    print "channel 3, ";
    $data[2] = $mc->make_data(numerator   => '$4', denominator => '$8',
                              ln          =>  1,   name        => 'channel 3', ) -> plot('e');
    print "channel 4, ";
    $data[3] = $mc->make_data(numerator   => '$5', denominator => '$9',
                              ln          =>  1,   name        => 'channel 4', ) -> plot('e');
    print "reference, ";
    $data[4] = $mc->make_data(numerator   => '$9', denominator => '$10',
                              ln          =>  1,   name        => "$file Ref", );

    my $prjname = basename($datafile) . '.prj';
    print "exporting $prjfile ... ";
    $data[0]->write_athena($prjfile, @data);
    print $/;
    $data[0]->po->end_plot;
    $mc->discard;

Note that, at this time, the data/reference relationship can only be
made between two Data objects. In a future version of :demeter:`demeter`, the
reference relationship will be extended to an arbitrary number of Data
objects, which will be useful in this case, as well as for MED data.
