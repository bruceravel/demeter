..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Understanding and denoting space groups
=======================================


Notation conventions
--------------------

The two most commonly used standards for the designation of three
dimensional space groups are the `Hermann-Maguin
<https://en.wikipedia.org/wiki/Hermann%E2%80%93Mauguin_notation>`_ and
`Schoenflies <https://en.wikipedia.org/wiki/Schoenflies_notation>`_
conventions. :demeter:`atoms` recognizes both conventions. Each of the
230 space groups as designated in each convention is listed later in
this chapter.

The Hermann-Maguin system uses four symbols to uniquely specify the
group properties of each of the 230 space groups. The first symbol is a
single letter ``P``, ``I``, ``R``, ``F``, ``A``, ``B``, or ``C`` which
refers to the Bravais lattice type. The remaining three letters refer to
the point group of the crystal.

Some modifications to the notation convention are made for use with a
keyboard. Spaces must separate each of the four symbols. Subscripted
numbers are printed next to the number being modified (e.g. 6\ :sub:`3`
is printed as ``63``). A bar above a number is entered with a minus
sign.

Occasionally there are variations in how space groups are referenced.
For example, the hausmannite structure of Mn\ :sub:`3`\ O\ :sub:`4` is
placed in space group ``I 41/A M D`` by the conventions laid out in
`The International Tables <http://it.iucr.org/A/>`_.  In *Crystal
Structures* v. 3, Wyckoff denotes this space group as ``I 4/A M
D``. This sort of incongruity is unfortunate. The list of
Hermann-Maguin space group designations as recognized by
:demeter:`atoms` is shown below. If you cannot resolve the incongruity
using this list, try using the Schoenflies notation.

.. bibliography:: ../artemis.bib
   :filter: author % "Wyckoff" or title % "International"
   :list: bullet


The Schoenflies conventions are also recognized by :demeter:`atoms`.
In the literature there is less variation in the application of these
conventions.  The Schoenflies convention is, in fact, less precise
than the Hermann-Maguin in that the complete symmetry characteristics
of the crystal are not encoded in the space group
designation. Adaptations to the keyboard have been made here as
well. Subscripts are denoted with an underscore (``_``) and
superscripts are denoted with a caret (``^``).  Spaces are not allowed
in the keyboard designation.  A couple of examples: ``d_4^8``, and
``O_5``.  The underscore does not need to precede to
superscript. ``C_2V^9`` can also be written ``C_9^2V``.  Each of the
230 space groups as designated by the Schoenflies notation is listed
below in the same order as the listing of the Hermann-Maguin notation.
The two conventions are equally supported in the code.


Unique Crystallographic Positions
---------------------------------

The atoms list in :file:`atoms.inp` is a list of the unique
crystallographic sites in the unit cell. A unique site is one (and
only one) of a group of equivalent positions. The equivalent positions
are related to one another by the symmetry properties of the
crystal. :demeter:`atoms` determines the symmetry properties of the
crystal from the name of the space group and applies those symmetry
operations to each unique site to generate all of the equivalent
positions.

If you include more than one of a group of equivalent positions in the
atom list, then a few odd things will happen. A series of run-time
messages will issued telling you that atom positions were found that
were coincident in space. This is because each of the equivalent
positions generated the same set of points in the unit
cell. :demeter:`atoms` removes these redundancies from the atom
list. The atom list and the potentials list written to
:file:`feff.inp` will be correct and :demeter:`feff` can be run
correctly using this output. However, the site tags and the indexing
of the atoms will certainly make no sense. Also the density of the
crystal will be calculated incorrectly, thus the absorption
calculation and the self-absorption correction will be calculated
incorrectly as well. The McMaster correction is unaffected.


Specially Recognized Lattice Types
----------------------------------

For some common crystal types it is convenient to have a shorthand way
of designating the space group. For instance, one might remember that
copper is an fcc crystal, but not that it is in space group ``F M 3
M`` (or ``O_H^5``). In this spirit, :demeter:`atoms` will recognize
the following words for common crystal types. These words may be used
as the value of the keyword space and :demeter:`atoms` will supply the
correct space group. Note that several of the common crystal types are
in the same space groups. For copper it will still be necessary to
specify that an atom lies at (0,0,0), but it isn't necessary to
remember that the space group is ``F M 3 M``.


+----------------------+---------------------------+---------------+
| description          | shorthand                 | space group   |
+======================+===========================+===============+
| cubic                | ``cubic``                 | P M 3 M       |
+----------------------+---------------------------+---------------+
| body-centered cubic  | ``bcc``                   | I M 3 M       |
+----------------------+---------------------------+---------------+
| face-centered cubic  | ``fcc``                   | F M 3 M       |
+----------------------+---------------------------+---------------+
| halite               | ``salt`` or ``nacl``      | F M 3 M       |
+----------------------+---------------------------+---------------+
| zincblende           | ``zincblende`` or ``zns`` | F -4 3 M      |
+----------------------+---------------------------+---------------+
| cesium chloride      | ``cscl``                  | P M 3 M       |
+----------------------+---------------------------+---------------+
| perovskite           | ``perovskite``            | P M 3 M       |
+----------------------+---------------------------+---------------+
| diamond              | ``diamond``               | F D 3 M       |
+----------------------+---------------------------+---------------+
| hexagonal close pack | ``hex`` or ``hcp``        | P 63/M M C    |
+----------------------+---------------------------+---------------+
| graphite             | ``graphite``              | P 63 M C      |
+----------------------+---------------------------+---------------+

When ``space`` is set to ``hex``, ``hcp``, or ``graphite``, |gamma| is
automatically set to 120.



Bravais Lattice Conventions
---------------------------

:demeter:`atoms` assumes certain conventions for each of the Bravais
lattice types.  Listed here are the labeling conventions for the axes
and angles in each Bravais lattice.

- **Triclinic**: All axes and angles must be specified.

- **Monoclinic**: ``B`` is the perpendicular axis, thus |beta| is the
  angle not equal to 90.

- **Orthorhombic**: ``A``, ``B``, and ``C`` must all be specified.

- **Tetragonal**: The ``C`` axis is the unique axis in a tetragonal
  cell. The ``A`` and ``B`` axes are equivalent. Specify ``A`` and
  ``C`` in :file:`atoms.inp`.

- **Trigonal**: If the cell is rhombohedral then the three axes are
  equivalent as are the three angles. Specify ``A`` and |alpha|. If
  the cell has hexagonal axes, specify ``A`` and ``C``. |gamma| will
  be set to 120 by the program.

- **Hexagonal**: The equivalent axes are ``A`` and ``B``. Specify
  ``A`` and ``C`` in :file:`atoms.inp`. |gamma| will be set to 120 by the
  program.

- **Cubic**: Specify ``A`` in :file:`atoms.inp`. The other axes will
  be set equal to ``A`` and the angles will all be set to 90.


Low Symmetry Space Groups
-------------------------

In three dimensional space there is an ambiguity in choice of right
handed coordinate systems. Given a set of mutually orthogonal axes,
there are six choices for how to label the positive ``x``, ``y``, and
``z`` directions. For some specific physical problem, the
crystallographer might choose a non-standard setting for a crystal. The
choice of standard setting is described in detail in
``The International Tables``. The Hermann-Maguin symbol describes the
symmetries of the space group relative to this choice of coordinate
system.

