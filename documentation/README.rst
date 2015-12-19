
Building Demeter's documentation
================================

Prerequisites
-------------

This version of the Demeter documentation uses `reStructuredText
<http://docutils.sourceforge.net/docs/user/rst/quickstart.html>`_ and
the Sphinx document generation system.  Thus to generate useful
documentation from the source files in this directory, you must have
the following tools installed on your computer:

#. The `Sphinx <http://sphinx-doc.org/>`_ document generator.  On
   Debian based systems, the package is called ``python-sphinx``.
   Features of sphinx 1.3 are used in this document.  Ubuntu 15.04
   comes with version 1.2, which must be upgraded:
   ::

      sudo pip install --upgrade sphinx

#. The `pybtex <http://pybtex.org/>`_ bibliography processor for
   python.
   
#. The `sphinxcontrib-bibtex
   <https://sphinxcontrib-bibtex.readthedocs.org/en/latest/>`_
   package, which is Sphinx extension for BibTeX style citations.

See each packages homepage for installation instructions.  pybtex and
sphinxcontrib-bibtex can be installed using `pip <https://pypi.python.org/pypi/pip>`_:

.. sourcecode:: bash

   pip install sphinxcontrib-bibtex

or, you may need to upgrade all of their prerequisites:

.. sourcecode:: bash

   pip install --upgrade sphinxcontrib-bibtex

I use the `emacs rst-mode
<http://docutils.sourceforge.net/docs/user/emacs.html>`_ to edit the
rst files.  rst-mode is OK -- the indentation behavior is pretty
wonky, though.  In any case, I highly recommend using an rst-sensitive
text editor.

Customizations
--------------

The file ``sphinx/ext/demeterdocs.py`` contains some sphinx roles and
directives for use in Demeter's documents, including:

- decoration of names of programs in Demeter, as well as Feff,
  Ifeffit, and Larch (colored and smallcaps)
  ::
   
     :demeter:`athena`

- decoration of configuration parameters (colored, preceded by a
  colored diamond, right arrow between group and parameter names)
  ::
   
     :configparam:`athena.import_plot`


- decoration of data processing parameters (colored and surrounded by
  guillemots) (``:procparam:``)
  ::
   
     :procparam:`e0`

- quoted text (default text, surrounded by proper opening and closing
  double quotation marks)
  ::
   
     :quote:`This software is awesome!`, said all the critics.

- insert static images such as the lightning bolt or the bend sign,
  image is one of (lightning, bend, somerights, soon)
  ::
   
     :mark:`bend`
  
- insert a linebreak.  This is much like ``..endpar::`` from sphinxtr,
  but it also breaks wrapped text around a figure ::

     .. linebreak::

- decorate characters and words to look like keyboard keys or
  on-screen button in one of four styles (dark, light, purple, orange)
  ::

     :button:`R,purple`
  
The ``_templates`` folder contains some customizations for the html
pages, including:

- ``linksbox,html``: this provides the html markup for the "Links"
  section of the sidebar

- ``layout.html``: this contains header lines for the html output
  which are used to make the link to custom style sheets in
  ``_static`` and ``Athena/_static/``.  Currently the style sheet
  ``subfig.css`` contains some code lifted from `the sphinxtr
  extension <https://github.com/jterrace/sphinxtr>`_ used to display
  subfigures nicely in the html output

- ``program.css``: this style sheet applies some program specific
  branding to the document.  Currently it is only used to set the
  color of the navigation bar at the top and bottom of each page.


The other content of ``sphinx/ext/`` was swiped from `Larch's document
<https://github.com/xraypy/xraylarch/tree/master/doc>`_


Figures and figure numbering
----------------------------

The use of figures and subfigures is a big confusing.  The repository
versions of the images files sit in ``_images/`` underneath this
top-level documentation directory.  Thus the paths to the images must
point to that location.  The ``:target:`` of each image (i.e. the file
that gets linked to each image) must have a path relative to its
location in ``_build/html/_images``.  As a result, the path to image
always has one more ``../`` than the target.

I am currently the using `built-in numref role
<http://sphinx-doc.org/markup/inline.html#cross-referencing-figures-by-figure-number>`_
for figure numbering.  This only supports the html builder.  The
numfig extension purports to support LaTeX, but it fails to do the
html figure numbering correctly.  That said, I am using the subfig
extension for figure grouping, but I am labeling and numbering the
individual figures.

Since this won't work for LaTeX, this is going to have to be addressed
at some point.  But trying to track down the problems with numfig is
beyond my patience right now.

  
Building the html document
--------------------------

.. sourcecode:: bash

   cd Athena
   make html

This will place the document tree in ``Athena/_build/html``.

Artemis and other documents ... coming soon.


Translations
------------

Coming soon!

Athena doc to-do list
---------------------



#. Creative Commons icon in epilog in a way that works throughout the
   source tree

#. In the PCA chapter:

   #. Document all the buttons and whatnot. Document the many
      useful features are still missing.

   #. Need a tutorial on math/science of PCA.  Explain what PCA
      means, what it does, and what it does not do.

#. In project files:

   #. Explain how the metadata dictionary works.

   #. Serialization of analysis results (i.e. LCF, peak fitting, PCA)



	  



