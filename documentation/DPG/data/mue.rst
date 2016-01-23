
|mu| (E) data files
===================

The most basic form of data import is from a column data file with the
first and second columns including energy and |mu| (E). In that case, the
data has already been processed from its raw form and saved in this
immediately useful form.

Importing a data file of this sort is very simple, as shown in this
example:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new(file => "data/fe.060.xmu",
                                    name => 'Fe 60K',
                                   );
    $data -> plot('E');

As always, the program begins by importing the :demeter:`demeter` package. At line
4, the Data object is created -- as all :demeter:`demeter` objects are created --
by the ``new`` method. The object is given a name and the file
containing the data is specified. The name will be used whenever the
data needs to be identified, for instance in the legend of a plot.

For a data file containing |mu| (E) data, it is usually not necessary
to explicitly identify the data as such. :demeter:`demeter` will
analyze the contents of the data file and recognize it as |mu| (E)
data. In the rare case that |mu| (E) data is not recognized as such,
it can be explicitly specified like so:

.. code-block:: perl

   $data -> datatype('xmu');

Parameters for normalization, background removal, and Fourier transforms
are set as attributes of the Data object. In this example, several basic
data processing parameters (discussed in detail in the documentation for
the Demeter::Data module) are set using the ``set`` method.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new(file => "data/fe.060.xmu",
                                    name => 'Fe 60K',
                                   );
    $data -> set(bkg_rbkg    => 1.5,
                 bkg_spl1    => 0,    bkg_spl2    => 18,
                 bkg_nor1    => 100,  bkg_nor2    => 1800,
                 fft_kmax    => 3,    fft_kmin    => 17,
                );
    $data -> plot('E');


Setting attributes
------------------

Since the parameters used for normalization, background removal,
Fourier transforms are all implemented as normal Moose attributes,
they are accessed and evaluated as normal Moose attributes. There are
several ways of doing this, including those inherent to Moose and
those defined by the MooseX::SetGet module which comes with
:demeter:`demeter`.

To obtain ``bkg_rbkg``, the R\ :sub:`bkg` value for background removal,
you can do this:

.. code-block:: perl

   my $rbkg = $data -> bkg_rbkg; 

To set a new value for R\ :sub:`bkg`, do this:

.. code-block:: perl

      $data -> bkg_rbkg(1.2); 

Each attribute has an accessor method for getting and setting the value
of the attribute that has the same name as the attribute itself.

To get and set several parameters at a time, you can use the ``get`` and
``set`` methods, which are thin wrappers around the normal accessors:

.. code-block:: perl
		
   my @values = $data -> get('bkg_rbkg', 'bkg_nor1', 'bkg_nor2');
   $data -> set(bkg_rbkg => 1.2, bkg_nor1 => 50, bkg_nor2 => 600); 

Finally, parameters can be set at the time of object creation:

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new(file => "data/fe.060.xmu",
                                    name => 'Fe 60K',
                                    bkg_rbkg => 1.5,
                                    bkg_spl1 => 0,    bkg_spl2 => 18,
                                    bkg_nor1 => 100,  bkg_nor2 => 1800,
                                    fft_kmax => 3,    fft_kmin => 17,
                                   );

All the arguments of ``new`` are passed to the ``set`` method.