The symbols for triclinic crystals and for crystals of high symmetry are
insensitive to choice of axes. Monoclinic and orthorhombic notations
reflect the choice of axes for those groups that possess a unique axis.
Tetragonal crystals may be rotated by 45 degrees about the z axis to
produce a unit cell of doubled volume and of a different Bravais type.
Alternative symbols for those space groups that have them are listed in
Appendix A.

:demeter:`atoms` recognizes those non-standard notations for these
crystal classes that are tabulated in ``The International
Tables``. :file:`atoms.inp` may use any of these alternate notations
so long as the specified cell dimensions and atomic positions are
consistent with the choice of notation. Any notation not tabulated in
chapter 6 of the 1969 edition of ``The International Tables`` will not
be recognized by :demeter:`atoms`.

This resolution of ambiguity in choice of coordinate system is one of
the main advantages of the Hermann-Maguin notation system over that of
Shoenflies. In a situation where a non-standard setting has been
chosen in the literature, use of the Schoenflies notation will, for
many space groups, result in unsatisfactory output from
:demeter:`atoms`. In these situations, :demeter:`atoms` requires the
use of the Hermann-Maguinn notation to resolve the choice of axes.

Here is an example. In the literature, La\ :sub:`2`\ CuO\ :sub:`4` was
given in the non-standard ``b m a b`` setting rather than the standard
``c m c a``. As you can see from the axes and coordinates, these
settings differ by a 90 degree rotation about the ``A`` axis. The
coordination geometry of the output atom list will be the same with
either of these input files, but the actual coordinates will reflect
this 90 degree rotation.

::

    title La2CuO4 structure at 10K from Radaelli et al.
    title standard setting
    space c m c a
    a= 5.3269 b= 13.1640 c= 5.3819
    rmax= 8.0 core= la
    atom
      la  0      0.3611   0.0074
      Cu  0      0        0
      O   0.25  -0.0068  -0.25    o1
      O   0      0.1835  -0.0332  o2

::

    title La2CuO4 structure at 10K from Radaelli et al.
    title non standard setting, rotated by 90 degrees about A axis
    space b m a b
    a= 5.3269 b= 5.3819 c= 13.1640
    rmax= 8.0 core= la
    atom
      la  0     -0.0074   0.3611
      Cu  0      0        0
      O   0.25   0.25    -0.0068   o1
      O   0      0.0332   0.1835   o2


Rhombohedral Space Groups
-------------------------

There are seven rhombohedral space groups. Crystals in any of these
space groups that may be represented as either monomolecular
rhombohedral cells or as trimolecular hexagonal cells. These two
representations are entirely equivalent. The rhombohedral space groups
are the ones beginning with the letter ``R`` in the Hermann-Maguin
notation. :demeter:`atoms` does not care which representation you use,
but a simple convention must be maintained. If the rhombohedral
representation is used then the keyword |alpha| must be specified in
:file:`atoms.inp` to designate the angle between the rhombohedral axes
and the keyword ``a`` must be specified to designate the length of the
rhombohedral axes. If the hexagonal representation is used, then ``a``
and ``c`` must be specified in :file:`atoms.inp`. |gamma| will be set
to 120 by the code. Atomic coordinates consistent with the choice of
axes must be used.


Multiple Origins and the Shift Keyword
--------------------------------------

Some space groups in *The International Tables* are listed with two
possible origins. The difference is only in which symmetry point is
placed at (0,0,0). :demeter:`atoms` always wants the orientation
labeled :quoted:`origin-at-centre`. This orientation places (0,0,0) at a point
of highest crystallographic symmetry. Wyckoff and other authors have
the unfortunate habit of not choosing the :quoted:`origin-at-centre`
orientation when there is a choice. Again Mn\ :sub:`3`\ O\ :sub:`4` is an
example. Wyckoff uses the :quoted:`origin at -4m2` option, which
places one Mn atom at (0,0,0) and another at (0,1/4,5/8).
:demeter:`atoms` wants the :quoted:`origin-at-centre` orientation
which places these atoms at (0,3/4,1/8) and (0,0,1/2). Admittedly,
this is an arcane and frustrating limitation of the code, but it is
not possible to conclusively check if the :quoted:`origin-at-centre`
orientation has been chosen.

Twenty one of the space groups are listed with two origins in *The
International Tables*. :demeter:`atoms` knows which groups these are
and by how much the two origins are offset, but **cannot** know if you
chose the correct one for your crystal. If you use one of these
groups, :demeter:`atoms` will print a run-time message warning you of
the potential problem and telling you by how much to shift the atomic
coordinates in :file:`atoms.inp` if the incorrect orientation was
used. This warning will also be printed at the top of the
:file:`feff.inp` file. If you use the :quoted:`origin-at-center`
orientation, you may ignore this message.

If you use one of these space groups, it usually isn't hard to know if
you have used the incorrect orientation. Some common problems include
atoms in the atom list that are very close together (less than 1
|AA|), unphysically large densities, and interatomic distances that do
not agree with values published in the crystallography
literature. Because it is tedious to edit the atomic coordinates in
the input file every time this problem is encountered and because
forcing the user to do arithmetic invites trouble, there is a useful
keyword called ``shift``. For the Mn\ :sub:`3`\ O\ :sub:`4` example
discussed above, simply insert this line in :file:`atoms.inp` if you have
supplied coordinates referenced to the incorrect origin:

::

      shift = 0.0  0.25 -0.125

This vector will be added to all of the coordinates in the atom list
after the input file is read.

Here is the input file for Mn\ :sub:`3`\ O\ :sub:`4` using the shift
keyword:

::

    title Mn3O4, hausmannite structure, using the shift keyword
    a       5.75    c       9.42  core    Mn2
    rmax    7.0     Space   i 41/a m d
    shift   0.0  0.25  -0.125
    atom
    * At       x   y    z     tag
      Mn      0.0 0.0  0.0    Mn1
      Mn      0.0 0.25 0.625  Mn2
      O       0.0 0.25 0.375

The above input file gives the same output as the following. Here the
shift keyword has been removed and the shift vector has been added to
all of the fractional coordinates. These two input files give equivalent
output.

::

    title Mn3O4, hausmannite structure, no shift keyword
    a       5.75    c       9.42  core      Mn2
    rmax    7.0     Space   i 41/a m d
    atom
    * At       x    y     z     tag
      Mn      0.0  0.25 -0.125  Mn1
      Mn      0.0  0.50  0.50   Mn2
      O       0.0  0.50  0.25



Denoting Space Groups
---------------------

The following is my attempt to demystify the crazy symbolism used by the
Hermann-Maguin and Schoenflies conventions. This is by no means an
adequate explanation of the rich and beautiful field of crystallography.
For that, I recommend a real crystallography text.

An important part of the demystification process is to define some of
the important terms used to describe crystal symmetries. The words
*system*, *Bravais lattice*, *crystal class*, and *space group* have
well-defined meanings. The symbols used in each of the notation
conventions specifically relate the various symmetries of crystals. In
crystallography, a symmetry operation is defined as a sequence of
reflections, translations, and/or rotations that map the crystal back
onto itself in such a way that the crystal after the mapping is
indistinguishable from the crystal before the mapping.



