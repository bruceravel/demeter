..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. |transfer button| image:: ../../_static/plot-icon.png

Example 1: FeS2
===============

Introduction, blah blah, known crystal structure, blah blah, learn the
mechanics of the program, blah blah

`Lecture notes <https://speakerdeck.com/bruceravel/discussion-of-the-fes2-exafs-analysis-example>`_


Import data
-----------

After starting :demeter:`artemis`, click on the :button:`Add,light`
button at the top of the :guilabel:`Data sets` list in the Main
window. This will open a file selection dialog. Click to find the
:demeter:`athena` project file containing the data you want to
analyze. Opening that project file displays the project selection
dialog.

.. _fig-fes2importdata:
.. figure:: ../../_images/fes2-importdata.png
   :target: ../_images/fes2-importdata.png
   :width: 50%
   :align: center

   Import data into Artemis

The project file used here has several iron standards. Select
FeS\ :sub:`2` from the list. That data set gets plotted when selected.

Now click the :button:`Import,light` button. That data set gets
imported into :demeter:`artemis`.  An entry for the FeS\ :sub:`2` is
created in the Data list, a window for interacting with the FeS\
:sub:`2` data is created, and the FeS\ :sub:`2` data are plotted as
|chi| (k).

The next step is to prepare for the :demeter:`feff` calculation using
the known FeS\ :sub:`2` crystal structure. Clicking on the line in the
Data window that says :guilabel:`Import crystal data or a Feff
calculation` will post a file selection dialog.  Click to find the
:file:`atoms.inp` file containing the FeS\ :sub:`2` crystal structure.

.. _fig-fes2importatoms:
.. figure:: ../../_images/fes2-importatoms.png
   :target: ../_images/fes2-importatoms.png
   :width: 50%
   :align: center

   Import crystal data into Artemis 

With the FeS\ :sub:`2` crystal data imported, run :demeter:`atoms` by
clicking the :button:`Run Atoms,light` button on the :demeter:`atoms`
tab of the :demeter:`feff` windows. That will display the
:demeter:`feff` tab containing the :demeter:`feff` input data. Click
the :button:`Run Feff,light` button to compute the scattering
potentials and to run the pathfinder.

Once the :demeter:`feff` calculation is finished, the path
intepretation list is shown in the Paths tab. This is the list of
scattering paths, sorted by increasing path length. Select the first
11 paths by :mark:`leftclick,..` clicking on the path
:guilabel:`0000`, then :button:`Shift`-:mark:`leftclick,..` clicking
on path :guilabel:`0010`.  The selected paths will be highlighted.
:mark:`leftclick,..` Click on one of the highlighted paths and,
without letting go of the mouse button, drag the paths over to the
Data window.  Drop the paths on the empty Path list.

.. _fig-fes2pathsdnd:
.. figure:: ../../_images/fes2-pathsdnd.png
   :target: ../_images/fes2-pathsdnd.png
   :width: 50%
   :align: center

   Drag and drop paths onto a data set

Dropping the paths on the Path list will associate those paths with that
data set. That is, that group of paths is now available to be used in
the fitting model for understanding the FeS\ :sub:`2` data.

Each path will get its own Path page. The Path page for a path is
displayed when that path is clicked upon in the Path list. Shown below
is the FeS\ :sub:`2` data with its 11 paths. The first path in the list,
the one representing the contribution to the EXAFS from the S single
scattering path at 2.257 |AA|, is currently displayed.

.. _fig-fes2pathsimported:
.. figure:: ../../_images/fes2-pathsimported.png
   :target: ../_images/fes2-pathsimported.png
   :width: 50%
   :align: center

   Paths associated with a data set 



Examine the scattering paths
----------------------------

The first chore is to understand how the various paths from the
:demeter:`feff` calculation relate to the data. To this end, we need
to populate the Plotting list with data and paths and make some plots.

First let's examine how the single scattering paths relate to the
data.  Mark each of the first four single scattring paths |nd| the
ones labeled :guilabel:`S.1`, :guilabel:`S.2`, :guilabel:`S.3`, and
:guilabel:`Fe.1` |nd| by clicking on their check buttons.  Transfer
those four paths to the Plotting list by selecting
:menuselection:`Actions --> Transfer marked`.

With the Plotting list poluated as shown below, click on the
:button:`R,light` plot button in the Plot window to make the plot
shown.

.. _fig-fes2sspaths:
.. figure:: ../../_images/fes2-sspaths.png
   :target: ../_images/fes2-sspaths.png
   :width: 50%
   :align: center

   FeS2 data plotted with the first four single scattering paths

The first interesting thing to note is that the first peak in the data
seems to be entirely explained by the path from the S atom at 2.257
|AA|.  None of the other single scattering paths contribute
significantly to the region of R-space.

The second interesting thing to note is that the next three single
scattering paths are not so well separated from one another. While it
may be tempting to point at the peaks at 2.93 |AA| and 3.45 |AA| and assert
that they are due to the second shell S and the fourth shell Fe, it is
already clear that the situation is more complicated. Those three single
scattering paths overlap one another. Each contriobutes at least some
spectral weight to both of the peaks at 2.93 |AA| and 3.45 |AA|.

