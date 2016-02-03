..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The Atoms and Feff Window
=========================

.. todo:: Reorganize content so that table of contents makes sense.


When you import crystal data from an :file:`atoms.inp` or CIF file,
three things happen:

#. A new :demeter:`atoms` and :demeter:`feff` window is created for
   interacting with the structural data and the various controls are
   set to values taken from the atoms.inp or CIF file,

#. A message is written to the status bar in the Main window.

#. An entry is placed in the :demeter:`feff` list on the main window.

You can also import a :file:`feff.inp` file directly. This is discussed in the
`next section <../feff/feff.html>`__

This new window looks like this. In this example, crystal data for
anatase TiO\ :sub:`2` have been imported from an :file:`atoms.inp` file.

.. _fig-feffatoms:
.. figure:: ../../_images/feff-atoms.png
   :target: ../_images/feff-atoms.png
   :align: center

   The Atoms and Feff window.

At the top of the window is a tool bar with four buttons. The first of
these is used to change the name of this :demeter:`feff`
calculation. Among other things, this is the label used in the
:demeter:`feff` list on the Main window. The second button is used to
discard the :demeter:`feff` calculation and this window.  The final
two buttons open a web browser and take you either to the
:demeter:`feff` document or to this page in the :demeter:`artemis`
document.

There are a series of tabs across the top. These will contain
different stages of the structural calculation. Here we will examine
the :demeter:`atoms` tab. The other tabs will be examined in the
following sections.



The toolbar across the top of the :demeter:`atoms` tab offers several
functions.

Clicking the open button will post the standard file selection dialog
for importing a new atoms.inp or CIF file. This is more useful in the
stand-along version of :demeter:`atoms` than in :demeter:`artemis`
where the crystal data file imported in other ways. *Right clicking*
this button will post the recent files dialog populated with recently
imported :file:`atoms.inp`, :file:`feff.inp`, and CIF files.

.. _fig-feffexport:
.. figure:: ../../_images/feff-export.png
   :target: ../_images/feff-export.png
   :align: center

   The save button will prompt you for a filename for an output
   :file:`atoms.inp` saving the current state of the tab.

Clicking the :button:`Export,light` button will post the dialog in
:numref:`Fig. %s <fig-feffexport>`, which offers several different
kinds of output files based on the crystal data.

- The :guilabel:`Feff6` and :guilabel:`Feff8` options will write input
  files for :demeter:`feff6` and :demeter:`feff8`.

- The :guilabel:`Atoms` option write the same file as the save button.

- The :guilabel:`P1` option writes the crystal data to an
  :file:`atoms.inp` file using the ``P 1`` space group and with a fully
  decorated unit cell.

- The :guilabel:`Spacegroup` option writes a file that fully describes
  the space group.

- The :guilabel:`Absorption` option writes a file containing some
  calculations based on tables of X-ray absorption coefficients.

- :guilabel:`XYZ` and :guilabel:`Alchemy` are formats that are
  commonly understood by molecule rendering software.

- :guilabel:`Overfull` is an :quoted:`XYZ` file with the contents of
  the unit cell in Cartesian coordinates and with all atoms near a
  cell wall replicated near the opposite cell wall. The purpose of
  this output type is generate nice figures of unit cells with
  decorations on all the corners, sides, and edges, like 
  :numref:`Fig. %s <fig-fivesixprussianblue>`.

The :button:`Clear,light` button is used to clear all data from all
controls on the :demeter:`atoms` tab.

The :button:`Run,light` button is pressed to convert the crystal data
into input data for :demeter:`feff` then displays `the next tab
<../feff/feff.html>`__.

The :button:`Aggregate,light` button is discussed in detail in `a
later section <../feff/aggregate.html>`__




.. toctree::
   :maxdepth: 2

   xtal.rst
   feff.rst
   paths.rst
   pathlike.rst
   console.rst
   aggregate.rst