A Quick Review of Crystallography
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To start, here are some definitions. These will be elaborated below.

- **System**: The undecorated shape of the unit cell.

- **Bravais Lattice**: An undecorated lattice of equivalent points.

- **Crystal Class**: The description of the symmetries about a point.

- **Space Group**: The complete description of three dimensional
  crystal symmetries.

There are seven systems of crystals. The system refers to the shape of
the undecorated unit cell. They are:

- **Triclinic**: a |neq| b |neq| c, |alpha| |neq| |beta| |neq| |gamma| |neq| 90\ |deg|

- **Monoclinic**: a |neq| b |neq| c, |alpha| = |gamma| = 90\ |deg|, |beta| |neq| 90\ |deg|

- **Orthorhombic**: a |neq| b |neq| c, |alpha| = |beta| = |gamma| = 90\ |deg|

- **Tetragonal**: a = b |neq| c, |alpha| = |beta| = |gamma| = 90\ |deg|

- **Hexagonal**: a = b |neq| c, |alpha| = |beta| = 90\ |deg|, |gamma| = 120\ |deg|

- **Trigonal**: (rhombohedral axes): a = b = c, |alpha| = |beta| = |gamma| < 120\ |deg| & |neq| 90\ |deg|
  (hexagonal axes): a = b |neq| c, |alpha| = |beta| = 90\ |deg|, |gamma| = 120\ |deg|

- **Cubic**: a = b = c, |alpha| = |beta| = |gamma| = 90\ |deg|

There are fourteen Bravais lattices. The Bravais lattices are
constructed from the simplest translational symmetries applied to the
seven crystal systems. A ``P`` lattice has decoration only at the
corners of the unit cell. An ``I`` lattice has decoration at the body
center of the cell as well as at the corners. An ``F`` lattice has
decoration at the face centers as well as at the corners. A ``C``
lattice has decoration at the center of the (001) face as well as at the
corners. Likewise ``A`` and ``B`` lattices have decoration at the
centers of the (100) and (010) faces respectively. ``R`` lattices are a
special type in the trigonal system which possess rhombohedral symmetry.

All seven crystal systems have ``P`` lattices, but not all the classes
have the other type of Bravais lattices. This is because there is
degeneracy when all the Bravais lattice types are applied to all the
crystal systems. For example, a face centered tetragonal cell can be
expressed as a body centered tetragonal cell by rotating the two
equivalent axes by 45\ |deg| and shortening them by a factor of square
root of 2. Considering such degeneracies reduces the possible
decorations of the seven systems to these 14 unique three dimensional
lattices:

+---------------+------------+
| Lattice       | symbol     |
+===============+============+
|  Triclinic    | P          |
+---------------+------------+
|  Monoclinic   | P, C       |
+---------------+------------+
|  Orthorhombic | P, C, I, F |
+---------------+------------+
|  Tetragonal   | P, I       |
+---------------+------------+
|  Hexagonal    | P          |
+---------------+------------+
|  Trigonal     | P, R       |
+---------------+------------+
|  Cubic        | P, I, F    |
+---------------+------------+

For historic reasons, hexagonal cells are sometimes called ``C``
lattices. :demeter:`atoms` will recognize hexagonal ``P`` cells
denoted in :file:`atoms.inp` by the letter ``C``. Modern literature
usually uses the ``P`` designation.

The decorations placed on the Bravais lattices come in 32 flavors called
classes or point groups which represent the possible symmetries within
the decorations. Each type of symmetry is defined either by a reflection
plane, a rotation axis, or a rotary inversion axis. A reflection plane
can either be a simple mirror plane or a glide plane, which defines the
symmetry operation of reflecting through a mirror followed by
translating along a direction in the plane. A rotation axis can either
define a simple rotation or a screw rotation, which is the symmetry
operation of rotating about the axis followed by translating along that
axis. A rotary inversion axis defines the symmetry operation of
reflecting through a plane followed by rotating about an axis in that
plane.

These three symmetry types, reflection plane, rotation axis, and rotary
inversion axis, can be combined in 32 non-degenerate ways. (An example
degeneracy: the symmetry operation of combining a 180\ |deg| rotary inversion
with a mirror reflection is identical to the operation of a simple 180\ |deg|
rotation.) It would seem that the 32 classes could decorate the 14
Bravais lattices in 458 ways. In fact, the number might be larger as
there are numerous types of screw axes and glide planes. Again,
considering degeneracies reduces the total number of combinations,
leaving 230 unique decorations of the Bravais lattices. These are called
space groups. The 230 space groups are a rigorously complete set of
descriptions of crystal symmetries in three dimensional space. That is,
there may be new crystals but there are no new space groups. Here I am
only considering space-filling crystals with translational periodicity.
3-D Penrose structures and quasi-crystals are outside the realm of this
appendix and of the code.



Decoding the Hermann-Maguin Notation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Hermann-Maguin notation uses a set of two to four symbols to
completely specify the symmetries of a space group. The first symbol is
always a single letter specifying the Bravais lattice. The next three
symbols specify the class of the space group. These three symbols are
some combination of the following characters:

::

        1 2 3 4 5 6 A B C D M N / -

These are sufficient to completely specify the various planar and axial
symmetries of the classes and sub-classes. The following is a discussion
of the most important rules of this convention. Some details are
neglected but sufficient information is provided to appreciate the
information contained in the notation.

The second symbol in the Hermann-Maguin notation, i.e. the one after the
Bravais lattice symbol, tells about symmetries involving the primary
axis of the cell and/or of the plane normal to the primary axis. The
primary axis is defined as follows:

- **Triclinic**: none

- **Monoclinic**: the B axis

- **Orthorhombic**: the C axis

- **Tetragonal**: the C axis

- **Hexagonal**: the C axis

- **Trigonal**: the A axis

- **Cubic**: the A axis

In cubic or rhombohedral lattices the axes are equivalent, thus the
primary axis is arbitrary. For orthorhombic lattices the third and
fourth symbols specify the symmetries of the a and b axes respectively.
In other lattices, the last two symbols encode the remaining symmetries
as described below.

A space filling crystal will always show a symmetry when rotated through
``(360/n)`` degrees, where n is one of ``1``, ``2``, ``3``, ``4``, or
``6``. The second symbol often tells the rotational symmetry properties
of the primary axis. Notice that all trigonal, tetragonal, and hexagonal
groups have a ``3``, ``4``, or ``6`` respectively in their designations.
Many orthorhombic and monoclinic groups have a ``2``, which is the
highest degree of rotational symmetry available to those lattices. Cubic
groups may possess 2- or 4-fold rotational symmetry about the cell axes,
thus have ``2`` or ``4`` in the second symbol.

Many second symbols contain a second number. This is the subscripted
number when the Hermann-Maguin notation is typeset. This refers to the
type of screw symmetry associated with the axis. A screw symmetric
lattice is mapped onto itself by an anti-clockwise rotation through
``m*(360/n)`` degrees and a translation of ``1/n`` up the primary axis.
Here n is the degree of rotational symmetry, m is the type of screw, and
the definition of rotation and direction is right-handed. Two types of
screw symmetry that are different only in handedness of rotation are
called enantiomorphous. The enantiomorphous pairs are ``31`` and ``32``,
``41`` and ``43``, ``61`` and ``65``, and ``62`` and ``64``.

