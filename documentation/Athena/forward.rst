Forward
=======

Conventions and acknowledgements
--------------------------------

The best way to learn how to use ATHENA is to **use** ATHENA. Poke at
the buttons, poke at the menus, try things just to see what happens. And
above all, remember the physical and mathematical meanings of your data
and of the data analysis techniques and think about how actions in
ATHENA relate to those meanings.

ATHENA is a powerful and versatile program capable of supporting almost
all of your common (and not-so-common) XAS data processing chores. It is
not, however, a particularly intuitive program. I doubt that any XAS
program could be intuitive. On top of that, ATHENA has accumulated lots
of features over the years. Many of these features are necessary for
high-quality data processing, others are bells and whistles intended to
make data processing more convenient or more fun.

This document attempts to be a comprehensive overview of all of ATHENA's
features. There are lots of words, but also lots of pictures. Feel free
to jump around and to focus on the parts most directly relevant to your
immediate needs. I hope you find this document and the program helpful.


Layout and typesetting conventions
----------------------------------

Here is a summary of fonts, colors, and symbols used to denote different
kinds of text. Note that some of these may appear the same in certain
presentation media.

-  File names look ``C:\\like\\this``.

-  The names of parameters for data processing look «like\_this».

-  Emphasized text looks *like this*.

-  Bold text looks **like this**.

-  Links to web sites look `like this <http://www.google.com>`__.

-  Internal links look `like
   this <forward.html#layoutandtypesettingconventions>`__.

-  Keyboard shortcuts look like this: ``Control-q``. This example means
   to hit the q key while holding the Control (or Ctrl) key.

-  Program names from the DEMETER's extended family look like this:
   ATHENA.

-  References to ATHENA's preferences are written like this:
   ♦Bkg → fraction. To modify this preferences, open the “bkg” section
   of the `preferences tool <other/prefs.html>`__ and then click on
   “fraction”.

.. CAUTION::
   Points that require special attention are written inside of
   attention-grabbing boxes.

.. TODO::
   Notes about features missing from the document are indicated
   like this.

|To do!| Features that have been recently added to ATHENA are indicated
like this if they have not yet been properly documented.

|Essential topic| This symbol indicates a section describing one of
ATHENA's features that I consider especially powerful and central to the
effective use of the program.

|Advanced topic| This symbol indicates a section with difficult
information that newcomers to ATHENA might pass over on their first
reading of this document.


The html version of this document makes use of HTML 4.1 character
entities (mostly Greek symbols) and will not display correctly in very
old browsers.



Acknowledgments
----------------

I have to thank Matt Newville, of course. Without IFEFFIT there
wouldn't be an ATHENA. One afternoon over coffee, Julie Cross and
Shelly Kelly lit the spark that eventually lead to the first version
of this document. Some content of this document was inspired by a
recent XAS review article :cite:ts:`KellyReview`, the first draft of
which I had the pleasure of editing and the final draft of which I
ended up on the author list. I have a huge debt of gratitude to all
the folks on the IFEFFIT mailing list. Without the incredible support
and wonderful feedback that I've received over the years, ATHENA would
be a shadow of what it is today.

The following great software tools were used to create this document:

- `The Sphinx Documentation Generator <http://sphinx-doc.org/>`_ and
  `reStructuredText <http://sphinx-doc.org/rest.html>`_

- The `Emacs <http://www.gnu.org/software/emacs/>`__ text editor along
  with `rst-mode
  <http://docutils.sourceforge.net/docs/user/emacs.html>`__ and the
  simply wonderful `Emacs Code Browser
  <http://ecb.sourceforge.net/>`__


Almost all screenshots were made of either ATHENA or the
`Gnuplot <http://gnuplot.info/>`__ window on my `KDE
desktop <http://www.kde.org>`__. The screenshots of spreadsheets made
from `a report file <output/report.html#export_excelreport>`__ and `an
LCF fit report <examples/aucl.html#ex_aucl_excel>`__ are displayed in
`LibreOffice <http://www.libreoffice.org>`__.

The images of the Tholos temple on the front page and the Klimt painting
*Pallas Athena* in the navigation box of the html document are from
http://www.artchive.com.

The image used as the ATHENA program icon is from a “Terracotta lekythos
depicting Athena holding a spear and aphlaston.”. The image is licensed
as Creative Commons Attribution-Share Alike 3.0 and can be found at
`Wikimedia
Commons <http://commons.wikimedia.org/wiki/File:Brygos_Painter_lekythos_Athena_holding_spear_MET.jpg>`__.


Data citations
--------------

