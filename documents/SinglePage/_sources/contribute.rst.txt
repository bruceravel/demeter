

..
   This document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Making contributions to the Demeter project
===========================================


Have you benefited by :demeter:`ifeffit` and its community of friendly
people?  Ever thought about doing something to contribute to the
community?  This document offers some suggestion for things you can do
to help the :demeter:`ifeffit` community.


Day to day contributions
------------------------

- Answer a question on the mailing list.

- Report a bug or make a suggestion for improving the codes.  Do this
  on the `Ifeffit mailing list
  <http://millenia.cars.aps.anl.gov/mailman/listinfo/ifeffit>`_ or at
  :demeter:`demeter`'s `issues page
  <https://github.com/bruceravel/demeter/issues>`_


Documentation contributions
---------------------------

- Write a web page explaining something about XAS.

- Measure a library of reference materials for some element and share
  an :demeter:`athena` project file containing the processed data.

- Explain a data analysis problem in the form of a series of annotated
  project files.

- Make a video explaining how to do something with the software.

- Give a lecture at an XAS training course.  Post your presentation and
  any relevant data on http://xafs.org or elsewhere.

Packaging contributions
-----------------------


- Make, support, and keep up-to-date installer packages for Debian based
  systems, Red Hat based systems, other Linux distributions, or BSD.

- Improve the Windows installer: add more XAS-related Start menu
  options, add more perl-related Start menu options, write a better
  :file:`README` file for display upon installation, figure out how to
  dispense with the useless dosbox, etc.

- As a Windows updater, could something be done with git and automating
  the build process?

- Desktop functionality for Windows, Mac, KDE, GNOME/Unity, etc.  By
  this I mean things like looking inside an :demeter:`athena` project
  file (a la :program:`dlsprj`) and displaying that information in the
  file manager.  Or showing an image of the most recent fit when an
  :demeter:`artemis` project file is selected.


Programming contributions
-------------------------

- Identify and fix a bug in the codes.  Submit a patch to Bruce or issue
  a pull request at https://github.com/bruceravel/demeter

- Write a file type plugin for the weird data files from some weird
  beamline.

- Write an interesting and novel program using :demeter:`demeter` and
  share it with the world.

- I have long wanted to integrate `OpenBabel
  <http://openbabel.org/wiki/Main_Page>`_ into :demeter:`artemis`.
  OpenBabel is a framework for converting between molecule file
  formats.  The :file:`feff.inp` format could be integrated into
  OpenBabel by writing a bit of C++.  With :demeter:`feff` integrated
  into OpenBabel, :demeter:`demeter` could use OpenBabel's `Perl
  interface <http://openbabel.org/wiki/Perl>`_.  This means that any
  molecule format could be imported into :demeter:`artemis` and used
  as the basis of a :demeter:`feff` calculation.  Writing the
  OpenBabel interface and contributing it the OpenBabel project would
  be a most splendid contribution to Demeter while at the same time
  opening up :demeter:`feff` support to the many projects that use
  OpenBabel.

