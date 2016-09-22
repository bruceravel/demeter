.. Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

WebAtoms: Convert crystallographic data into a Feff input file ... on the web!
==============================================================================

:demeter:`WebAtoms` is a application which can be run locally or
hosted on a web server and accessed through your browser.  It is
`available at GitHub <https://github.com/bruceravel/WebAtoms>`_.

**To access WebAtoms on the web**

  Point your browser at any of these servers:

  #. http://millenia.cars.aps.anl.gov/webatoms/

  If you would like your installation included in this list, let Bruce
  know by opening an `issue at the GitHub site
  <https://github.com/bruceravel/WebAtoms/issues>`_.

**To run WebAtoms locally**

  #. Clone a copy from the GitHub site or `download the latest zip file
     <https://github.com/bruceravel/WebAtoms/archive/master.zip>`_.

  #. Assuming you have `perl installed
     <https://www.perl.org/get.html>`_ on your computer, you will need
     to install `the Dancer web framework <http://perldancer.org/>`_,
     `perl's YAML tool <https://metacpan.org/pod/distribution/YAML/lib/YAML.pod>`_,
     and `Demeter <http://bruceravel.github.io/demeter/>`_.

  #. Launch the application by doing ``perl bin/app.pl`` at the
     command line.

  #. Point your browser at http://localhost:3000

**To deploy WebAtoms on your server**

  #. Clone a copy from the GitHub site or `download the latest zip file
     <https://github.com/bruceravel/WebAtoms/archive/master.zip>`_.

  #. Assuming you have `perl installed
     <https://www.perl.org/get.html>`_ on your computer, you will need
     to install `the Dancer web framework <http://perldancer.org/>`_,
     `perl's YAML tool <https://metacpan.org/pod/distribution/YAML/lib/YAML.pod>`_,
     and `Demeter <http://bruceravel.github.io/demeter/>`_.

  #. Follow the `instructions for deploying a Dancer application
     <https://metacpan.org/pod/Dancer2::Manual::Deployment>`_
     appropriate to your web server.

**Installing dependencies**

  ``cpanm -S Dancer`` to download and install Dancer and its
  dependencies.  ``cpanm -S YAML`` to download and install YAML
  and its dependencies.  The ``-S`` flag uses :program:`sudo`
  to do the actual installation.

  For :demeter:`demeter`, follow the instructions at `the Demeter
  homepage <http://bruceravel.github.io/demeter/>`_.


If you have any problems deploying :demeter:`WebAtoms` on particular
servers or accessing it with particular browsers, please `open an
issue at the GitHub site
<https://github.com/bruceravel/WebAtoms/issues>`_.

If you have any suggestions or corrections for this manual, `also open
an issue at the GitHub site
<https://github.com/bruceravel/WebAtoms/issues>`_.

Using WebAtoms
--------------

When run in your browser, :demeter:`WebAtoms` (like `Gaul
<http://www.thelatinlibrary.com/caesar/gall1.shtml>`_) is in three
parts.  Across the top of the window are a bunch of useful links,
including the link in the upper left back to the empty
:demeter:`WebAtoms` application.  On the left is a form to be filled
in with crystallographic data.  On the right is the response area,
which will (hopefully!) be filled with a :file:`feff.inp` file or some
other useful crystallographic calculation.

.. figure:: ../_images/webatoms.png
   :target: ../_images/webatoms.png
   :align: center

   :demeter:`WebAtoms`, running locally, after importing a CIF file for Ga\ :sub:`2`\ O\ :sub:`3`


The sort of data expected by :demeter:`WebAtoms` is the same as the
command line and desktop versions of :demeter:`atoms` and is explained
in some detail in the :demeter:`artemis` manual in the chapters `on
the Atoms window
<http://bruceravel.github.io/demeter/documents/Artemis/feff/index.html>`_
and `on crystallography for EXAFS
<http://bruceravel.github.io/demeter/documents/Artemis/atoms/index.html>`_.

As an aid to using :demeter:`WebAtoms`, hint text will appear when the
mouse lingers over the different elements of the form.  For instance,
when the mouse lingers over the text box for entering the cluster
size, the hint text will read :quoted:`The radial extent of the
cluster written to the feff.inp file`.