Several of the second symbols are one or two numbers followed by a slash
and a letter, e.g. ``P 63/M M C``. The letter specifies the type of
reflection plane that is normal to the rotation axis.

There are several types of reflection planes. The simplest is a mirror
plane, denoted by the letter ``M``. This says the crystal is mapped onto
itself by reflecting all atoms through a mirror placed in an appropriate
plane in the crystal. The letters ``A``, ``B``, or ``C`` denote glide
planes. These map the crystal onto itself by reflecting through the
plane then translating elements of the crystal by half the length of the
cell axis normal to the reflection plane. A ``D`` glide plane is similar
but involves translations of a quarter of the cell axis length. Finally,
the letter ``N`` denotes a diagonal glide plane, which is a reflection
through a plane followed by a translation in the same plane of half the
length of both cell axes in that plane.

The symbol ``-`` before a number indicates a rotary inversion axis. This
maps the crystal back onto itself by rotating through ``(360/n)``
degrees then reflecting through a plane parallel to the rotation axis.

A final word about the Hermann-Maguin notation, all cubic space groups
have four three-fold rotational axes through the body diagonals. Thus
all cubic groups have the number 3 as the third symbol, e.g.
``F M 3 M``.


Decoding the Schoenflies Notation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Schoenflies notation uses a set of three symbols to classify sets
of space groups by their dominant symmetry features. The letters
``C``, ``D``, ``S``, ``T``, and ``O`` denote the character of the
center of symmetry. The symbol after the underscore (the subscript
when typeset) indicates the presence of symmetry planes and additional
symmetry axes.  The number after the caret (the superscript when
typeset) is simply an indexing of all the distinct space groups that
share major symmetry properties. In the older literature, ``D``
symmetry centers are occasionally referred to as
``V``. :demeter:`atoms` will probably understand a space group
referred to by the letter ``V``, but using the ``D`` notation is
recommended.

The letter ``C`` indicates an rotation axis where the crystal is mapped
onto itself when rotated by ``(360/n)`` deg, where n is the number after
the underscore. An ``H`` after the underscore indicates the presence of
a plane of symmetry normal to the rotation axis. A ``V`` after the
underscore indicates one or two planes of symmetry parallel to the
rotation axis. The letter ``S`` after the underscore indicates a normal
plane of symmetry in a crystal where the degree of rotational symmetry
is 1. The letter ``I`` after the underscore indicates the presence of a
point center of symmetry.

The letter ``S`` indicates a rotary inversion axis. The degree of
rotation is the number after the underscore.

The letter ``D`` denotes a primary rotation axis with another rotation
axis normal to it. The degree of rotation of both axes is the number
after the underscore. The letters ``H`` and ``V`` have the same meanings
as they did in groups beginning with the letter ``C``. The letter ``D``
indicates the presence of a diagonal symmetry plane.

Cubic groups are all specified by the letters ``T`` and ``O``. ``T``
indicates tetrahedral symmetry, that is, the presence of the four
three-fold axes and three two-fold axes. ``O`` indicates octahedral
symmetry, i.e. four three-fold axes with three four-fold axes. ``H`` and
``D`` after the underscore carry the same meaning as before.


The Hermann-Maguin Notation
~~~~~~~~~~~~~~~~~~~~~~~~~~~


Notation for the Standard Settings
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**2 Triclinic and 13 Monoclinic Space Groups**

+------+-------+--------+-------+-------+--------+---------+
| [1]  |P 1    |P -1    |P 2    |P 21   |C 2     |P M      |
+------+-------+--------+-------+-------+--------+---------+
| [7]  |P C    |C M     |C C    |P 2/M  |P 21/M  |C 2/M    |
+------+-------+--------+-------+-------+--------+---------+
| [13] |P 2/C  |P 21/C  |C 2/C  |                          |
+------+-------+--------+-------+--------------------------+

**59 Orthorhombic Space Groups**


+----------+----------+----------+----------+----------+----------+----------+
| [16]     |P 2 2 2   |P 2 2 21  |P 21 21 2 |P 21 21 21|C 2 2 21  |C 2 2 2   |
+----------+----------+----------+----------+----------+----------+----------+
| [22]     |F 2 2 2   |I 2 2 2   |I 21 21 21|P M M 2   |P M C 21  |P C C 2   |
+----------+----------+----------+----------+----------+----------+----------+
| [28]     |P M A 2   |P C A 21  |P N C 2   |P M N 21  |P B A 2   |P N A 21  |
+----------+----------+----------+----------+----------+----------+----------+
| [34]     |P N N 2   |C M M 2   |C M C 21  |C C C 2   |A M M 2   |A B M 2   |
+----------+----------+----------+----------+----------+----------+----------+
| [40]     |A M A 2   |A B A 2   |F M M 2   |F D D 2   |I M M 2   |I B A 2   |
+----------+----------+----------+----------+----------+----------+----------+
| [46]     |I M A 2   |P M M M   |P N N N   |P C C M   |P B A N   |P M M A   |
+----------+----------+----------+----------+----------+----------+----------+
| [52]     |P N N A   |P M N A   |P C C A   |P B A M   |P C C N   |P B C M   |
+----------+----------+----------+----------+----------+----------+----------+
| [58]     |P N N M   |P M M N   |P B C N   |P B C A   |P N M A   |C M C M   |
+----------+----------+----------+----------+----------+----------+----------+
| [64]     |C M C A   |C M M M   |C C C M   |C M M A   |C C C A   |F M M M   |
+----------+----------+----------+----------+----------+----------+----------+
| [70]     |F D D D   |I M M M   |I B A M   |I B C A   |I M M A   |          |
+----------+----------+----------+----------+----------+----------+----------+

**68 Tetragonal Space Groups**


+----------+----------+----------+----------+----------+----------+------------+
| [75]     |P 4       |P 41      |P 42      |P 43      |I 4       |I 41        |
+----------+----------+----------+----------+----------+----------+------------+
| [81]     |P -4      |I -4      |P 4/M     |P 42/M    |P 4/N     |P 42/N      |
+----------+----------+----------+----------+----------+----------+------------+
| [87]     |I 4/M     |I 41/A    |P 4 2 2   |P 4 21 2  |P 41 2 2  |P 41 21 2   |
+----------+----------+----------+----------+----------+----------+------------+
| [93]     |P 42 2 2  |P 42 21 2 |P 43 2 2  |P 43 21 2 |I 4 2 2   |I 41 2 2    |
+----------+----------+----------+----------+----------+----------+------------+
| [99]     |P 4 M M   |P 4 B M   |P 42 C M  |P 42 N M  |P 4 C C   |P 4 N C     |
+----------+----------+----------+----------+----------+----------+------------+
| [105]    |P 42 M C  |P 42 B C  |I 4 M M   |I 4 C M   |I 41 M D  |I 41 C D    |
+----------+----------+----------+----------+----------+----------+------------+
| [111]    |P -4 2 M  |P -4 2 C  |P -4 21 M |P -4 21 C |P -4 M 2  |P -4 C 2    |
+----------+----------+----------+----------+----------+----------+------------+
| [117]    |P -4 B 2  |P -4N2    |I -4 M 2  |I -4 C 2  |I -42 M   |I -42 D     |
+----------+----------+----------+----------+----------+----------+------------+
| [123]    |P 4/M M M |P 4/M C C |P 4/N B M |P 4/N N C |P 4/M B M |P 4/M N C   |
+----------+----------+----------+----------+----------+----------+------------+
| [129]    |P 4/N M M |P 4/N C C |P 42/M M C|P 42/M C M|P 42/N B C|P 42/N N M  |
+----------+----------+----------+----------+----------+----------+------------+
| [135]    |P 42/M B C|P 42/M N M|P 42/N M C|P 42/N C M|I 4/M M M |I 4/M C M   |
+----------+----------+----------+----------+----------+----------+------------+
| [141]    |I 41/A M D|I 41/A C D|                                             |
+----------+----------+----------+---------------------------------------------+

