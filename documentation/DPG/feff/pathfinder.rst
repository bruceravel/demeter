
The path finder
===============

The path finder is the tool that digs through the atoms list in the
:file:`feff.inp` file and determines all possible scattering
geometries. This has been reimplemented in :demeter:`demeter` to add
some important features that are missing in :demeter:`feff`'s path
finder. Continuing with the example from the previous section, we can
use an instrumented Feff object to compute potentials. It is not
essential to run the potentials calculation (line 6) before the path
finder (line 7), however both must be run before anything else
(plotting, fitting) is done with the :demeter:`feff` calculation.

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter;

    my $feff = Demeter::Feff -> new(file => "feff/feff.inp");
    $feff -> set(workspace => "feff/", screen => 0,);
    $feff -> potph
    $feff -> pathfinder;

    $feff -> freeze("feff/feff.yaml");

At line 9, the attributes of the Feff object, including results of the
path finder, are written to a save file. This save file is in the `YAML
format <http://search.cpan.org/~adamk/YAML/>`__, which is a simple,
textual serialization format for data structures. As you will see in
subsequent sections, these YAML files (along with the phase.bin) can be
used to restore a :demeter:`feff` calculation for future use.


This can be made a little more efficient.  ``run`` at line 6 below is
a thin wrapper around the ``potph`` and ``pathfinder`` method calls.

.. code-block:: perl
   :linenos:

    #!/usr/bin/perl
    use Demeter;

    my $feff = Demeter::Feff -> new(file => "feff/feff.inp");
    $feff -> set(workspace => "feff/", screen => 0,);
    $feff -> run

The rest of this chapter will cover ways of finding out information
about the :demeter:`feff` calculation. The next chapter will cover in
detail how information from the :demeter:`feff` calculation is used to
create Path object and how those Path objects can be plotted and used
in a fitting model.



Comparing Pathfinders
---------------------

:demeter:`demeter`'s path finder has two huge advantages over :demeter:`feff`'s:

#. User configurable fuzzy degeneracy (explained in detail
   below). :demeter:`feff` considers paths that differ in length by
   0.00001 |AA| to be non-degenerate.

#. The scattering geometries of the degenerate paths are stored and
   are available for use and examination.  :demeter:`feff` discards
   the details of the degenerate paths.

:demeter:`feff`'s path finder, however, has its advantages over
:demeter:`demeter`'s.

#. As it is written in a compiled language, it is considerably faster.
   Fortunately, the path finder does not need to be called very often.

#. :demeter:`feff` uses its fast plane wave calculation to approximate
   the importance of path. Low importance paths can be removed from
   consideration, as can all higher order paths built from that path.
   :demeter:`demeter` does not have access to the plane wave
   calculation, so it must consider many more paths that
   :demeter:`feff`'s and relies instead on some simple heuristics to
   trim the tree of paths.

#. :demeter:`feff` path finder considers up to seven-legged
   paths. :demeter:`demeter` currently defaults to four-legged paths.
   Five- and six-legged paths are possible, but time-consuming.



Fuzzy degeneracy
----------------

As the path finder organizes all the scattering geometries it finds
among the atoms in the input atoms list, it will make a fuzzy
comparison to sort the paths into nearly-degenerate bins. That is, all
paths whose lengths are within a small margin will be considered
degenerate. The width of this bin is set by the
:configparam:`Pathfinder,fuzz` preference. Consider this
:file:`feff.inp` file:

::

     TITLE magnetoplumbite  PbFe_12O_19
     HOLE 4   1.0   *  Pb L3 edge  (13035.0 eV), second number is S0^2

     *         mphase,mpath,mfeff,mchi
     CONTROL   1      1     1     1
     PRINT     1      0     0     0

     RMAX        5.0

     POTENTIALS
     *    ipot   Z  element
            0   82   Pb        
            1   82   Pb        
            2   26   Fe        
            3    8   O         

     ATOMS                          * this list contains 39 atoms
     *   x          y          z      ipot  tag              distance
        0.00000    0.00000    0.00000  0 Pb1             0.00000
        1.65468    0.00003    2.30070  3 O_1             2.83393
       -0.82737   -1.43298    2.30070  3 O_1             2.83394
        1.65468    0.00003   -2.30070  3 O_1             2.83393
       -0.82737   -1.43298   -2.30070  3 O_1             2.83394
       -0.82737    1.43304    2.30070  3 O_2             2.83397
       -0.82737    1.43304   -2.30070  3 O_2             2.83397
        2.63123   -1.31552    0.00000  3 O_3             2.94176
       -0.17634   -2.93647    0.00000  3 O_3             2.94176
        2.63123    1.31558    0.00000  3 O_4             2.94179
       -2.45494   -1.62092    0.00000  3 O_4             2.94179
       -2.45494    1.62098    0.00000  3 O_5             2.94182
       -0.17634    2.93653    0.00000  3 O_5             2.94182
        1.69537   -2.93647    0.00000  2 Fe2_1           3.39074
       -3.39080    0.00003    0.00000  2 Fe2_2           3.39080
        1.69537    2.93653    0.00000  2 Fe2_2           3.39079
        0.83581   -1.44767    3.24399  2 Fe5_1           3.64936
        0.83581   -1.44767   -3.24399  2 Fe5_1           3.64936
       -1.67167    0.00003    3.24399  2 Fe5_2           3.64938
        0.83581    1.44772    3.24399  2 Fe5_2           3.64938
       -1.67167    0.00003   -3.24399  2 Fe5_2           3.64938
        0.83581    1.44772   -3.24399  2 Fe5_2           3.64938
        3.39074    0.00006    1.38042  2 Fe4_1           3.66097
       -1.69542   -2.93644    1.38042  2 Fe4_1           3.66097
        3.39074    0.00006   -1.38042  2 Fe4_1           3.66097
       -1.69542   -2.93644   -1.38042  2 Fe4_1           3.66097
       -1.69542    2.93656    1.38042  2 Fe4_2           3.66106
       -1.69542    2.93656   -1.38042  2 Fe4_2           3.66106
     END

Using the default :configparam:`Pathfinder,fuzz parameter` of 0.03
|AA|, will give these paths. Note that the ``Fe4`` and ``Fe5``
scatterers, which differ by about 0.11 |AA|, get merged into a single
scattering path with an R\ :sub:`eff` value that is the average of the
constituent paths.

::

    #     degen   Reff       scattering path                       I legs   type              
     0001   6    2.834  ----  <+> O_1    <+>                       2  2 single scattering     
     0002   6    2.942  ----  <+> O_3    <+>                       2  2 single scattering
     0003   3    3.391  ----  <+> Fe2_1  <+>                       2  2 single scattering
     0004  12    3.655  ----  <+> Fe5_1  <+>                       2  2 single scattering

Resetting the :configparam:`Pathfinder,fuzz` to 0.01 separates those
two nearly degenerate paths into separate scattering paths.

::

    #     degen   Reff       scattering path                       I legs   type              
     0001   6    2.834  ----  <+> O_1    <+>                       2  2 single scattering     
     0002   6    2.942  ----  <+> O_3    <+>                       2  2 single scattering     
     0003   3    3.391  ----  <+> Fe2_1  <+>                       2  2 single scattering     
     0004   6    3.649  ----  <+> Fe5_1  <+>                       2  2 single scattering
     0005   6    3.661  ----  <+> Fe4_1  <+>                       2  2 single scattering

