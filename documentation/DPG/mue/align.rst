..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Aligning data
=============

:demeter:`demeter` uses a rather simple alignment algorithm. First,
one Data object is chosen as the alignment standard. The standard is
one that doesn't move |nd| other data are aligned to the standard by
applying an E\ :sub:`0` shift.  The derivative spectrum is computed
for both the standard and the data.  An E\ :sub:`0` shift and an
overall amplitude are the variable parameters used to fit the data to
the standard. The amplitude value is discard, but the fitted E\
:sub:`0` shift is set as the ``bkg_eshift`` attribute of the aligned
data.

This algorithm work quite well for good quality data. Although, even for
very good data, if it starts of many volts out of alignment, the fit is
likely to find a false minimum. If data start very far out of alignment,
you will likely need to set the ``bkg_eshift`` attribute by hadn to
something close before calling the ``align`` method.

Here is a simple example:

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl

    my $prj = Demeter::Data::Prj -> new(file=>'U_DNA.prj');
    my @data = $prj -> records(1, 2, 3, 4);

    ## ... set background removal and Fourier transform attributes for
    ##     each data set ...

    ## align to the standard
    $data[0]->align(@data);
    ## make all the E0 values the same
    $_->e0($data[0]) foreach @data[1..3];

Four data sets are imported at lines 3 and 4. By calling the ``align``
method on the first data set in the list at line 10, it is chosen as
the standard, i.e. the one that stays in place while the others are
shifted.  It is not a problem that the standard is passed as an
argument of the method. :demeter:`demeter` will notice this and do the
right thing.

Aligning does not also force the E\ :sub:`0` values to be the same, so
that is done as a separate step at line 12.

There is also an ``align_with_reference`` method (which has an alias
of ``alignwr``).  This will use the Data objects specified in the
``reference`` attribute of the standard and the data to perform the
alignment.  Here is how that works:

.. code-block:: perl

    #!/usr/bin/perl

    my $prj = Demeter::Data::Prj -> new(file=>'U_DNA.prj');
    my @data = $prj -> records(1, 2, 3, 4);

    $data[0]->reference($data[1]);
    $data[2]->reference($data[3]);

    ## align to the standard using the reference
    $data[0]->alignwr($data[2]);
    ## make the E0 values the same
    $data[2]->e0($data[0]);

.. todo:: Smoothing the derivative spectra before aligning is not yet
	  implemented.
