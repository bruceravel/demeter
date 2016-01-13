..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Marking and Plotting
====================

The check buttons next to each path in the path list are central to
many features in :demeter:`artemis` related to plotting and other
tasks. Along with all of the tools in the Mark menu, you can mark a
group of paths by clicking elsewhere on the path list while holding
down the shift key. Doing so marks all paths between the selected one
and the one shift-clicked upon.

:button:`Control`-clicking on the path list is also a special function
used for two purposes. Doing a :button:`Control`-click starts a
drag-and-drop with the path you click on. Dropping the path on another
data window, copies If you drop the path on the same path list, that
path to that Data set.  Dropping the path on the same path list is
equivalent to cloning the dragged path, with the clone being appended
to the end of the path list.

.. caution:: Mistakenly :button:`Control`-clicking rather than
   :button:`Shift`-clicking will likely result in a path being
   cloned. This can be surprising and confusing, so take care!

.. todo:: Write a page about tools for building MDS fits



Moving paths to the Plotting list
---------------------------------

:demeter:`artemis` has no special plot types involving individual
paths like `those for the data sets
<../data.html#specialplots>`__. Any plots with paths are constructed
using the Plotting list on the `Plot window
<../plot/index.html>`__. There are three ways of moving individual
paths to the Plotting list.

#. The blue button with the squiggly line in the upper left corner of
   the Path page transfers that path to the Plotting list.

#. A path will be transferred automatically after a fit if its
   :guilabel:`Plot after fit` button is checked.

#. The set of marked groups will be transferred when
   :menuselection:`Actions --> Transfer marked` is selected. This is
   probably the most common way of constructing plots involving paths.

:demeter:`artemis` offers a concept called a :quoted:`virtual path`,
or a :quoted:`VPath`.  A VPath is an ensemble of normal paths which
are summed.  The sum is then plotted in k-, R-, or q-space.  A VPath
is made by marking a set of paths then selecting
:menuselection:`Actions --> Make VPath from marked`.  VPaths are
discussed in more detail `the chapter on the Plot window
<../plot/vpaths.html>`__.

.. subfigstart::

.. _fig-pathau4:

.. figure::  ../../_images/path-au4.png
   :target: ../_images/path-au4.png
   :width: 100%

   Data on a gold foil plotted as Re[ |chi| (R)] with the fourth shell
   single scattering path and the two colinear multiple scattering
   paths involving the fourth neighbor and the intervening first shell
   neighbor. This is a rather cluttered plot due to the phase
   relationship between these three paths.

.. _fig-pathau4vpath:

.. figure::  ../../_images/path-au4vpath.png
   :target: ../_images/path-au4vpath.png
   :width: 100%

   The VPath composed of those three paths is plotted along with the
   data. This is a much cleaner plot and gives you a sense of the net
   impact of the fourth neighbor on the fit.

.. subfigend::
   :width: 0.45
   :label: _fig-path-auvpath


When the VPath is created, it is placed in the VPath tab in the Plot
window and in the Plotting list. The VPath list contains tools for
renaming and discarding VPaths, displaying its constituants in the
Main window status bar, and a VPath onto the Plotting list. (Remember
that, unless the :guilabel:`Freeze` button is clicked, the Plotting
list is cleared and repopulated after each fit.)


Phase corrected plots
---------------------

When the Data page button labeled :guilabel:`Plot with phase
correction`, plots using that data set and/or any of its paths will be
plotted with phase correction. This means that the contributions of
the central and scattering atom phase shifts will be removed before
the Fourier transform. This has the effect of shifting the peaks in
|chi| (R) by about -0.5 |AA|, such that the first shell peaks at an R
value close to the physical interatomic distance between the absorber
and first shell scatterer.

The phase information is taken from one of the paths. Each path has a
button labeled :guilabel:`Use this path for phase corrected
plotting`. These buttons are exclusive – only one path per data set
can have its button ticked on. The phase information from that path is
used for the phase corrected plots.

If you turn on phase corrected plotting without having selected a path
to use, :demeter:`artemis` will issue a warning in te status bar and
turn phase corrected plotting back off. You **must** select a path to
use as the source of the phase information.

Note that, when making a phase corrected plot, the window function in R
is not corrected in any way.

Also note that the phase correction propagates through to |chi|
(q). While the window function will display sensibly with the central
atom phase corrected |chi| (q), a “kq” plot will be somewhat less
insightful because phase correction is not performed on the original
|chi| (k) data.
