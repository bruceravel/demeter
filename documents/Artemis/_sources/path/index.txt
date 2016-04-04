..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The Path page
=============

In this chapter, the method for associating paths with data sets is
explained. We will also see how to begin constructing a fitting model.

Shown below is the Data window, `which we have already seen
<../data.html>`__, with some data from a gold foil already imported.
I have passed the cursor over the active text which says
:guilabel:`Import crystal data or a Feff calculation`.
:mark:`leftclick,..` Clicking will open the standard file selection
dialog, prompting you for an :file:`atoms.inp`, :file:`feff.inp` or
CIF file.  The same thing can be done by clicking the
:button:`Add,light` button above the :guilabel:`Feff` list in the Main
window, by selecting :menuselection:`File --> Open project of data` in
the Main window, or by using the :button:`Control`-:button:`o`
keyboard shortcut.

.. _fig-pathempty:
.. figure:: ../../_images/path-empty.png
   :target: ../_images/path-empty.png
   :align: center

   The Data window with no paths associated.

From the file dialog, I select an :file:`atoms.inp` file containing
these crystal data:

::

    title  gold
    space  f m 3 m
    a = 4.08   rmax = 6.00    core = Au1
    atoms
      Au     0.00000   0.00000   0.00000  Au1

This crystal data is entered in a :demeter:`feff` window and posted to the screen.

.. _fig-pathatoms:
.. figure:: ../../_images/path-atoms.png
   :target: ../_images/path-atoms.png
   :align: center

   The Atoms and Feff window containing gold metal crystal data.

Running :demeter:`atoms` then :demeter:`feff` results in this path list:


.. _fig-pathpathlist:
.. figure:: ../../_images/path-pathlist.png
   :target: ../_images/path-pathlist.png
   :align: center

   The path list for the gold metal calculation.

By :mark:`leftclick,..` clicking on path :guilabel:`0000` in the list
then shift-:mark:`leftclick,..` clicking on path :guilabel:`0012`, the
first 13 paths are selected

.. _fig-pathselected:
.. figure:: ../../_images/path-selected.png
   :target: ../_images/path-selected.png
   :align: center

   The first 13 paths have been selected.

Now :mark:`leftclick,..` click on any of the selected paths. While
holding down the left mouse button, drag those paths over to the right
side of the Data window and drop them by releasing the mouse
button. This will place all 13 of those paths in the path list on the
Data window containing the data on the gold foil.

.. _fig-pathpopulated:
.. figure:: ../../_images/path-populated.png
   :target: ../_images/path-populated.png
   :align: center

   The Data window has been populated with the 13 paths from the Feff
   calculation.

At this point we can begin examining the paths by plotting them along
with the data. The path plotting tools are explained in `the chapter on
the Plot window <../plot/index.html>`__.

Also at this point, we can begin creating a fitting model to fit the
gold foil data using these paths from the :demeter:`feff` calculation.

-----------------

.. toctree::
   :maxdepth: 2

   mathexp.rst
   plot.rst
   pathlike.rst


