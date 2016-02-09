..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Athena project files
====================

The most convenient method for importing data into a :demeter:`demeter` program is
to import directly from an :demeter:`athena` project file. Presumably, you have
already used :demeter:`athena` to process your |mu| (E) data into an analysis-ready
form. When data are imported from a project file, all the attributes of
the Data object will be set using the values found in the project file.


Creating Data objects
---------------------

Importing data from an :demeter:`athena` project file is a two-step process. First
a Data::Prj object must be created to store information obtained from a
lexical analysis of the project file. Methods of the Data::Prj object
are then used to generate Data objects. Here is a simple example of
extracting the first record from a project file and creating a Data
object from that record.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $prj = Demeter::Data::Prj -> new(file=>'iron_data.prj');
    my $data = $prj -> record(1);
    $data -> plot('E');

The ``$data`` scalar contains a Data object. Internally, the ``record``
method does the following behind the scenes:

.. code-block:: perl

   $data = Demeter::Data->new();

then sets attributes from values in the project file.  It then pushes the
associated data arrays into :demeter:`ifeffit` (or :demeter:`larch`).

You can import several records at a time by specifying a list of record
identifiers:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $prj = Demeter::Data::Prj -> new(file=>'iron_data.prj');
    my @several = $prj -> records(2, 7, 12, 19);
    $_ -> plot('E') foreach @several;

Note that ``records`` is just an alias for ``record``. They point at the
same method. The two spellings are offered as a nod to English grammar.
The method will recognize if it is called in scalar or list context and
properly return a single Data object or an array of Data objects.

You can import all records easily using the ``slurp`` method.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $prj = Demeter::Data::Prj -> new(file=>'iron_data.prj');
    my @all = $prj -> slurp;
    $_ -> plot('E') foreach @all;


Obtaining other information from project files
----------------------------------------------

You can query an :demeter:`athena` project file for its content in
several ways. To obtain a listing of contents of the project file, use
the ``list`` method.

.. code-block:: perl

  print $prj -> list;
     ## ==prints==>
     #  #     record
     #  # -------------------------------------------
     #    1 : Iron foil
     #    2 : Iron oxide
     #    3 : Iron sulfide

To create a simple table of parameter values, supply a list of attribute
names to the ``list`` method.

.. code-block:: perl


  print $prj -> list(qw(bkg_rbkg fft_kmin));
    ## ==prints==>
    #  #     record         bkg_rbkg   fft_kmin
    #  # -------------------------------------------
    #    1 : Iron foil      1.6        2.0
    #    2 : Iron oxide     1.0        2.0
    #    3 : Iron sulfide   1.0        3.0

The ``list`` method is used extensively by the ``lsprj`` program, which
is distributed with :demeter:`demeter`.

The ``allnames`` method will return an array of record labels (the
strings in the groups list in :demeter:`athena`).  For complete
details on these methods, see the Demeter::Data::Prj documentation.