The shift vector is used to recenter a crystal from a non-standard
setting into a setting that will be recognized by :demeter:`WebAtoms`'
crystal engine.  This often causes confusion and is `discussed here in
some detail
<http://bruceravel.github.io/demeter/documents/Artemis/atoms/space.html#multiple-origins-and-the-shift-keyword>`_.

Once you are done entering crystal data, :mark:`leftclick,.` click the
:button:`Compute,light` button.  The corresponding :file:`feff.,inp`
file will be displayed in the response area on the right.

To save the contents of the response area, :mark:`leftclick,.` click
the :button:`Save as,light` button.  You will be prompted for the name
and location of the save file on your computer.


Entering crystallographic data
------------------------------

There are several ways of importing crystallographic data in this
application:

#. Manually enter your crystal data into the form.

#. You can import from a CIF or :file:`atoms.inp` file which resides
   locally on your computer.  To do this, :mark:`leftclick,.` click the
   :button:`Browse,light` button to post a file selection dialog and
   select a file from your computer.  Then :mark:`leftclick,.` click
   the :button:`Submit crystal data,light` button.  Your data will be
   imported and the result will be shown in the response area.

#. Enter a URL to a CIF or :file:`atoms.inp` file in the text box
   below the :button:`Browse,light` button.  Hit :button:`Return`
   to fetch that file from the internet.  Your data will be
   imported and the result will be shown in the response area.

#. Use the ``url?url=`` syntax in the URL for the :demeter:`WebAtoms`
   application, e.g.
   ``http://webatoms.server/url?url=http://www.crystallography.net/cod/1535967.cif``.
   Your data will be imported and the result will be shown in the
   response area.  In this way, you can hook :demeter:`WebAtoms` up to
   other web or desktop applications.

.. todo:: 
   #. Need to streamline file import this so that the second button
      click is not necessary
   #. Upload directly from a file, i.e.
      ``http://webatoms.server/file?file=http://www.crystallography.net/cod/1535967.cif``
      or some such.  Although care should be taken, as this can
      `expose files inappropriately
      <https://blog.steve.fi/If_your_code_accepts_URIs_as_input__.html>`_
      to the internet.
   #. Say something sensible when a file is neither :file:`atoms.inp`
      nor CIF.
   #. Lots more testing for error conditions.

Note that one- or two-letter symbols are typically used to identify
the element at each site.  However, full names (e.g. :quoted:`oxygen`)
or Z numbers (e.g. :quoted:`8`) can be used as well.  Names must be
spelled correctly according to British English spelling (which is odd,
I suppose, but the tool used to recognize element names was written
using British English |nd| so :quoted:`aluminium`, not
:quoted:`aluminum` as we sensible Yanks say).


Output options
--------------

There are a number of kinds of output that can be generated by
:demeter:`WebAtoms`.  While a :file:`feff.inp` is the most common,
there are other options:

* A :demeter:`feff6` input file
* A :demeter:`feff8` input file, also suitable for :demeter:`feff9`
* An :demeter:`atoms` input file
* An :demeter:`atoms` input file using the ``P1`` space group and with
  the fully decorated unit cell
* A file detailing absorption calculations made using tables of X-ray
  cross-sections
* A file detailing the space group of the crystal
* A file with the same cluster of atoms as the :file:`feff.inp` file,
  but in the `XYZ format
  <http://openbabel.org/docs/2.3.0/FileFormats/XYZ_cartesian_coordinates_format.html>`_
* A file with the same cluster of atoms as the :file:`feff.inp` file,
  but in the `alchemy format
  <http://paulbourke.net/dataformats/alc/alc3/>`_
* An :quoted:`overfull` file, which has the fully decorated unit cell
  expressed in Cartesian coordinates and includes all of the atoms
  that sit near cell walls and corners
* A diagnostic file with the state of the application