The first peak shold be reather simple to interpret, but higher shells
are some kind of superposition of many paths.

What about the multiple scattering paths?

To examine those, first clear the Plotting list by clicking the
:button:`Clear,light` button at the bottom of the Plot
window. Transfer the FeS\ :sub:`2` data back to the Plotting list by
clicking its transfer button: |transfer button|. Mark the first three
multiple scattering paths by clicking their mark buttons.  Select
:menuselection:`Actions --> Transfer marked`.

With the Plotting list newly populated, make a new plot of \| |chi|\ (R)\|.

.. _fig-fes2mspaths1:
.. figure:: ../../_images/fes2-mspaths1.png
   :target: ../_images/fes2-mspaths1.png
   :width: 50%
   :align: center

   FeS2 data plotted with the first three multiple scattering paths

The two paths labeled :guilabel:`S.1 S.1`, which represent two
different ways for the photoelectron to scatter from a S atom in the
first coordination shell then scatter from another S atom in the first
coordination shell, contribute rather little spectra weight. Given
their small size, it seems possible that we may be able to ignore
those paths when we analyze our FeS\ :sub:`2` data.

The :guilabel:`S.1 S.2` path, which first scatters from a S in the
first coordination shell then from a S in the second coordination
shell, contributes significantly to the peak at 2.93 |AA|. It seems
unlikely that we will be able to ignore that path.

To examine the next three multiple scattering paths, clear the Plotting
list, mark those paths, and repopulate the Plotting list.

.. _fig-fes2mspaths2:
.. figure:: ../../_images/fes2-mspaths2.png
   :target: ../_images/fes2-mspaths2.png
   :width: 50%
   :align: center

   FeS2 data plotted with the next three multiple scattering paths

The :guilabel:`S.1 Fe.1` path, which scatters from a S atom in the
first coordination shell then scatters from an Fe atom in the fourth
coordination shell, is quite substantial. It will certainly need to be
considered in our fit. The other two paths are tiny.


Fit to the first coordination shell
-----------------------------------

We begin by doing an analysis of the first shell. As we saw above, we
only need the first path in the path list. To prepare for the fit, we do
the following:

#. Exclude all but the first path from the fit. With the first path
   selected in the path list and displayed, select
   :menuselection:`Marks --> Mark after current`. This will mark all
   paths except for the first one. Then select :menuselection:`Actions
   --> Exclude marked`. This will exclude those paths from the
   fit. That is indicated by the triple parentheses in the path list.

#. Set the values of R\ :sub:`min` and R\ :sub:`max` to cover just the
   first peak.

#. For this simple first shell fit, we set up a simple, four-parameter
   model. The parameters ``amp``, ``enot``, ``delr``, and ``ss`` are
   defined in the GDS window and given sensible initial guess values.

#. The path parameters for the first shell path are set. S\ :sup:`2`\
   :sub:`0` is set to ``amp``, E\ :sub:`0` is set to ``enot``, |Delta|
   R is set to ``delr``, and |sigma|\ :sup:`2` is set to ``ss``.

Note that the current settings for k- and R-range result in a bit more
than 7 independent points, as computed from the Nyquist criterion. With
only 4 guess parameters, this should be a reasonable fitting model.

.. _fig-fes21stshell:
.. figure:: ../../_images/fes2-1stshell.png
   :target: ../_images/fes2-1stshell.png
   :width: 50%
   :align: center

   Setting up for a first shell fit

Now hit the :button:`Fit,light` button. Upon completion of the fit,
the following things happen:

#. An :quoted:`Rmr` plot is made of the data and the fit.

#. The log Window is displayed with the results of the fit

#. The :button:`Fit,light` and plot buttons are recolored according to
   the evaluation of the happiness parameter.

#. The Plotting list is cleared and repopulated with the data.

#. The fit is entered into the History window (which is not in the
   screenshot below).

.. _fig-fes2firstshellfit:
.. figure:: ../../_images/fes2-firstshellfit.png
   :target: ../_images/fes2-firstshellfit.png
   :width: 50%
   :align: center

   Results of the first shell fit

This is not a bad result. The value of ``enot`` is small, indicatng
that a reasonable value of E\ :sub:`0` was chosen back in
:demeter:`athena`. ``delr`` is small and consistent with 0, as we
should expect for a known crystal. ``ss`` is a reasonable value with a
reasonable error bar. The only confusing parameter is ``amp``, which
is a bit smaller than we might expect for a S\ :sup:`2`\ :sub:`0`
value.

The correlations between parameters are of a size that we expect. The
R-factor evaluates to about 2% misfit. |chi|\ :sup:`2`\ :sub:`v` is
really huge, but that likely means that |epsilon| was not evaluated
correctly. All in all, this is a reasonable fit.


Extending the fit to higher shells
----------------------------------


The final fitting model
-----------------------


Additional questions
--------------------

