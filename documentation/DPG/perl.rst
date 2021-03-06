..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Using perl to structure a fit
=============================

It is very helpful to make use of perl's data structures and control
structures when precessing large quatities of data. In this example, a
list of attribute names and values common to all Data objects is defined
starting at line 4 and then pushed onto each Data object at line before
plotting at line 13. Because attributes were updated, the plot will
trigger all appropriate data processing steps.

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter;

    my @params = (bkg_pre1    => -30,  bkg_pre2    => -150,
                  bkg_nor1    => 150,  bkg_nor2    => 1757.5,
                  bkg_spl1    => 0.5,  bkg_spl2    => 22,
                  fft_kmax    => 3,    fft_kmin    => 14,);

    my $prj = Demeter::Data::Prj -> new(file=>'iron_data.prj');
    my ($data1, $data2) = $prj -> records(1,2);
    foreach my $obj ($data1, $data2) {
       $obj -> set(@params);
       $obj -> plot('R');
    };

Using perl's control structures
-------------------------------

Using perl


Cloning Demeter objects
-----------------------

Cloning
