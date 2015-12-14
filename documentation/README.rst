
Building Demeter's documentation
================================

Prerequisites
-------------

This version of the Demeter documentation uses reSTructuredText and
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

.. sourcecode:: bash

   pip install sphinxcontrib-bibtex

or, you may need to upgrade all of their prerequisites:

.. sourcecode:: bash

   pip install --upgrade sphinxcontrib-bibtex


Building the html document
--------------------------

.. sourcecode:: bash

   cd Athena
   make html

This will place the document tree in ``Athena/_build/html``.



Translations
------------

Coming soon!
