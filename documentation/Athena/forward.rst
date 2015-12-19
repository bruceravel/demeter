..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Forward
=======

      
The best way to learn how to use :demeter:`athena` is to **use**
:demeter:`athena`. Poke at the buttons, poke at the menus, try things
just to see what happens. And above all, remember the physical and
mathematical meanings of your data and of the data analysis techniques
and think about how actions in :demeter:`athena` relate to those
meanings.

:demeter:`athena` is a powerful and versatile program capable of
supporting almost all of your common (and many not-so-common!) XAS
data processing chores. It is not, however, a particularly intuitive
program. I doubt that any XAS program could be intuitive. On top of
that, :demeter:`athena` has accumulated lots of features over the
years. Many of these features are necessary for high-quality data
processing, others are bells and whistles intended to make data
processing more convenient or more fun.

This document attempts to be a comprehensive overview of all of the
features of :demeter:`athena`. There are lots of words, but also lots
of pictures. Feel free to jump around and to focus on the parts most
directly relevant to your immediate needs. I hope you find this
document and the program helpful.


Layout and typesetting conventions
----------------------------------

Here is a summary of fonts, colors, and symbols used to denote different
kinds of text. Note that some of these may appear the same in certain
presentation media.

- File names look ``C:\\like\\this``

- The names of parameters for data processing look
  :procparam:`like this`

- Emphasized text looks *like this*

- Bold text looks **like this**

- Links to web sites look `like this <http://www.google.com>`__

- Internal links look `like this
  <forward.html#layout-and-typesetting-conventions>`__

- Menu selections look like this: :menuselection:`File --> Import data`
  
- Keyboard shortcuts look like this:
  :button:`Control,dark`-:button:`q`, which means to hit the :button:`q`
  key while holding the :button:`Control` (or :button:`Ctrl`) key

- Program names from the :demeter:`demeter`'s extended family look
  like this: :demeter:`athena`

- References to :demeter:`athena`'s preferences are written like this:
  :configparam:`Bkg,fraction`.  To modify this preferences, open the
  :guilabel:`bkg` section of the `preferences tool <other/prefs.html>`__ and
  then click on :guilabel:`fraction`

.. CAUTION::
   Points that require special attention are indicated
   like this.

.. TODO::
   Notes about features missing from the document are indicated
   like this.

.. versionadded:: 1.2.3
   Features that have been recently added to :demeter:`athena` are
   indicated like this if they have not yet been properly documented.
   Usually this is because I have been too lazy to make screenshots.

:mark:`lightning,.` This symbol indicates a section describing one of
:demeter:`athena`'s features that I consider especially
powerful and central to the effective use of the program.

.. endpar::

:mark:`bend,.` This symbol indicates a section with difficult
information that newcomers to :demeter:`athena` might pass
over on their first reading of this document.

.. endpar::

The html version of this document makes use of Unicode characters
(mostly Greek, math, superscript, and subscript symbols) and may not
display correctly in very old browsers.



Acknowledgments
----------------

I have to thank Matt Newville, of course. Without :demeter:`ifeffit`
there wouldn't be an :demeter:`athena`. One afternoon over coffee,
Julie Cross and Shelly Kelly lit the spark that eventually lead to the
first version of this document. Some content of this document was
inspired by a recent XAS review article by Shelly Kelly and Dean
Hesterberg, the first draft of which I had the pleasure of editing and
the final draft of which I ended up on the author list. I have a huge
debt of gratitude to all the folks on the :demeter:`ifeffit` mailing
list. Without the incredible support and wonderful feedback that I've
received over the years, :demeter:`athena` would be a shadow of what
it is today.

.. bibliography:: athena.bib
   :filter: author % "Kelly"
   :list: bullet

An excellent review of the fundamental principles of X-ray absorption
spectroscopy is

.. bibliography:: athena.bib
   :filter: author % "Newville" and year == '2014'
   :list: bullet

