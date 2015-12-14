
Building Demeter's documentation
================================

Prerequisites
-------------

This version of the Demeter documentation uses `reSTructuredText
<http://docutils.sourceforge.net/docs/user/rst/quickstart.html>`_ and
the Sphinx document generation system.  Thus to generate useful
documentation from the source files in this directory, you must have
the following tools installed on your computer.

#. The `Sphinx <http://sphinx-doc.org/>`_ document generator.  On
   Debian based systems, the package is called ``python-sphinx``.

#. The `pybtex <http://pybtex.org/>`_ bibliography processor for
   python.
   
#. The `sphinxcontrib-bibtex
   <https://sphinxcontrib-bibtex.readthedocs.org/en/latest/>`_
   package, which is Sphinx extension for BibTeX style citations.

See each packages homepage for installation instructions.  pybtex and
sphinxcontrib-bibtex can be installed using `pip <https://pypi.python.org/pypi/pip>`_:

I use the `emacs rst-mode
<http://docutils.sourceforge.net/docs/user/emacs.html>`_ to edit the
rst files.  rst-mode is OK -- the indentation behavior is pretty
wonky, though.  In any case, I highly recommend using an rst-sensitive
text editor.

.. sourcecode:: bash

   pip install sphinxcontrib-bibtex

or, you may need to upgrade all of their prerequisites:

.. sourcecode:: bash

   pip install --upgrade sphinxcontrib-bibtex

Customizations
--------------

The file ``sphinx/ext/demeterdocs.py`` contains some sphinx roles for
use in Demeter's documents, including:

- decoration of names of programs in Demeter, as well as Feff,
  Ifeffit, and Larch (colored and smallcaps)

- decoration of configuration parameters (colored, preceded by a
  colored diamond, right arrow between group and parameter names)

- decoration of data processing parameters (colored and surrounded by
  guillemots)

- quoted text (default text, surrounded by proper opening and closing
  double quotation marks)


The ``_templates`` folder contains some customizations for the html
pages, including:

- ``linksbox,html``: this provides the html markup for the "Links"
  section of the sidebar

- ``layout.html``: this contains header lines for the html output
  which are used to make the link to the custom style sheets in
  ``Athena/_static/``.  Currently that style sheet, ``subfig.css``
  contains some code lifted from `the sphinxtr extension
  <https://github.com/jterrace/sphinxtr>`_ used to display subfigures
  nicely in the html output


The other content of ``sphinx/ext/`` was swiped from `Larch's document
<https://github.com/xraypy/xraylarch/tree/master/doc>`_


  
Building the html document
--------------------------

.. sourcecode:: bash

   cd Athena
   make html

This will place the document tree in ``Athena/_build/html``.



Translations
------------

Coming soon!
