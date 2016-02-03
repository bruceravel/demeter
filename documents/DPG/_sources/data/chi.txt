..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

|chi| (k) data files
=====================

On occassion, you will need to import a data file containing |chi| (k)
data, that is, data that have already been processed to have the
background removed and to be properly normalized. This is allowed in
:demeter:`demeter` but is strongly discouraged. Many features of
:demeter:`demeter` that are nominally related to the |chi| (k) data
still make use of earlier aspects of the data processing. An example
of this is explained in `the section on sanity checking of fitting
models <../fit/sanity.html>`__. One of those sanity checks is to have
the beginning of the fitting range in R-space come before the R\
:sub:`bkg` value used in the background removal. That check cannot
possibly happen for a Data object that begins as imported |chi| (k)
data.

Importing |chi| (k) data is done like so:

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $data = Demeter::Data -> new(file      => "cu10k.chi",
                                    name      => '10K copper data',
                                    fft_kmin  => 3,    fft_kmax  => 14,
                                   );
    $data -> plot('k');

For a data file containing |chi| (k) data, it is usually not necessary
to explicitly identify the data as such. :demeter:`demeter` will
analyze the contents of the data file and recognize it as |chi| (k)
data. In the rare case that |chi| (k) data is not recognized as such,
it can be explicitly specified like so:

.. code-block:: perl

   $data -> datatype('chi');

Note also that data that are imported as |chi| (k) cannot be plotted in
energy. Attempting to do so will trigger an error and end your program.
Note that you can set attributes related to normalization or background
removal for a |chi| (k). Data object without consequence. Those attribute
values will mostly never be used but there is no penalty for accessing
them.