Selection between :demeter:`feff6` and :demeter:`feff8` style files is
made with the :guilabel:`ipot style` menu.  This menu offers each of
`the three ipot styles
<http://bruceravel.github.io/demeter/documents/Artemis/extended/ipots.html>`_
for each of :demeter:`feff6` and :demeter:`feff8`.

Issues with CIF files
---------------------

**Multi-record CIF files**

  A single CIF file can contain more than one crystal structures.
  Currently :demeter:`WebAtoms` has no way to prompt you to choose
  which record from a CIF file you want to import.
  :demeter:`WebAtoms` will always import the first record.  `Here's an
  example of a CIF file with 2
  records. <https://raw.githubusercontent.com/bruceravel/demeter/master/examples/AuCl.cif>`_

**Partial occupancy**

  :demeter:`WebAtoms` cannot handle partial occupancy of
  crystallographic sites.  `Read this for more information the topic
  of dopants
  <http://bruceravel.github.io/demeter/documents/Artemis/extended/dopants.html>`_.

**Imperfect parsing of CIF files**

  It is certainly possible that you might come across a valid CIF file
  which is not parsed correctly by the tool used by
  :demeter:`WebAtoms`.  In this situation, submit `an issue at the
  github site <https://github.com/bruceravel/WebAtoms/issues>`_ and
  include the CIF file in question (or a link to where that CIF file
  can be found).

**Imperfect recognition of CIF files**

  Currently a CIF file is recognized only if it's file name ends in
  :file:`.cif`.  That's dumb and easy to foil, but that's how it works
  right now.  Happily, :demeter:`webatoms` is more deft at recognizing
  :file:`atoms.inp` files.


Troubleshooting
---------------

**You have N unique potentials, but Feff only allows 7.**

  This usually happens when you have a lengthy list of unique sites
  and are using the ``tags`` or ``sites`` ipot style.  You can `find a
  discussion of ipot styles in the Artemis manual
  <http://bruceravel.github.io/demeter/documents/Artemis/extended/ipots.html>`_.

**Sites generate one or more common positions and their occupancies sum to more than 1.**

  This is likely to happen when importing a CIF file with partial
  occupancy of lattice sites.  :demeter:`webatoms` is not able to
  generate a :file:`feff.inp` file with consideration of partial
  occupancy.  You can `find a discussion of dopants in the Artemis
  manual
  <http://bruceravel.github.io/demeter/documents/Artemis/extended/dopants.html>`_.
  The need for a `shift vector
  <http://bruceravel.github.io/demeter/documents/Artemis/atoms/space.html#multiple-origins-and-the-shift-keyword>`_
  is another possible culprit.

**Your symbol could not be recognized as a space group symbol.**

  `This section of the Artemis manual
  <http://bruceravel.github.io/demeter/documents/Artemis/atoms/space.html>`_
  has a complete list of symbols recognized by :demeter:`WebAtoms`.

**Lattice constant was not a number / Lattice constant was negative**

  Lattice constants must be positive numbers and must be written in a
  way that are obviously interpretable as numbers.  Localization is
  *not* respected |nd| the decimal mark is a dot (``.``), **not** a
  comma, momayyez, apostrophe, decimal separator key symbol, space, or
  any other symbol.

  Lattice angles must also be positive numbers.  So too the three
  radius parameters.

  Note that site coordinates can be negative, but must also be
  obviously interpretable as numbers using a dot for the decimal
  mark.

**Symbol for site N is not a valid element symbol**

  Element symbols for the sites must be the standard two-letter
  symbols as found on any English-language periodic table (or
  `Hephaestus
  <http://bruceravel.github.io/demeter/documents/Athena/hephaestus.html>`_).
  Full names (e.g. :quoted:`oxygen`) or Z numbers
  (e.g. :quoted:`8`) can be used as well, however names must be
  spelled correctly.

  Note that site tags can be any string and need not be related to the
  element symbol, although only the first 10 characters will be used.
  Also, tags should not include white space.


Citing WebAtoms
---------------

Use

.. bibliography:: singlefile.bib
   :filter: title % "crystallography"
   :list: bullet

or

.. bibliography:: singlefile.bib
   :filter: title % "ATHENA"
   :list: bullet