**25 Trigonal Space Groups**


+----------+----------+----------+----------+----------+----------+------------+
| [143]    |P 3       |P 3 1     |P 32      |R3        |P -3      |R -3        |
+----------+----------+----------+----------+----------+----------+------------+
| [149]    |P 3 1 2   |P 3 2 1   |P 31 1 2  |P 31 2 1  |P 32 1 2  |P 32 2 1    |
+----------+----------+----------+----------+----------+----------+------------+
| [155]    |R 32      |P 3 M 1   |P 3 1 M   |P 3 C 1   |P 3 1 C   |R 3 M       |
+----------+----------+----------+----------+----------+----------+------------+
| [161]    |R 3C      |P -3 1 M  |P -3 1 C  |P -3 M 1  |P -3 C 1  |R -3 M      |
+----------+----------+----------+----------+----------+----------+------------+
| [167]    |R -3 C    |          |          |          |          |            |
+----------+----------+----------+----------+----------+----------+------------+

**27 Hexagonal Space Groups**


+----------+----------+----------+----------+----------+----------+------------+
| [168]    |P 6       |P 61      |P 65      |P 62      |P 64      |P 63        |
+----------+----------+----------+----------+----------+----------+------------+
| [174]    |P -6      |P 6/M     |P 63/M    |P 62 2    |P 61 2 2  |P 65 2 2    |
+----------+----------+----------+----------+----------+----------+------------+
| [180]    |P 62 2 2  |P 64 2 2  |P 63 2 2  |P 6 M M   |P 6 C C   |P 63 C M    |
+----------+----------+----------+----------+----------+----------+------------+
| [186]    |P 63 M C  |P -6 M 2  |P -6 C 2  |P -6 2 M  |P -62 C   |P 6/M M M   |
+----------+----------+----------+----------+----------+----------+------------+
| [192]    |P 6/M C C |P 63/M C M|P 63/M M C|          |          |            |
+----------+----------+----------+----------+----------+----------+------------+

**36 Cubic Space Groups**


+----------+----------+----------+----------+----------+----------+------------+
| [195]    |P 2 3     |F 2 3     |I 2 3     |P 21 3    |I 21 3    |P M 3       |
+----------+----------+----------+----------+----------+----------+------------+
| [201]    |P N 3     |F M 3     |F D 3     |I M 3     |P A 3     |I A 3       |
+----------+----------+----------+----------+----------+----------+------------+
| [217]    |P 4 3 2   |P 42 3 2  |F 4 3 2   |F 41 3 2  |I 4 3 2   |P 43 3 2    |
+----------+----------+----------+----------+----------+----------+------------+
| [213]    |P 41 3 2  |I 41 3 2  |P -4 3 M  |F -4 3 M  |I -4 3 M  |P -4 3 N    |
+----------+----------+----------+----------+----------+----------+------------+
| [219]    |F -4 3 C  |I -4 3 D  |P M 3 M   |P N 3 N   |P M 3 N   |P N 3 M     |
+----------+----------+----------+----------+----------+----------+------------+
| [225]    |F M 3 M   |F M 3 C   |F D 3 M   |F D 3 C   |I M 3 M   |I A 3 D     |
+----------+----------+----------+----------+----------+----------+------------+


Non-Standard Settings
^^^^^^^^^^^^^^^^^^^^^

Here are the notations for the alternate settings of the monoclinic and
orthorhombic space groups. Also presented are the notations for
tetragonal space groups that have been rotated by 45 degrees resulting
in a unit cell of doubled volume and of a different Bravais type.

In an monoclinic or orthorhombic space group, the Hermann-Maguin symbols
are identical for the various settings if none of the three axes possess
special symmetry properties. In this case the three axes are
distinguished only by length and the symbol is the same for all
settings.

The column headings below indicate the orientations of the alternative
settings relative to the standard setting. For instance, ``cab`` is a
setting with axes and coordinates cyclically permuted from the
standard setting. This is equivalent to a rotation of 120 degrees
about an axis in a <111> direction relative to the Cartesian axes. The
setting ``a-cb`` is rotated by 90 degrees about the A axis. Thus the
``B`` and ``C`` axes are swapped and the ``y`` and ``z`` coordinates
in the standard setting map onto the ``z`` and ``-y`` coordinates of
the alternate setting. In :demeter:`atoms`, when an alternative
setting is specified in :file:`atoms.inp`, the axes and coordinates are
multiplied by the appropriate permutation matrix onto the standard
setting. The positions in the unit cell are expanded according to the
Hermann-Maguin symbol for the standard setting. The contents of the
unit cell are then permuted back to the specified setting.

**Symbols for Monoclinic Groups of Various Settings**


+--------------+--------------+--------------+
|              | standard abc | bca          |
+==============+==============+==============+
| 3            |      P 2     |     P 2      |
+--------------+--------------+--------------+
| 4            |      B 2     |     C 2      |
+--------------+--------------+--------------+
| 5            |      P B     |     P C      |
+--------------+--------------+--------------+
| 6            |      B B     |     C C      |
+--------------+--------------+--------------+
| 7            |      P 21/M  |     P 21/M   |
+--------------+--------------+--------------+
| 8            |      P 2/B   |     P 2/C    |
+--------------+--------------+--------------+
| 9            |      B 2/B   |     C 2/C    |
+--------------+--------------+--------------+
| 10           |      P 21    |     P 21     |
+--------------+--------------+--------------+
| 11           |      P M     |     P M      |
+--------------+--------------+--------------+
| 12           |      B M     |     C M      |    
+--------------+--------------+--------------+
| 13           |      P 2/M   |     P 2/M    |
+--------------+--------------+--------------+
| 14           |      B 2/M   |     C 2/M    |
+--------------+--------------+--------------+
| 15           |      P 21/B  |     P 2/C    |
+--------------+--------------+--------------+





**Symbols for Orthorhombic Groups of Various Settings**


