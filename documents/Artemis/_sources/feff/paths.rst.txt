..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The Paths tab
=============

When you click the :button:`Run Feff,light` button on the
:demeter:`feff` tab, the :demeter:`feff` calculation is run. Once
finished, a succinct summary of the calculation is displayed on the
Paths tab.

.. _fig-feffpaths:
.. figure:: ../../_images/feff-paths.png
   :target: ../_images/feff-paths.png
   :align: center

   The Paths tab.

Some statistics about the :demeter:`feff` calculation are shown in the
:guilabel:`Description` text box. Below that is the summary of the
paths found in the :demeter:`feff` calculation. This summary is
presented in the form of a table. Each row describes a scattering
path. The columns contain the following information:

#. The first column shows a path index, similar to the index that
   :demeter:`feff` uses when run by hand from the command line.

#. The second column shows the degeneracy of the path.

#. The third column shows its nominal path length, R\ :sub:`eff`. That
   is value that will be used in any `path parameter math
   expression <../path/mathexp.html>`__ containing the ``reff`` token.

#. The fourth column shows a simple view of the scattering path. The
   ``@`` token represents the absorber, thus appears as the first and
   last token in each description. The tokens representing the
   scattering atoms are taken from the tags on the :demeter:`feff`
   tab. You can change the absorber token by setting the
   :configparam:`Pathfinder,token` configuration parameter.

#. The fifth column contains the rank of the path. This is an attempt to
   predict how important of each path will be to your fitting model.
   Paths with large spectral weight have a large rank and paths with
   little spectral weight have small rank. Highly ranked paths are
   colored green, mid-rank paths are colored yellow, and low-rank paths
   are grey. Don't put too much faith in this assessment of importance.
   You should explicitly check all paths to decide if they should be
   included in a fit.

#. The sixth column gives the number of legs in each path.

#. The final column is a simple explanation of the shape of the
   scattering geometry.

The rows in this table are selectable by mouse
click. :mark:`leftclick,..` Left clicking on a row selects that
row. :button:`Control`-:mark:`leftclick,..` clicking on another row
adds it to the selection. :button:`Shift`-:mark:`leftclick,..`
clicking adds to the selection all rows between the one clicked upon
and the previously clicked upon row.

Much of the functionality of this page rests upon the set of selected
paths. Most importantly, selecting paths is the first step to using
paths in a fitting model. This will be explained in the `next
chapter <../path/index.html>`__.

At the top of the page is a bar of buttons used to perform tasks
specific to the path list. The :button:`Doc,light` button will open a
browser displaying this documentation for the interpretation page. The
:button:`Rank,light` button is described below. The remaining buttons
are related to making plots of the selected paths.



Polarization
------------

If :demeter:`feff` has been run considering linear polarization, the
path list may be considerably longer. The degeneracy checker in the
path finder calculation will recognize the effect of polarization on
path degeneracy. Paths with common outgoing and incoming angles of the
photoelectron with respect to the specified polarization vector will
be treated as degenerate. Paths which would be degenerate in the
absence of polarization, but which have distinct outgoing and/or
incoming angles will be presented as separate paths in the path list.

When the polarization calculation is performed, the outgoing and
incoming angles will be displayed in :guilabel:`Scattering path`
column (although you may need to widen the column by clicking on and
dragging the little vertical line that separates the
:guilabel:`Scattering path` and :guilabel:`Rank` columns in the header
row).

Also, when :mark:`drag,..` dragging a path onto the data page, the
angles out and in will be displayed in the path geometry box on the
`path page <../path/index.html>`__.

Optionally, the angles can be displayed in the path list label by
setting the :configparam:`Pathfinder,label` configuration parameter
appropriately.

Low ranking paths are, by default, not displayed in the paths list. In
a polarization calculation, typically, paths close to or at 90 degrees
in either angle will have very small amplitude and so will not be
displayed in the path list. This behavior of suppressing low-ranking
paths can be controlled by setting the
:configparam:`Pathfinder,postcrit` configuration parameter. Setting it
to 0 will cause all paths, even the right angle ones, to be displayed
in the paths list.

.. caution:: :demeter:`feff`'s ``ELLIPTICITY`` keyword is not
   supported at this time.  That means the trick of modeling
   :quoted:`polarization in the plane` is not yet supported by
   :demeter:`artemis`.


Path plotting and path geometry
-------------------------------

.. figure:: ../../_images/feff-plot.png
   :target: ../_images/feff-plot.png
   :align: center

   This is a plot of paths from the raw Feff calculation.

In this example, the first three single scattering paths from the
sodium uranyl triacetate calculation were selected along with a
low-rank multiple scattering path. Then the :guilabel:`Plot selection`
button was pressed.  In this plot, we see that the three single
scattering paths are, indeed, quite large. The multiple scattering
path can barely be seen on this scale. It truly is a low importance
path.

The meaning of a :quoted:`raw` :demeter:`feff` calculation is that it
is displayed as |chi| (k) with S\ :sup:`2`\ :sub:`0` set to 1.0 and
each of E\ :sub:`0`, |Delta| R, and |sigma|\ :sup:`2` set to 0. A plot
of |chi| (R) for the :quoted:`raw` :demeter:`feff` calculation, then,
displays the Fourier transform of |chi| (k) parameterized with those
values.