Scott Calvin has written an excellent XAFS text book which covers a
lot of the material covered by :demeter:`athena`:

.. bibliography:: athena.bib
   :filter: title % "Everyone"
   :list: bullet

The following great software tools were used to create this document:

- `The Sphinx Documentation Generator <http://sphinx-doc.org/>`_ and
  `reStructuredText <http://sphinx-doc.org/rest.html>`_

- The `Emacs <http://www.gnu.org/software/emacs/>`__ text editor along
  with `rst-mode
  <http://docutils.sourceforge.net/docs/user/emacs.html>`__ and the
  simply wonderful `Emacs Code Browser
  <http://ecb.sourceforge.net/>`__

- The `pybtex <http://pybtex.org/>`_ bibliography processor for
  python.

- The `sphinxcontrib-bibtex
  <https://sphinxcontrib-bibtex.readthedocs.org/en/latest/>`_
  package, which is Sphinx extension for BibTeX style citations.

- The `sphinxtr <https://github.com/jterrace/sphinxtr>`_ package,
  which is Sphinx extension for supporting a few LaTeX environments.
  Currently, the ``subfig`` package is used for grouping figures, but
  the ``numfig`` package is not used for figure numbering.
  
- The `keys.css stylesheet <https://github.com/michaelhue/keyscss>`_,
  which I modified to add options for purple and orange stylings.
  
Almost all screenshots were made of either :demeter:`athena` or the
`Gnuplot <http://gnuplot.info/>`__ window on my `KDE desktop
<http://www.kde.org>`__. The screenshots of spreadsheets made from a
report (:numref:`Fig. %s <fig-exportexcel>`) and an LCF fit
report (:numref:`Fig. %s <fig-auclexcel>`) are displayed in
`LibreOffice <http://www.libreoffice.org>`__.


The images of the `Tholos temple
<https://en.wikipedia.org/wiki/Delphi#Tholos>`_ on the front page and
the `Klimt painting Pallas Athena
<http://www.wikiart.org/en/gustav-klimt/minerva-or-pallas-athena>`_ in
the navigation box of the html document are from
http://www.artchive.com.

The image used as the :demeter:`athena` program icon is from a
:quoted:`Terracotta lekythos depicting Athena holding a spear and
aphlaston.`. The image is licensed as Creative Commons
Attribution-Share Alike 3.0 and can be found at `Wikimedia Commons
<http://commons.wikimedia.org/wiki/File:Brygos_Painter_lekythos_Athena_holding_spear_MET.jpg>`__.


Data citations
--------------

- The copper foil data shown here and there are the data that Matt
  Newville, Yanjun Zhang, and I measured one day back in 1992 that
  has, inscrutably, become *the* copper foil data shown and
  referenced often in the XAS theory literature. The copper film in
  `the self-absorption section <process/sa.html>`__ comes from Corwin
  Booth.

- The platinum catalyst data shown in `the difference spectrum section
  <analysis/diff.html>`__ were donated by Simon Bare.

- The gold edge data shown in many places throughout this document are
  taken from measurements published as

  .. bibliography:: athena.bib
     :filter: author % "Lengke"
     :list: bullet

- The gold oxide data shown in `the smoothing section
  <process/smooth.html>`__ were donated by Norbert Weiher.

- The iron foil data shown in `the convolution section
  <process/conv.html>`__ and elsewhere were measured by me while I
  was commissioning NSLS beamline X11B in 2004.

- The sulphate data shown in `the self-absorption section
  <process/sa.html>`__ were donated by Zhang Ghong and come with
  Daniel Haskel's `Fluo program
  <http://www.aps.anl.gov/xfd/people/haskel/fluo.html>`__. The copper
  data shown in `the same section <process/sa.html>`__ come with
  Corwin Booth's `RSXAP program <http://lise.lbl.gov/RSXAP/>`__.

