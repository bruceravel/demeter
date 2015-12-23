..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The History window
==================

:demeter:`artemis` keeps a complete history of your fitting
project. After each fit, your fitting model and the state of the
program are saved as part of the fitting project. When a project file
is written, this history is stored in the project file. This allows
you to compare fits or even to revert :demeter:`artemis` to an earlier
fit.

.. _fig-historylog:
.. figure:: ../_images/history-log.png
   :target: _images/history-log.png
   :align: center

   Fit history window

Interactions with the fit history are via the History window, which is
shown and hidden using the History button on the left side of the Main
window.

The History window shows two major controls. On the left is a list all
fits performed as part of the fitting prject. Like many other lists in
:demeter:`artemis`, this contains elements that can be selected and
marked. This list uses multiple selection, so control-clicking can be
used to add to the selection and shift-clicking can be used to select
groups of fits.  Much of the analysis discussed below uses the
selection. Some functionality uses the set of marked fits.

On the right is a notebook. The first tab is for displaying the log
files from old fits. The log file displayed when the most recent fit is
clicked upon is identical to the log file displayed in the Log window.

You may find that there is a short pause between clicking on a fit and
seeing its log file displayed. When importing a project file,
:demeter:`artemis` delays importing the fits until one is explicitly
needed. For a large project file, this greatly speeds up import at the
small cost of a pause when examining log files.

.. _fig-historymenu:
.. figure:: ../_images/history-menu.png
   :target: _images/history-menu.png
   :align: center

   The history context menu

Each fit in the list will display a context menu when right
clicked. Again, there may be a short pause before the menu gets
posted. In that menu are a variety of functions related to the fit
history.

:guilabel:`Restore fitting model`
    An prior fitting model can be restored. This will clear all of
    :demeter:`artemis`' windows and replace them with content from that fit.
:guilabel:`Save log file`
    The log file displayed can be written to a text file. You will be
    prompted for a file name and location.
:guilabel:`Export fit`
    The fit can be exported to an :demeter:`artemis` project file containing only
    that fit in the fit history.
:guilabel:`Discard fit(s)`
    The current or the set of marked fits can be discarded from the
    project.
:guilabel:`Show YAML`
    The last item is a tool used to help debug problems in ARTEMIS. It
    displays :demeter:`artemis`' internal representation of the fit in a text
    window.


Reports on fits
---------------

The second tab is used to analyze groups of fits. In the example shown
above, the progression of |chi|\ :sup:`2`\ :sub:`ν` values throughout
the development of the fitting model is shown both as a textual report
and as a plot.  Similar plots can be made for individual parameter
values.

.. subfigstart::

.. _fig-historyreport:

.. figure::  ../_images/history-report.png
   :target: _images/history-report.png
   :width: 100%

   Generate a report from the marked fits.

.. _fig-historyreportplot:

.. figure::  ../_images/history-reportplot.png
   :target: _images/history-reportplot.png
   :width: 100%

   A plot of the generated report.

.. subfigend::
   :width: 0.45
   :label: _fig-historyreporting


Only the marked fits are included in the report. If no fits are
marked, then all fits will be marked before the report is
generated. Simple controls for setting the marks are at the bottom of
the list. The buttons marked :button:`All,light` and
:button:`None,light` set and clear all marks. The
:button:`Regexp,light` button will prompt you for a pattern to match
against all fit names.

When a fit is selected from the list, the :guilabel:`Select parameter`
menu is populated with the names of the parameters used in that
fit. All parameter types are included. Selecting a new item from the
menu or clicking the :button:`Write report,light` button will generate
a new report and its plot.

For statistics, all of |chi|\ :sup:`2`, |chi|\ :sup:`2`\ :sub:`ν`,
R-factor, and the happiness are reported. You can choose which of
|chi|\ :sup:`2`\ :sub:`ν`, R-factor, and happiness to have displayed
in the resulting plot. Clicking the :guilabel:`Show y=0` button forces
the plot to be scaled of the y-axis such that y=0 is shown.

Buttons at the bottom of this tab allow you to save the report as a text
file or to send it to the printer.

Plotting fits
-------------

The plot tool tab is used to place old fits in the Plotting list for
comparison with data and with the current fit. As you perform fits (or
when a project file is imported), an entry on the :guilabel:`Plot
tool` page is made for each fit. Within the box associated with each
fit is one button for each data set included in the fit. The example
below is of a single data set fit to Co metal, thus each fit has a
single button associated with it.

.. _fig-historyplottool:
.. figure:: ../_images/history-plottool.png
   :target: _images/history-plottool.png
   :align: center

   Fit history plotting tool

Clicking one of the buttons on the :guilabel:`Plot tool` page makes an
entry in the plotting list. These will then be plotted just like any
other item in `the plotting list <plot/index.html>`_. Note that it is
usually not necessary to put the most recent plot in the plotting list
in this way.  If the “Plot fit” button is checked on and a data group
is in the plotting list, the most recent will be plotted by
default. Fit items in the plotting list will `be stacked
<plot/stack.html>`_ when the stacking option is in play.

.. _fig-historyplotlist:
.. figure:: ../_images/history-plotlist.png
   :target: _images/history-plotlist.png
   :align: center

   Historical fits placed in the plotting list