+---------+----------+----------+----------+----------+----------+----------+
|         |(standard)|          |          |          |          |          |
|         |abc       |cab       |bca       |a-cb      |ba-c      |-cab      |
+=========+==========+==========+==========+==========+==========+==========+
| 16      |P 2 2 2   |each setting                                          |
+---------+----------+----------+----------+----------+----------+----------+
| 17      |P 2 2 21  |P 21 2 2  |P 2 21 2  |P 2 21 2  |P 2 2 21  |P 21 2 2  |
+---------+----------+----------+----------+----------+----------+----------+
| 18      |P 21 21 2 |P 2 21 21 |P 21 2 21 |P 21 2 21 |P 21 21 2 |P 2 21 21 |
+---------+----------+----------+----------+----------+----------+----------+
| 19      |P 21 21 21|each setting                                          |
+---------+----------+----------+----------+----------+----------+----------+
| 20      |C 2 2 21  |A 21 2 2  |B 2 21 2  |B 2 21 2  |C 2 2 21  |A 21 2 2  |
+---------+----------+----------+----------+----------+----------+----------+
|   21    |C 2 2 2   |A 2 2 2   |B 2 2 2   |B 2 2 2   |C 2 2 2   |A 2 2 2   |
+---------+----------+----------+----------+----------+----------+----------+
|    22   |F 2 2 2   |each setting                                          |
+---------+----------+------------------------------------------------------+
| 23      |I 2 2 2   |each setting                                          |
+---------+----------+------------------------------------------------------+
| 24      |I 21 21 21|each setting                                          |
+---------+----------+----------+----------+----------+----------+----------+
| 25      |P M M 2   |P 2 M M   |P M 2 M   |P M 2 M   |P M M 2   |P 2 M M   |
+---------+----------+----------+----------+----------+----------+----------+
| 26      |P M C 21  |P 21 M A  |P B 21 M  |P M 21 B  |P C M 21  |P 21 A M  |
+---------+----------+----------+----------+----------+----------+----------+
| 27      |P C C 2   |P 2 A A   |P B 2 B   |P B 2 B   |P C C 2   |P 2 A A   |
+---------+----------+----------+----------+----------+----------+----------+
| 28      |P M A 2   |P 2 M B   |P C 2 M   |P M 2 A   |P B M 2   |P 2 C M   |
+---------+----------+----------+----------+----------+----------+----------+
| 29      |P C A 21  |P 21 A B  |P C 21 B  |P B 21 A  |P B C 21  |P 21 C A  |
+---------+----------+----------+----------+----------+----------+----------+
| 30      |P N C 2   |P 2 N A   |P B 2 N   |P N 2 B   |P C N 2   |P 2 A N   |
+---------+----------+----------+----------+----------+----------+----------+
| 31      |P M N 21  |P 21 M N  |P N 21 M  |P M 21 N  |P N M 21  |P 2 N M   |
+---------+----------+----------+----------+----------+----------+----------+
| 32      |P B A 2   |P 2 C B   |P C 2 A   |P C 2 A   |P B A 2   |P 2 C B   |
+---------+----------+----------+----------+----------+----------+----------+
| 33      |P N A 21  |P 21 N B  |P C 21 N  |P N 21 A  |P B N 21  |P 2 C N   |
+---------+----------+----------+----------+----------+----------+----------+
| 34      |P N N 2   |P 2 N N   |P N 2 N   |P N 2 N   |P N N 2   |P 2 N N   |
+---------+----------+----------+----------+----------+----------+----------+
| 35      |C M M 2   |A 2 M M   |B M 2 M   |B M 2 M   |C M M 2   |A 2 M M   |
+---------+----------+----------+----------+----------+----------+----------+
| 36      |C M C 21  |A 21 M A  |B B 21 M  |B M 21 B  |C C M 21  |A 21 A M  |
+---------+----------+----------+----------+----------+----------+----------+
| 37      |C C C 2   |A 2 C A   |B B 2 C   |B B 2 B   |C C C 2   |A 2 A A   |
+---------+----------+----------+----------+----------+----------+----------+
| 38      |A M M 2   |B 2 M M   |C M 2 M   |A M 2 M   |B M M 2   |C 2 M M   |
+---------+----------+----------+----------+----------+----------+----------+
| 39      |A B M 2   |B 2 C M   |C M 2 A   |A C 2 M   |B M A 2   |C 2 M B   |
+---------+----------+----------+----------+----------+----------+----------+
| 40      |A M A 2   |B 2 M B   |C C 2 M   |A M 2 A   |B B M 2   |C 2 C M   |
+---------+----------+----------+----------+----------+----------+----------+
| 41      |A B A 2   |B 2 C B   |C C 2 A   |A C 2 A   |B B A 2   |C 2 C B   |
+---------+----------+----------+----------+----------+----------+----------+
| 42      |F M M 2   |F 2 M M   |F M 2 M   |F M 2 M   |F M M 2   |F 2 M M   |
+---------+----------+----------+----------+----------+----------+----------+
| 43      |F D D 2   |F 2 D D   |F D 2 D   |F D 2 D   |F D D 2   |F 2 D D   |
+---------+----------+----------+----------+----------+----------+----------+
|  44     |I M M 2   |I 2 M M   |I M 2 M   |I M 2 M   |I M M 2   |I 2 M M   |
+---------+----------+----------+----------+----------+----------+----------+
|  45     |I B A 2   |I 2 C B   |I C 2 A   |I C 2 A   |I B A 2   |I 2 C B   |
+---------+----------+----------+----------+----------+----------+----------+
|  46     |I M A 2   |I 2 M B   |I C 2 M   |I M 2 A   |I B M 2   |I 2 C M   |
+---------+----------+----------+----------+----------+----------+----------+
|  47     |P M M M   |each setting                                          |
+---------+----------+------------------------------------------------------+
|  48     |P N N N   |each setting                                          |
+---------+----------+----------+----------+----------+----------+----------+
|  49     |P C C M   |P M A A   |P B M B   |P B M B   |P C C M   |P M A A   |
+---------+----------+----------+----------+----------+----------+----------+
|  50     |P B A N   |P N C B   |P C N A   |P C N A   |P B A N   |P N C B   |
+---------+----------+----------+----------+----------+----------+----------+
|  51     |P M M A   |P B M M   |P M C M   |P M A M   |P M M B   |P C M M   |
+---------+----------+----------+----------+----------+----------+----------+
|  52     |P N N A   |P B N N   |P N C N   |P N A N   |P N N B   |P C N N   |
+---------+----------+----------+----------+----------+----------+----------+
|  53     |P M N A   |P B M N   |P N C M   |P M A N   |P N M B   |P C N M   |
+---------+----------+----------+----------+----------+----------+----------+
|  54     |P C C A   |P B A A   |P B C B   |P B A B   |P C C B   |P C A A   |
+---------+----------+----------+----------+----------+----------+----------+
|  55     |P B A M   |P M C B   |P C M A   |P C M A   |P B A M   |P M C B   |
+---------+----------+----------+----------+----------+----------+----------+
|  56     |P C C N   |P N A A   |P B N B   |P B N B   |P C C N   |P N A A   |
+---------+----------+----------+----------+----------+----------+----------+
|  57     |P B C M   |P M C A   |P B M A   |P C M B   |P C A M   |P M A B   |
+---------+----------+----------+----------+----------+----------+----------+
|  58     |P N N M   |P M N N   |P N M N   |P N M N   |P N N M   |P M N N   |
+---------+----------+----------+----------+----------+----------+----------+
|   59    |P M M N   |P N M M   |P M N M   |P M N M   |P M M N   |P N M M   |
+---------+----------+----------+----------+----------+----------+----------+
|  60     |P B C N   |P N C A   |P B N A   |P C N B   |P C A N   |P N A B   |
+---------+----------+----------+----------+----------+----------+----------+
|  61     |P B C A   |P B C A   |P B C A   |P C A B   |P C A B   |P C A B   |
+---------+----------+----------+----------+----------+----------+----------+
|  62     |P N M A   |P B N M   |P M C N   |P N A M   |P M N B   |P C M N   |
+---------+----------+----------+----------+----------+----------+----------+
|  63     |C M C M   |A M M A   |B B M M   |B M M B   |C C M M   |A M A M   |
+---------+----------+----------+----------+----------+----------+----------+
|  64     |C M C A   |A B M A   |B B C M   |B M A B   |C C M B   |A C A M   |
+---------+----------+----------+----------+----------+----------+----------+
|  65     |C M M M   |A M M M   |B M M M   |B M M M   |C M M M   |A M M M   |
+---------+----------+----------+----------+----------+----------+----------+
|  66     |C C C M   |A M A A   |B B M B   |B B M B   |C C C M   |A M A A   |
+---------+----------+----------+----------+----------+----------+----------+
|  67     |C M M A   |A B M M   |B M C M   |B M A M   |C M M B   |A C M M   |
+---------+----------+----------+----------+----------+----------+----------+
|  68     |C C C A   |A B A A   |B B C B   |B B A B   |C C C B   |A C A A   |
+---------+----------+----------+----------+----------+----------+----------+
|  69     |F M M M   |each setting                                          |
+---------+----------+------------------------------------------------------+
|  70     |F D D D   |each setting                                          |
+---------+----------+------------------------------------------------------+
|  71     |I M M M   |each setting                                          |
+---------+----------+----------+----------+----------+----------+----------+
|  72     |I B A M   |I M C B   |I C M A   |I C M A   |I B A M   |I M C B   |
+---------+----------+----------+----------+----------+----------+----------+
|  73     |I B C A   |I B C A   |I B C A   |I C A B   |I C A B   |I C A B   |
+---------+----------+----------+----------+----------+----------+----------+
|  74     |I M M A   |I B M M   |I M C M   |I M A M   |I M M B   |I C M M   |
+---------+----------+----------+----------+----------+----------+----------+

