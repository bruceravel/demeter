..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Atoms
=====



Input crystal data
------------------

The attributes of the Atoms object can be populated in one of three
ways, by reading an :file:`atoms.inp` file, by reading a `CIF
file <http://www.iucr.org/resources/cif>`__, or by setting the
attributes programmatically.

The format of the :file:`atoms.inp` file is documented elsewhere.
Importing data from one is as simple as specifying the file when the
Atoms object is created. In this example, an :file:`atoms.inp` file is
imported and an input file for :demeter:`feff6` is written to standard
output.

.. todo:: link to atoms.inp documentation

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $atoms = Demeter::Atoms->new(file => "ybco.inp");
    print $atoms->Write("feff6");

The command-line :demeter:`atoms` program that comes with
:demeter:`demeter` is longer than 5 lines, but does not really do much
beyond this example.

Importing crystal data from a CIF file is no more difficult, however
you need to explicitly tell the Atoms object that the input data is in
CIF format. The Atoms object assumes that the value of the ``file``
attribute points at an :file:`atoms.inp` file, so the ``cif``
attribute must be used to specify a CIF file.

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $atoms = Demeter::Atoms->new(cif => "Fe2N_ICSD.cif");
    print $atoms->Write("feff6");

The `STAR::Parser <http://pdb.sdsc.edu/STAR/index.html>`__ module is
used to interpret the CIF file. This is a quirky bit of code and my
understanding of it is not so deep. There are probably examples of CIF
files that do not get imported properly, but it seems to work in most
cases. You should consider a valid CIF file that cannot be imported by
:demeter:`demeter` to be a reportable :demeter:`demeter` bug.

CIF files can contain more than one structure. By default,
:demeter:`demeter` will import the first structure contained in the
CIF file. To specify another structure, use the ``record``
attribute. Note that the counting is zero based, so this example is
importing the second record in the CIF file.  In a GUI like
:demeter:`artemis`, it is probably wise to let the user count from 1
and to do the translation behind the scenes.

.. code-block:: perl


    #!/usr/bin/perl
    use Demeter;

    my $atoms = Demeter::Atoms->new(cif => "AuCl.cif", record=>1);
    print $atoms->Write("feff6");


Object methods
--------------


Manually inputing crystal data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Starting with this :file:`atoms.inp` file

::

    title YBCO: Y Ba2 Cu3 O7 
    space P M M M 
    rmax=5.2              a 3.823   b 3.886 c 11.681
    core=cu2
    atom
    ! At.type   x        y       z      tag
       Y       0.5      0.5     0.5   
       Ba      0.5      0.5     0.184
       Cu      0        0       0        cu1
       Cu      0        0       0.356    cu2
       O       0        0.5     0        o1
       O       0        0       0.158    o2
       O       0        0.5     0.379    o3
       O       0.5      0       0.377    o4

you can manually load up the attributes of the Atoms object.  This is
what the :demeter:`atoms` interface in :demeter:`artemis` does.  A
straight-forward, brute-force approach is shown in this example:

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter;

    my $atoms = Demeter::Atoms->new();
    $atoms -> set(a=>3.823, b=>3.886, c=>11.681);
    $atoms -> space('P M M M');
    ## add each site
    $atoms -> push_sites( join("|", 'Y',  0.5, 0.5, 0.5,   'y'  ) );
    $atoms -> push_sites( join("|", 'Ba', 0.5, 0.5, 0.184, 'ba' ) );
    $atoms -> push_sites( join("|", 'Cu', 0.0, 0.0, 0.0,   'cu1') );
    $atoms -> push_sites( join("|", 'Cu', 0.0, 0.0, 0.356, 'cu2') );
    $atoms -> push_sites( join("|", 'O',  0.0, 0.5, 0.0,   'o1' ) );
    $atoms -> push_sites( join("|", 'O',  0.0, 0.0, 0.158, 'o2' ) );
    $atoms -> push_sites( join("|", 'O',  0.0, 0.5, 0.379, 'o3' ) );
    $atoms -> push_sites( join("|", 'O',  0.5, 0.0, 0.377, 'o4' ) );
    $atoms -> core('cu2');
    $atoms -> set(rpath=>5.2, rmax => 8);
    print $atoms->Write("feff6");

Once all the data is set, simply call the ``Write`` method and the
object will take care of populating the cell and explanding the cluster.