It is, therefore, very quick and easy to examine the results of a
:demeter:`feff` calculation. The other four buttons are used to select
how the plot of paths is made. The options are |chi| (k), \| |chi|
(R)\|, Re[|chi| (R)], and Im[|chi| (R)].  The k-weight selected in the
Plot window is used to make the plot of paths.

:mark:`rightclick,..` Right clicking on an entry in the paths list
will post a menu. The first item on the menu opens a dialog window
with more details about the geomtery of the selected scattering
path. In the following figure, the selected path (0006) was
:mark:`rightclick,..` right-clicked on, opening the dialog depicted
below.

The other context menu options are used to set the path select on the
basis of distance, ranking, or scattering geometry. These options are
useful for selecting groups of paths to :mark:`drag,..` drag and drop
onto the Data window.

.. figure:: ../../_images/feff-pathsinfo.png
   :target: ../_images/feff-pathsinfo.png
   :align: center

   Information about the geometry of a scattering path.

The contents of the path interpretation can be filtered after running
the :demeter:`feff` calculation by setting the :configparam:`Pathfinder,postcrit`
parameter. By default, it is set to 3, which means that only paths
with a ranking above 3 will be displayed in the path
interpretation. Resetting this parameter allows you tune how many
paths get displayed after the calculation.


Path ranking
------------

:demeter:`feff` provides a crude evaluation of the importance of each
path called the :quoted:`curved wave importance factor`. This is
computed as a very sparse |nd| computed at four points between 0 |AA|\
:sup:`-1` and 20\ |AA|\ :sup:`-1` |nd| trapezoidal integration of
\| |chi| (k)\|. This amplitude is then expressed as a percentage with
the largest path having an amplitude of 100.

There are a few shortcomings of :demeter:`feff`'s amplitude
factor. First, the percentages are computed serially. So the first
path is always given as 100%. If a subsequent path is larger than the
first path, it, so, will be given as 100%. All following paths will be
scaled to size of the later path. This is somewhat confusing.

Second, the integration is very sparse. This made sense back in the
mid-90s, when computers were slower and had less memory. But it means
the amplitude is not very accurate.

Finally, the integration is over a much wider range in k-space than is
typically measured in a real experiment. It would make more sense to
evaluate a measure of the importance of a path over a range in k that is
expressed in a real measurement or, at least, a range that is more
typical of a normal experiment.

To this end, :demeter:`artemis` offers a variety of new ways to rank the
importance of a path. Some use |chi| (k) and some use |chi| (R) of the
paths. All are evaluated over a restricted range in k or R. By
default, the range in k is 3\ |AA|\ :sup:`-1` and 12\ |AA|\ :sup:`-1`
and in R it is 1 |AA| and 4 |AA|. All are evaluated using the full k
or R grid which is used internally. Some consider k-weighting.

They all have funny acronyms:

 **akc**
    This is the sum over the k-range of the absolute value of k |chi| (k).
 **aknc**
    This is the sum over the k-range of the absolute value of
    k\ :sup:`n`\ |chi| (k) where the plotting k-weight is used for n.
 **sqkc**
    This is the square root of the sum over the k-range of the square of
    k |chi| (k).
 **sqknc**
    This is the square root of the sum over the k-range of the square of
    k\ :sup:`n`\ |chi| (k) where the plotting k-weight is used for n.
 **mkc**
    This is the sum over the k-range of k\| |chi| (k)\|.
 **mknc**
    This is the sum over the k-range of k\ :sup:`n`\ \||chi| (k)\| where the
    plotting k-weight is used for n.
 **mft**
    This is the maximum value of \| |chi| (R)\| within the R-range where the
    plotting k-weight is used for the Fourier transform.
 **sft**
    This is the sum over the R-range of \| |chi| (R)\| where the plotting
    k-weight is used for the Fourier transform.

These new ranking criteria tend to do a better job of correctly
predicting which paths are important to a fit. That's a good thing. The
bad thing is that they take quite a bit longer to compute than simply
relying on :demeter:`feff`'s amplitude ratios.

The full suite of options are provided in order to replicate the
analysis shown in the paper by K. Provost, et al. The :quoted:`akc`
and :quoted:`aknc` choices tend to be reliable.

You can select which criterion to use on the interpretation page by
setting the :configparam:`Pathfinder,rank` configuration parameter to
:guilabel:`feff` or to one of the acronyms above.

You can compare the evaluations of the ranking criteria by pressing
the :button:`Rank,light` button in the toolbar. This calculation takes
about a third of a second per path. If there are a lot of paths in the
interpretation, this can be a bit time consuming. At the end, a text
dialog with the various rankings for each path is displayed. As can be
seen in the figure below, there is some variation between the
criteria, but all of them differ substantially from :demeter:`feff`'s
importance factors.

.. figure:: ../../_images/feff-rank.png
   :target: ../_images/feff-rank.png
   :align: center

   The report on the path ranking calculation.

This improvement upon :demeter:`feff`'s path selection tool is adapted from 

.. bibliography:: ../artemis.bib
   :filter: author % "Provost"
   :list: bullet


None of the path ranking criteria currently use |sigma|\ :sup:`2` when
they are being evaluated, but that would be an interesting
consideration.