-  The copper foil data shown here and there are the data that Matt
   Newville, Yanjun Zhang, and I measured one day back in 1992 that has,
   inscrutably, become *the* copper foil data shown and referenced in a
   large fraction of the XAS theory literature. The copper film in `the
   self-absorption section <process/sa.html>`__ comes from Corwin Booth.

-  The platinum catalyst data shown in `the difference spectrum
   section <analysis/diff.html>`__ were donated by Simon Bare.

-  The gold edge data shown in many places throughout this document are
   taken from measurements published as :cite:ts:`Lengke`.

-  The gold oxide data shown in `the smoothing
   section <process/smooth.html>`__ were donated by Norbert Weiher.

-  The iron foil data shown in `the convolution
   section <process/conv.html>`__ and elsewhere were measured by me
   while I was commissioning NSLS beamline X11B in 2004.

-  The sulphate data shown in `the self-absorption
   section <process/sa.html>`__ were donated by Zhang Ghong and come
   with Daniel Haskel's `Fluo
   program <http://www.aps.anl.gov/xfd/people/haskel/fluo.html>`__. The
   copper data shown in `the same section <process/sa.html>`__ come with
   Corwin Booth's `RSXAP program <http://lise.lbl.gov/RSXAP/>`__.

-  Data on a hydrated uranyl phosphate that appear in several places are
   the U L\ :sub:`III` standard used by `my former research
   group <http://www.mesg.anl.gov/>`__. Spectra from this standard have
   appeared in many publications from that group. The
   U\ :sub:`3`\ O\ :sub:`8` sample shown in the `the deglitching
   section <process/deg.html>`__ are from the group's standards library.

-  Tin edge data which appear in several places are from
   :cite:ts:`Impellitteri`

-  Data on PbTiO\ :sub:`3`, BaTiO\ :sub:`3`, and EuTiO\ :sub:`3` are
   taken from my own PhD thesis.


Installing Athena on your computer
----------------------------------

**Linux, BSD, and other unixes**
    It is not especially hard to build ATHENA from source code. The
    procedure is explained in detail on this web page:
    http://bruceravel.github.io/demeter/pods/installation.pod.html. An
    excellent addendum to those instructions is at
    https://gist.github.com/3959252.
**Debian and debian-based Linux**
    Coming soon....
**Windows**
    Follow the links on `the Demeter
    homepage <http://bruceravel.github.io/demeter/>`__ to download the
    installer and updater packages. Just download, double-click, and
    answer the questions.
**Macintosh**
    Coming soon....



Building this document from source
----------------------------------



Obtaining the document source
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The source files and all images files for this document can be
downloaded using Git. To grab the source, you will need an `Git
client <http://git-scm.com/>`__ on your computer. This command checks a
copy of the source out and downloads it onto your computer:

::

        git clone https://github.com/bruceravel/demeter.git


.. todo::
   explain use of Sphinx
   
Contributions to the document are extremely welcome. The very best sort
of contribution would be to directly edit the source templates and
commit your changes to the SVN repository. The second best sort would be
a patch file against the templates in the repository. If TT2 is more
than you want to deal with, but you have corrections to suggest, I'd
cheerfully accept almost any other format for the contribution.
(Although I have to discourage using an html editing tool like FrontPage
to edit the html directly. Tools like that tend to insert lots of
additional html tags into the text, making it more difficult for me to
incorporate your changes into the source.)


Building the html document
~~~~~~~~~~~~~~~~~~~~~~~~~~

After downloading and unpacking the source for DEMETER, you must
configure it to build correctly on your computer. This is simple:

::

    cd doc/aug
    ./configure

To build the entire document as html

::

    ./bin/build -a

Individual pages can be built by specifying them on the command line:

::

    ./bin/build bkg/norm.tt forward.tt


Building the LaTeX document
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The L\ :sup:`A`\ T\ :sub:`E`\ X document is built by

::

    ./bin/tex -a
    cd tex/
    pdflatex athena.ltx
    pdflatex athena.ltx

You need to run ``pdflatex`` two or three times to get all of the
section numbering and cross referencing correct. The varioref package,
used to handle cross-referencing, is sometimes a little fragile. If you
see the following error message: simply hit return. The message should
disappear when you recompile the document.

::

    ! Package varioref Error: vref at page boundary 142-143 (may loop).


Using the document with Athena
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The html document files can be used by ATHENA. They are installed at the
time that DEMETER is installed (and they can be installed on a Windows
machine by downloading and installing the documentation package). If the
html pages cannot be found, ATHENA will try to use your internet
connection to fetch them from `the Demeter
homepage <http://bruceravel.github.io/demeter/>`__.