Note the odd syntax in lines 8 through 15 for loading the ``sites``
attribute. The elements of that array are strings of
vertical-bar-separated values of 

 * element symbol
 * fractional x coordinate
 * fractional y coordinate
 * fractional z coordinate, and 
 * tag.

Note that the tag has a limit of 10 characters.

At line 16, the central atom is chosen by specifying a valid tag as the
value of the ``core`` attribute.


 

Other methods
-------------

.. todo::
   * Absorption calculations: xsec, deltamu density mcmaster i0 selfsig
     selfamp netsig
   * Mentions cluster and nclus attributes



Output
------

Output from the Atoms object is handled by the ``Write`` method. Note
that this is capitalized to avoid any possible confusion (by perl or by
a syntax highlighting text editor) with perl's `write
function <http://perldoc.perl.org/functions/write.html>`__, as shown in
this example:

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $atoms = Demeter::Atoms->new(file => "ybco.inp");
    print $atoms->Write("feff6");

There are several output targets, which are formatted using
`templates <../highlevel/dispose.html>`__ from the Atoms template set.
The output targets, i.e. the arguments of the ``Write`` method, that
come with :demeter:`demeter` are:

``feff6``
    Input file for :demeter:`feff6`.
``feff7``
    Input file for :demeter:`feff7` (which is not really very different from the
    :demeter:`feff6` input file).
``feff8``
    Input file for :demeter:`feff8`.
``atoms``
    Input file for :demeter:`atoms`. This used as the save-file target for a GUI.
``p1``
    Input file for :demeter:`atoms` using the ``P 1`` spacegroup and the fully
    populated unit cell. Here's an example:

    ::

        title = YBCO: Y Ba2 Cu3 O7
        space = P M M M
        a     =   3.82300    b    =   3.88600    c     =  11.68100
        alpha =  90.00000    beta =  90.00000    gamma =  90.00000
        rmax  =   5.20000    core  = cu2
        shift =
        atoms
        # el.     x           y           z        tag
          Y      0.50000     0.50000     0.50000   Y
          Ba     0.50000     0.50000     0.18400   Ba
          Ba     0.50000     0.50000     0.81600   Ba
          Cu     0.00000     0.00000     0.00000   cu1
          Cu     0.00000     0.00000     0.35600   cu2
          Cu     0.00000     0.00000     0.64400   cu2
          O      0.00000     0.50000     0.00000   o1
          O      0.00000     0.00000     0.15800   o2
          O      0.00000     0.00000     0.84200   o2
          O      0.00000     0.50000     0.37900   o3
          O      0.00000     0.50000     0.62100   o3
          O      0.50000     0.00000     0.37700   o4
          O      0.50000     0.00000     0.62300   o4

 

``absorption``
    A file containing several interesting calculations using tables of
    absorption coefficients. Here's an example:

    ::

        ## --*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--
        ##  total mu*x=1:  8.160 microns,  unit edge step:  23.243 microns
        ##  specific gravity:  6.375
        ## --*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--
        ##  normalization correction:     0.00046 ang^2
        ## --*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--*--



``spacegroup``
    A file containing a description of the space group. Here's an
    example:

    ::

        # title = YBCO: Y Ba2 Cu3 O7
        # space = P M M M
        # a     =   3.82300    b    =   3.88600    c     =  11.68100
        # alpha =  90.00000    beta =  90.00000    gamma =  90.00000
        # rmax  =   5.20000    core  = cu2
        # shift =
        # atoms
        # # el.     x           y           z        tag
        #   Y      0.50000     0.50000     0.50000   Y
        #   Ba     0.50000     0.50000     0.18400   Ba
        #   Cu     0.00000     0.00000     0.00000   cu1
        #   Cu     0.00000     0.00000     0.35600   cu2
        #   O      0.00000     0.50000     0.00000   o1
        #   O      0.00000     0.00000     0.15800   o2
        #   O      0.00000     0.50000     0.37900   o3
        #   O      0.50000     0.00000     0.37700   o4

        Spacegroup P M M M (#47)

          Schoenflies: D_2h^1
          Full symbol: p 2/m 2/m 2/m
          New symbol : 
          Thirtyfive : 
          Nicknames  : 

          Common shift vector:
              

          Bravais translations:

          8 positions:
               x         y         z
              -x        -y         z
              -x         y        -z
               x        -y        -z
              -x        -y        -z
               x         y        -z
               x        -y         z
              -x         y         z

.. todo:: Show overfull, xyz, and alchemy output