**Symbols for Tetragonal Groups of Various Orientations**


+---------------+---------------+---------------+---------------+---------------+---------------+
|               |(standard) abc |(a+b)(b-a)c    |               |(standard) abc |(a+b)(b-a)c    |
+===============+===============+===============+===============+===============+===============+
|             75|P 4            |C 4            |             76|P 41           |C 41           |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             77|P 42           |C 42           |             78|P 43           |C 43           |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             79|I 4            |F 4            |             80|I 41           |F 41           |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             81|P -4           |C -4           |             82|I -4           |F -4           |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             83|P 4/M          |C 4/M          |             84|P 42/M         |C 42/M         |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             85|P 4/N          |C 4/A          |             86|P 42/M         |C 42/A         |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             87|I 4/M          |F 4/M          |             88|I 41/A         |F 41/D         |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             89|P 4 2 2        |C 4 2 2        |             90|P 4 2 21       |C 4 2 21       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             91|P 41 2 2       |C 41 2 2       |             92|P 41 2 21      |C 41 2 21      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             93|P 42 2 2       |C 42 2 2       |             94|P 42 2 21      |C 42 2 21      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             95|P 43 2 2       |C 43 2 2       |             96|P 43 2 21      |C 43 2 21      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             97|I 4 2 2        |F 4 2 2        |             98|I 41 2 2       |F 41 2 2       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|             99|P 4 M M        |C 4 M M        |            100|P 4 B M        |C 4 M B        |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            101|P 42 C M       |C 42 M C       |            102|P 42 N M       |C 42 M N       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            103|P 4 C C        |C 4 C C        |            104|P 4 N C        |C 4 C N        |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            105|P 42 M C       |C 42 C M       |            106|P 42 B C       |C 42 C B       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            107|I 4 M M        |F 4 M M        |            108|I 4 C M        |F 4 M C        |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            109|I 41 M D       |F 41 D M       |            110|I 41 C D       |F 41 D C       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            111|P -4 2 M       |C -4 M 2       |            112|P -4 2 C       |C -4 C 2       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            113|P -4 21 M      |C -4 M 21      |            114|P -4 21 C      |C -4 C 21      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            115|P -4 M 2       |C -4 2 M       |            116|P -4 C 2       |C -4 2 C       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            117|P -4 B 2       |C -4 2 B       |            118|P -4 N 2       |C -4 2 N       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            119|I -4 M 2       |F -4 2 M       |            120|I -4 C 2       |F -4 2 C       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            121|I -4 2 M       |F -4 M 2       |            122|I -4 2 D       |F -4 D 2       |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            123|P 4/M M M      |C 4/M M M      |            124|P 4/M C C      |C 4/M C C      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            125|P 4/N B M      |C 4/A M B      |            126|P 4/N N C      |C 4/A C N      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            127|P 4/M B M      |C 4/M M B      |            128|P 4/M N C      |C 4/M C N      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            129|P 4/N M M      |C 4/A M M      |            130|P 4/N C C      |C 4/A C C      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            131|P 42/M M C     |C 42/M C M     |            132|P 42/M C M     |C 42/M M C     |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            133|P 42/N B C     |C 42/A C B     |            134|P 42/N N M     |C 42/A M N     |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            135|P 42/M B C     |C 42/M C B     |            136|P 42/M N M     |C 42/M M N     |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            137|P 42/N M C     |C 42/A C M     |            138|P 42/N C M     |C 42/A M C     |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            139|I 4/M M M      |F 4/M M M      |            140|I 4/M C M      |F 4/M M C      |
+---------------+---------------+---------------+---------------+---------------+---------------+
|            141|I 41/A M D     |F 41/D D M     |            142|I 41/A C D     |F 41/D D C     |
+---------------+---------------+---------------+---------------+---------------+---------------+


The Schoenflies Notation
~~~~~~~~~~~~~~~~~~~~~~~~

**2 Triclinic and 13 Monoclinic Space Groups**



+------+----------+----------+----------+----------+----------+----------+
| [1]  |C_1^1     |C_I^1     |C_2^1     |C_2^2     |C_2^3     |C_S^1     |
+------+----------+----------+----------+----------+----------+----------+
| [7]  |C_S^2     |C_S^3     |C_S^4     |C_2H^1    |C_2H^2    |C_2H^3    |
+------+----------+----------+----------+----------+----------+----------+
| [13] |C_2H^4    |C_2H^5    |C_2H^6    |          |          |          |
+------+----------+----------+----------+----------+----------+----------+

**59 orthorhombic space groups**


