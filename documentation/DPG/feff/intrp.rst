
Path interpretation
===================

The hard part of using :demeter:`feff` effectively is keeping track of
all the paths. The main tool :demeter:`demeter` offers for this is the
path interpretation.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $feff = Demeter::Feff -> new(file => "feff/feff.inp");
    $feff -> set(workspace => "feff/", screen => 0,);
    $feff -> potph
    $feff -> pathfinder;
    print $feff -> intrp;

or, using the serialization file introduced in the last section,

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $feff = Demeter::Feff -> new(yaml => "feff/feff.yaml");
    print $feff -> intrp;

Here is what gets printed out by the line with the ``intrp`` method:

::

    # Hg at site 15 in thymidine            
    # This paths.dat file was written by Demeter 0.3.0
    # The central atom is denoted by this token: <+>  
    # Cluster size = 4.50000 Angstrom, containing 21 atoms
    # 23 paths were found                                  
    # Forward scattering cutoff 25.00                      
    # Distance fuzz = 0.0300 Angstroms
    # Angle fuzz = 3.0000 degrees                          
    # Suppressing eta: yes                                 
    # -------------------------------------------------------------------------------
    #     degen   Reff       scattering path                       I legs   type
     0001   1    2.040  ----  <+> N16    <+>                       2  2 single scattering
     0002   2    2.923  ----  <+> C      <+>                       2  2 single scattering
     0003   2    3.036  ----  <+> O      <+>                       2  2 single scattering
     0004   4    3.171  ----  <+> C      N16    <+>                1  3 obtuse triangle
     0005   2    3.418  ----  <+> N16    C      N16    <+>         0  4 dog-leg
     0006   4    3.591  ----  <+> C      O      <+>                0  3 other double scattering
     0007   4    3.676  ----  <+> O      N16    <+>                0  3 other double scattering
     0008   1    4.080  ----  <+> N16    <+>    N16    <+>         1  4 rattle
     0009   2    4.146  ----  <+> C      O      C      <+>         0  4 dog-leg
     0010   2    4.159  ----  <+> C      C      <+>                1  3 acute triangle
     0011   1    4.191  ----  <+> N13    <+>                       2  2 single scattering
     0012   2    4.244  ----  <+> N13    C      <+>                1  3 obtuse triangle
     0013   2    4.258  ----  <+> O      C      O      <+>         0  4 dog-leg
     0014   1    4.263  ----  <+> C      <+>                       2  2 single scattering
     0015   2    4.267  ----  <+> N13    N16    <+>                1  3 obtuse triangle
     0016   2    4.301  ----  <+> C      N16    C      <+>         0  4 dog-leg
     0017   1    4.297  ----  <+> C      N13    C      <+>         0  4 dog-leg
     0018   2    4.317  ----  <+> N16    O      N16    <+>         0  4 dog-leg
     0019   2    4.314  ----  <+> C      C      <+>                1  3 obtuse triangle
     0020   2    4.342  ----  <+> N16    C      <+>                1  3 obtuse triangle
     0021   1    4.343  ----  <+> N16    N13    N16    <+>         0  4 dog-leg
     0022   1    4.364  ----  <+> C      C      C      <+>         0  4 dog-leg
     0023   1    4.420  ----  <+> N16    C      N16    <+>         0  4 dog-leg

This should be familiar to the :demeter:`artemis` user. The paths are
presented in order of increasing half-path-length and each line
provides an overview of the geometry of the path, starting with the
degeneracy, the half-path-length, and a textual description of the
atoms in the path.

The line labeled *I* is the :quoted:`importance` of the path.  This is
an integer -- 0, 1, or 2 -- which :demeter:`demeter` assigns based on
some heuristics for the likelihood that the path will contribute
significantly to the fit. The high importance paths with value 2 are
the single scattering and colinear multiple scattering paths. The mid
importance paths tend to be short triangles.

The last column is a description of the shape of the path. The header
contains some statistics about the cluster and the values of some of the
relevant configuration parameters.

As you will see in the next chapter, there is a way of obtaining a
single lines from the path interpretation.



Interpretaton output targets.
-----------------------------

The ``intrp`` method can take an optional argument which is used to
format the path interpretation. The argument can be either a string or
`an anonymous hash <http://perldoc.perl.org/perlref.html>`__. The
string can be either ``latex`` or ``css``. With those, the path
interpretation will be mark-up such that it can be inserted into a
latex document using a tabular environment or into an html document
using CSS and span tags to format the text. This formatting works by
inserting text at the beginning and ending of each line appropriate to
the header or to the importance of the path.

The anonymous hash option allows you to specify a different set of
starting and ending tags for the lines in the interpretation. It looks
like this:

The command line ``intrp`` program that comes with :demeter:`demeter`
colorizes the text on the screen by assigning ANSI color control
sequences as the values of the anonymous hash.