- Data on a hydrated uranyl phosphate that appear in several places
  are the U L\ :sub:`III` standard used by `my former research group
  <http://www.mesg.anl.gov/>`__. Spectra from this standard have
  appeared in many publications from that group. The U\ :sub:`3`\ O\
  :sub:`8` sample shown in the `the deglitching section
  <process/deg.html>`__ are from the group's standards library.

- Tin edge data which appear in several places are from
   
   .. bibliography:: athena.bib
      :filter: author % "Impellitteri"
      :list: bullet

- Data on PbTiO\ :sub:`3`, BaTiO\ :sub:`3`, and EuTiO\ :sub:`3` are
  taken from my own PhD thesis.


   
Installing ATHENA on your computer
----------------------------------

**Linux, BSD, and other unixes**
    It is not especially hard to build :demeter:`athena`
    from source code. The 
    procedure is explained in detail on this web page:
    http://bruceravel.github.io/demeter/pods/installation.pod.html. An
    excellent addendum to those instructions is at
    https://gist.github.com/3959252.
**Windows**
    Follow the links to `the Windows instructions on the Demeter
    homepage <http://bruceravel.github.io/demeter/#windows>`__ to download the
    installer and updater packages. Just download, double-click, and
    answer the questions.
**Macintosh**
    Follow the links to `the Macintosh instructions on the Demeter
    homepage <http://bruceravel.github.io/demeter/#mac>`__ and carefully
    follow the instructions you find there.
**Debian and debian-based Linux**
    There are no packages for Debian of any other Linux distribution 
    at this time.


Building this document from source
----------------------------------

The source files and all images files for this document can be
downloaded using Git. To grab the source, you will need an `Git
client <http://git-scm.com/>`__ on your computer. This command checks a
copy of the source out and downloads it onto your computer:

::

        git clone https://github.com/bruceravel/demeter.git

The document is found in the :file:`documentation/` folder.

Contributions to the document are extremely welcome. The very best
sort of contribution would be to directly edit the `sphinx
<http://sphinx-doc.org>`_ source files and make a pull request to the
`git repository <https://github.com/bruceravel/demeter>`_. The second
best sort would be a patch file against the templates in the
repository. If sphinx is more than you want to deal with, but you have
corrections to suggest, I'd cheerfully accept almost any other format
for the contribution.  (Although I have to discourage using an html
editing tool to edit the html directly. Tools like that tend to insert
lots of additional html tags into the text, making it more difficult
for me to incorporate your changes into the source.)


Building the html document
~~~~~~~~~~~~~~~~~~~~~~~~~~

Building the :demeter:`athena` document requires at least version 1.3
of :program:`sphinx-build`.  Note that Ubuntu 15.04 comes with version
1.2, so you will need to upgrade by doing

.. code:: bash

   sudo pip install --upgrade sphinx

You will also need to install the following python packages

#. The `pybtex <http://pybtex.org/>`_ bibliography processor for
   python.
   
#. The `sphinxcontrib-bibtex
   <https://sphinxcontrib-bibtex.readthedocs.org/en/latest/>`_
   package, which is Sphinx extension for BibTeX style citations.

These can be installed at the command line by

.. code::

   sudo pip install pybtex
   sudo pip install sphinxcontrib-bibtex

To build the html document, do the following

.. code:: bash

   cd documentation/
   cd Athena/
   make html

This will use :program:`sphinx-build` to convert the source code into
html pages.  The html pages will be placed in :file:`_build/html/`.
This folder is a self-contained package.  The :file:`html/` folder can
be copied and placed somewhere else.  The web pages can be accessed
with full functionality in any location.


Building the LaTeX document
~~~~~~~~~~~~~~~~~~~~~~~~~~~

:mark:`soon,.`

.. linebreak::


Using the document with ATHENA
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The html document files can be used by :demeter:`athena`.  They are
installed at the time that :demeter:`demeter` is installed.  If the
html pages cannot be found, :demeter:`athena` will try to use your
internet connection to fetch them from `the Demeter homepage
<http://bruceravel.github.io/demeter/>`__.

