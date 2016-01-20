
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
method does the following

setting attributes appropriately and pushing the associated data arrays
into :demeter:`ifeffit`.

You can import several records at a time by specifying a list of record
identifiers:

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $prj = Demeter::Data::Prj -> new(file=>'iron_data.prj');
    my @several = $prj -> records(2, 7, 12, 19);
    $_ -> plot('E') foreach @several;

Note that ``records`` is just an alias for ``record``. They point at the
same method. The two spellings are offered as a nod to English grammer.
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

You can query an :demeter:`athena` project file for its content in several ways. To
obtain a listing of contents of the project file, use the ``list``
method.

To create a simple table of parameter values, supply a list of attribute
names to the ``list`` method.

The ``list`` method is used extensively by the ``lsprj`` program, which
is distributed with :demeter:`demeter`.

The ``allnames`` method will return an array of record labels (the
strings in the groups list in :demeter:`athena`). For complete details on these
methods, see the Demeter::Data::Prj documentation.