+----------+----------+----------+----------+----------+----------+----------+
| [16]     |D_2^1     |D_2^2     |D_2^3     |D_2^4     |D_2^5     |D_2^6     |
+----------+----------+----------+----------+----------+----------+----------+
| [22]     |D_2^7     |D_2^8     |D_2^9     |C_2V^1    |C_2V^2    |C_2V^3    |
+----------+----------+----------+----------+----------+----------+----------+
| [28]     |C_2V^4    |C_2V^5    |C_2V^6    |C_2V^7    |C_2V^8    |C_2V^9    |
+----------+----------+----------+----------+----------+----------+----------+
| [34]     |C_2V^10   |C_2V^11   |C_2V^12   |C_2V^13   |C_2V^14   |C_2V^15   |
+----------+----------+----------+----------+----------+----------+----------+
| [40]     |C_2V^16   |C_2V^17   |C_2V^18   |C_2V^19   |C_2V^20   |C_2V^21   |
+----------+----------+----------+----------+----------+----------+----------+
| [46]     |C_2V^22   |D_2H^1    |D_2H^2    |D_2H^3    |D_2H^4    |D_2H^5    |
+----------+----------+----------+----------+----------+----------+----------+
| [52]     |D_2H^6    |D_2H^7    |D_2H^8    |D_2H^9    |D_2H^10   |D_2H^11   |
+----------+----------+----------+----------+----------+----------+----------+
| [58]     |D_2H^12   |D_2H^13   |D_2H^14   |D_2H^15   |D_2H^16   |D_2H^17   |
+----------+----------+----------+----------+----------+----------+----------+
| [64]     |D_2H^18   |D_2H^19   |D_2H^20   |D_2H^21   |D_2H^22   |D_2H^23   |
+----------+----------+----------+----------+----------+----------+----------+
| [70]     |D_2H^24   |D_2H^25   |D_2H^26   |D_2H^27   |D_2H^28   |          |
+----------+----------+----------+----------+----------+----------+----------+

**68 Tetragonal space groups**


+----------+----------+----------+----------+----------+----------+----------+
| [75]     |C_4^1     |C_4^2     |C_4^3     |C_4^4     |C_4^5     |C_4^6     |
+----------+----------+----------+----------+----------+----------+----------+
| [81]     |S_4^1     |S_4^2     |C_4H^1    |C_4H^2    |C_4H^3    |C_4H^4    |
+----------+----------+----------+----------+----------+----------+----------+
| [87]     |C_4H^5    |C_4H^6    |D_4^1     |D_4^2     |D_4^3     |D_4^4     |
+----------+----------+----------+----------+----------+----------+----------+
| [93]     |D_4^5     |D_4^6     |D_4^7     |D_4^8     |D_4^9     |D_4^10    |
+----------+----------+----------+----------+----------+----------+----------+
| [99]     |C_4V^1    |C_4V^2    |C_4V^3    |C_4V^4    |C_4V^5    |C_4V^6    |
+----------+----------+----------+----------+----------+----------+----------+
| [105]    |C_4V^7    |C_4V^8    |C_4V^9    |C_4V^10   |C_4V^11   |C_4V^12   |
+----------+----------+----------+----------+----------+----------+----------+
| [111]    |D_2D^1    |D_2D^2    |D_2D^3    |D_2D^4    |D_2D^5    |D_2D^6    |
+----------+----------+----------+----------+----------+----------+----------+
| [117]    |D_2D^7    |D_2D^8    |D_2D^9    |D_2D^10   |D_2D^11   |D_2D^12   |
+----------+----------+----------+----------+----------+----------+----------+
| [123]    |D_4H^1    |D_4H^2    |D_4H^3    |D_4H^4    |D_4H^5    |D_4H^6    |
+----------+----------+----------+----------+----------+----------+----------+
| [129]    |D_4H^7    |D_4H^8    |D_4H^9    |D_4H^10   |D_4H^11   |D_4H^12   |
+----------+----------+----------+----------+----------+----------+----------+
| [135]    |D_4H^13   |D_4H^14   |D_4H^15   |D_4H^16   |D_4H^17   |D_4H^18   |
+----------+----------+----------+----------+----------+----------+----------+
| [141]    |D_4H^19   |D_4H^20   |          |          |          |          |
+----------+----------+----------+----------+----------+----------+----------+

**25 Trigonal space groups**


+----------+----------+----------+----------+----------+----------+----------+
| [143]    |C_3^1     |C_3^2     |C_3^3     |C_3^4     |C_3I^1    |C_3I^2    |
+----------+----------+----------+----------+----------+----------+----------+
| [149]    |D_3^1     |D_3^2     |D_3^3     |D_3^4     |D_3^5     |D_3^6     |
+----------+----------+----------+----------+----------+----------+----------+
| [155]    |D_3^7     |C_3V^1    |C_3V^2    |C_3V^3    |C_3V^4    |C_3V^5    |
+----------+----------+----------+----------+----------+----------+----------+
| [161]    |    T^1   |D_3D^1    |D_3D^2    |D_3D^3    |D_3D^4    |D_3D^5    |
+----------+----------+----------+----------+----------+----------+----------+
| [167]    |D_3D^6    |          |          |          |          |          |
+----------+----------+----------+----------+----------+----------+----------+

**27 Hexagonal space groups**

+----------+----------+----------+----------+----------+----------+----------+
| [168]    |C_6^1     |C_6^2     |C_6^3     |C_6^4     |C_6^5     |C_6^6     |
+----------+----------+----------+----------+----------+----------+----------+
| [174]    |C_3H^1    |C_6H^1    |C_6H^2    |D_6^1     |D_6^2     |D_6^3     |
+----------+----------+----------+----------+----------+----------+----------+
| [180]    |D_6^4     |D_6^5     |D_6^6     |C_6V^1    |C_6V^2    |C_6V^3    |
+----------+----------+----------+----------+----------+----------+----------+
| [186]    |C_6V^4    |D_3H^1    |D_3H^2    |D_3H^3    |D_3H^4    |D_6H^1    |
+----------+----------+----------+----------+----------+----------+----------+
| [192]    |D_6H^2    |D_6H^3    |D_6H^4    |          |          |          |
+----------+----------+----------+----------+----------+----------+----------+

**36 Cubic space groups**

+----------+----------+----------+----------+----------+----------+----------+
| [195]    |T^1       |T^2       |T^3       |T^4       |T^5       |T_H^1     |
+----------+----------+----------+----------+----------+----------+----------+
| [201]    |T_H^2     |T_H^3     |T_H^4     |T_H^5     |T_H^6     |T_H^7     |
+----------+----------+----------+----------+----------+----------+----------+
| [217]    |O^1       |O^2       |O^3       |O^4       |O^5       |O^6       |
+----------+----------+----------+----------+----------+----------+----------+
| [213]    |O^7       |O^8       |T_D^1     |T_D^2     |T_D^3     |T_D^4     |
+----------+----------+----------+----------+----------+----------+----------+
| [219]    |T_D^5     |T_D^6     |O_H^1     |O_H^2     |O_H^3     |O_H^4     |
+----------+----------+----------+----------+----------+----------+----------+
| [225]    |O_H^5     |O_H^6     |O_H^7     |O_H^8     |O_H^9     |O_H^10    |
+----------+----------+----------+----------+----------+----------+----------+
