..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Forward
=======

:demeter:`artemis` is:

- a graphical front-end for :demeter:`feff` and :demeter:`ifeffit` (or
  :demeter:`larch`) built using :demeter:`demeter`

- a tool which makes easy analysis problems easy and hard analysis
  problem possible

- in use by hundreds of scientists world-wide


.. todo:: 
   #. section numbering in chapters with sections in index.rst
      

Layout and typesetting conventions
----------------------------------

Here is a summary of fonts, colors, and symbols used to denote different
kinds of text. Note that some of these may appear the same in certain
presentation media.

- File names look ``C:\like\this``

- The names of parameters for data processing look
  :procparam:`like this`

- Emphasized text looks *like this*

- Bold text looks **like this**

- Links to web sites look `like this <http://www.google.com>`__

- Internal links look `like this
  <forward.html#layout-and-typesetting-conventions>`__

- References to menu selections look like this: :menuselection:`File --> Import data`
  
- References to buttons in :demeter:`artemis` that can be pushed
  :button:`look like this,light`

- Keyboard shortcuts look like this:
  :button:`Control,dark`-:button:`q`, which means to hit the :button:`q`
  key while holding the :button:`Control` (or :button:`Ctrl`) key

- Program names from the :demeter:`demeter`'s extended family look
  like this: :demeter:`artemis`

- References to :demeter:`artemis`'s preferences are written like this:
  :configparam:`Fit,k1`.  To modify this preferences, open the
  :guilabel:`fit` section of the `preferences tool <other/prefs.html>`__ and
  then click on :guilabel:`k1`

.. CAUTION::
   Points that require special attention are indicated
   like this.

.. TODO::
   Notes about features missing from the document are indicated
   like this.

.. versionadded:: 1.2.3
   Features that have been recently added to :demeter:`artemis` are
   indicated like this if they have not yet been properly documented.
   Usually this is because I have been too lazy to make screenshots.

:mark:`lightning,.` This symbol indicates a section describing one of
:demeter:`artemis`' features that I consider especially
powerful and central to the effective use of the program.

.. endpar::

:mark:`bend,.` This symbol indicates a section with difficult
information that newcomers to :demeter:`artemis` might pass
over on their first reading of this document.

.. endpar::

The html version of this document makes use of Unicode characters
(mostly Greek, math, superscript, and subscript symbols) and may not
display correctly in very old browsers.



Acknowledgments
----------------

I have to thank Matt Newville, of course. Without :demeter:`ifeffit`
and :demeter:`larch` there wouldn't be an :demeter:`artemis`. Some
content of this document was inspired by a recent XAS review article
by Shelly Kelly and Dean Hesterberg, the first draft of which I had
the pleasure of editing and the final draft of which I ended up on the
author list. I have a huge debt of gratitude to all the folks on the
:demeter:`ifeffit` mailing list. Without the incredible support and
wonderful feedback that I've received over the years,
:demeter:`artemis` would be a shadow of what it is today.

.. bibliography:: artemis.bib
   :filter: author % "Kelly" and year == '2008'
   :list: bullet

An excellent review of the fundamental principles of X-ray absorption
spectroscopy is

.. bibliography:: artemis.bib
   :filter: author % "Newville" and year == '2014'
   :list: bullet

Scott Calvin has written an excellent XAFS text book which covers a
lot of the material covered by :demeter:`artemis`:

.. bibliography:: artemis.bib
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
  
Almost all screenshots were made of either :demeter:`artemis` or the
`Gnuplot <http://gnuplot.info/>`__ window on my `KDE desktop
<http://www.kde.org>`__. 


The image of `the Temple of Artemis at Jerash, Jordan
<http://en.wikipedia.org/wiki/Temple_of_Artemis_(Jerash)>`_ is courtesy of
by Matthew Marcus.

`The image at the top of the navigation sidebar
<http://commons.wikimedia.org/wiki/File:Brauron_-_Votive_Relief1.jpg>`_
is a votive relief from the Archaeological Museum of Brauron in
Brauron, Greece and is in the public domain.  It depicts a family of
worshippers sacrificing a goat to the goddess Artemis.


The image used as the :demeter:`artemis` program icon is Detail from
:quoted:`Bernardino Cametti: Diana as Huntress`, Rome 1717/1720,
marble. Skulpturensammlung (Inv. 9/59; acquired in 1959), Bode-Museum
Berlin.  The image is in the public domain and can be found at
`Wikimedia Commons
<https://commons.wikimedia.org/wiki/File:Cametti_Diana_detail.jpg>`__.

The image of the `leafhopper
<https://www.flickr.com/photos/opoterser/3684369721/>`_ used as a
desktop image in some screen shots is by `Thomas Shanan
<https://www.flickr.com/photos/opoterser/>`_ and is licensed under a
`Creative Commons attribution, non-commercial, no-derivatives
<https://creativecommons.org/licenses/by-nc-nd/2.0/>`_ license.



Data citations
--------------



   
Installing ATHENA on your computer
----------------------------------

**Linux, BSD, and other unixes**
    It is not especially hard to build :demeter:`artemis`
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

The document is found in the :file:`documentation/Artemis` folder.

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

Building the :demeter:`artemis` document requires at least version 1.3
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
   cd Artemis/
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


Using the document with ARTEMIS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The html document files can be used by :demeter:`artemis`.  They are
installed at the time that :demeter:`demeter` is installed.  If the
html pages cannot be found, :demeter:`artemis` will try to use your
internet connection to fetch them from `the Demeter homepage
<http://bruceravel.github.io/demeter/>`__.

