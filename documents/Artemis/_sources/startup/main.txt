..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

The main window
===============

The main window provides an overview of the state of
:demeter:`artemis` as well as of your current fitting project. This
window is divided into 7 areas.

.. _fig_mainwindow:

.. figure:: ../../_images/main.png
   :target: ../_images/main.png

   The main window.


#. At the top is a menu bar. We will examine the contents of each menu
   below.

#. At the bottom is the status bar. This area is used to convey messages
   to you during the course of operating the program.

#. On the left is a stack of buttons used to show and hide various
   parts of :demeter:`artemis`. Each of these will be described in
   detail later in the document.

#. To the right is the listing of data groups. The :button:`Add,light`
   button is used to import a new data set into :demeter:`artemis`. As
   data are imported, they will listed as a stack of buttons below the
   :button:`Add,light` button.

#. Next comes the listing of :demeter:`feff` calculations. The
   :button:`Add,light` button is used to import new structural data set into
   :demeter:`artemis`. This may be input data for :demeter:`feff`, an
   :file:`atoms.inp` file, or a CIF file containing crystal structure
   data. As :demeter:`feff` calculations are started, they will listed as a stack of
   buttons below the :button:`Add,light` button.

#. The wide area to the right of the :demeter:`feff` calculations
   contains several controls for the current fitting project. The
   :guilabel:`Name` and :guilabel:`Description` boxes are used to
   describe the current state of your fitting project. The name should
   be a concise description of the current fit and is used as a label
   identifying a specific fit. The description is a lengthier,
   free-form bit of text describing the current fit in more
   detail. This text will be written to log files.
   :demeter:`artemis` does a decent job of automatically generating
   text for both of these boxes, but providing your own text will help
   you to document the progression of your fitting project. This
   section also has controls for selecting the space in which your fit
   is evaluated and for saving a project file in a single click.

#. On the far right is the :button:`Fit,light` button. As you might
   imagine, this button is clicked to initiate a fit. The color of
   this button will change to provide a `heuristic evaluation
   <../fit/happiness.html>`__ of the quality of each fit. Below the
   :button:`Fit,light` button is :button:`Show log,light` button, used
   to show or hide a window containing the results from the most
   recent fit.


File drag and drop
------------------

The data set and :demeter:`feff` calculation area on the main window,
areas 4 and 5 above, are drop targets for files dragged from your
computer's file manager.

- You can drop :demeter:`athena` project files (:file:`.prj`) onto the
  data set area. To import data from some other source, you are
  required to use the :guilabel:`File` menu.

- You can drop CIF, :demeter:`atoms` input, or :demeter:`feff` input
  files onto the :demeter:`feff` calculation area.

- You can drop an :demeter:`artemis` project file (:file:`.fpj`) onto
  either of the data set and :demeter:`feff` calculation areas. To
  import old-style artemis project files or :demeter:`demeter`
  serializations, you are required to use the :file:`File` menu.

You can only drag and drop one file at a time. If you try to drag more
than one of any file type, a warning will be issued in the status bar
and no import will happen. Similarly, you may not drop a folder.


The File menu
-------------

Clicking on :guilabel:`File` displays this menu, which is mostly used
for various kinds of input and output. Note that some menu items that
have keyboard shortcuts attached and that these shortcuts are shown in
the menu.

.. _fit-artemisfilemenu:

.. figure:: ../../_images/filemenu.png
   :target: ../_images/filemenu.png
   :align: center

   The :guilabel:`File` menu.

- The first option is used to import any kind of data into
  :demeter:`artemis`, including :demeter:`artemis` or :demeter:`athena`
  project files, ASCII files containing |chi| (k) data, :demeter:`feff`
  or :demeter:`atoms` input files, CIF files, or a few other
  things. :demeter:`artemis` is usually good about properly identifying
  the type of input file and doing the right thing with it. In the rare
  situation where this doesn't work, try the :guilabel:`import` submenu.

- The second option provides a submenu of recently imported files
  broken down by file type, including :demeter:`artemis` projects,
  :demeter:`athena` projects, structure data for :demeter:`atoms` or
  :demeter:`feff`, and a couple of other more obscure file types.

- The next three items are used to save :demeter:`artemis` project
  files. :guilabel:`Save project` saves the current state of the
  project to its current, prompting for a name if it does not yet have
  one. :guilabel:`Save project as` will prompt for the name to which
  to save the current state of the project. :guilabel:`Save current
  fit` will save a project file containing only the current fit,
  without any of the history. These project files are the sort that
  can be dragged from your computer's file manager onto the data or
  :demeter:`feff` list.

- The :guilabel:`import` submenu is used to specify the file type to
  import.  Typically, this is not necessary and is only provided for
  the rare situation when :demeter:`artemis` fails to recognize one of
  its standard input data types.

- The :guilabel:`export` submenu is used to generate files in the
  format of an :demeter:`ifeffit` script or a perl script using
  :demeter:`demeter`. These files attempt to capture the current state
  of your fitting project. It is unlikely that the output of either of
  these export options will be immediately useful without some
  editing. The purpose of these export options is to allow you to use
  :demeter:`artemis` to develop a fitting model, then use the exported
  file in some other way, for instance as part of a script for
  automated batch processing.

- The next menu item displays a window used to set `program
  preferences. <../prefs.html>`__

- Finally, there are menu items for closing the current fitting
  project and for exiting the program. Each of these will prompt you
  to save your fitting option if you have not recently done so.


The Monitor menu
----------------

This menu provides several options for monitoring the state of
:demeter:`artemis`, :demeter:`ifeffit`, and the plotting backend
(usually :program:`Gnuplot`).

.. _fit-artemismonitormenu:

.. figure:: ../../_images/monitormenu.png
   :target: ../_images/monitormenu.png
   :align: center

   The :guilabel:`Monitor` menu.

- The command buffer contains a record of every data processing
  command sent to :demeter:`ifeffit` or :demeter:`larch` and every
  plotting command sent to the plotting backend. Bruce uses these
  buffers to debug the prgram as he implements new features. You may
  want to use these buffers to learn the details of interacting
  directly with :demeter:`ifeffit`, :demeter:`larch`, or the plotting
  backend.

- The `status bar buffer <../monitor.html#the-status-buffer>`_ contains a
  record of nearly every message sent the status bar in the main
  window as well as those messages displayed in the status bars of
  other windows in :demeter:`artemis`. All messages are time stamped.

- The :guilabel:`Show Ifeffit` menu will cause :demeter:`ifeffit` to
  display detailed information in the command buffer about the
  internal state of different kind of data. This is another thing
  Bruce uses to debug program issues.

- The :guilabel:`Debug options` menu contains several items used to
  display technical information about the current state of
  :demeter:`artemis`. Again, this is a tool Bruce uses when developing
  the program. After reporting a bug to the :demeter:`ifeffit` mailing
  list, Bruce may ask for information obtained using these menu
  items. This submenu is only displayed if the
  :configparam:`Artemis,debug_menus` configuration parameter is set to
  a true value.

- :guilabel:`Show Ifeffit's memory use` item displays a crude,
  somewhat unreliable calculation of the resources still available to
  :demeter:`ifeffit`.

The Plot menu
-------------

.. _fit-artemisplotmenu:

.. figure:: ../../_images/plotmenu.png
   :target: ../_images/plotmenu.png
   :align: center

   The :guilabel:`Plot` menu.


When using :program:`Gnuplot` as the plotting backend, you have an
option to direct plots to multiple windows, thus allowing you to plot
something new without removing an existing plot. This menu controls
which of four such plot displays is active.

The top two options are used to export the most recent plot to a PNG or
PDF file. You will be prompted for a filename.

The bottom two options tick on or off the :guilabel:`Plot after fit` buttons for
each data set, which may be useful for a multiple data set fit.

:demeter:`artemis` can make plots in a style that resembles the famous
`XKCD comic <http://xkcd.com/>`__. To make use of this most essential
feature, you should first download and install the `Humor-Sans font
<http://antiyawn.com/uploads/humorsans.html>`__ onto your computer.
Once you have installed the font, simply check the
:menuselection:`Plot --> Plot XKCD style` button. Enjoy!


The Main help menu
------------------

This menu is used to display this document or to display information
about :demeter:`artemis`, including its open source licensing terms.

.. _fit-artemishelpmenu:

.. figure:: ../../_images/helpmenu.png
   :target: ../_images/helpmenu.png
   :align: center

   The :guilabel:`Help` menu.



Status bar
----------

This area in the main window is used to display various kinds of
messages, including updates on long-running tasks, hints about
controls underneath the mouse, and other announcements.

On some platforms, the status bar is able to display color.  If you
are one one of those platforms, the status bar will display with a
green background during a long running task and with a red background
when an error has occured or when something needs your immediate
attention.

Many controls in the main window and elsewhere have hints attached to
them which will be displayed in this status bar when the mouse passes
over.  These hints are intended to teach about the functionality of
the control beheath the mouse.  Hints are not recorded in the status
bar buffer.

Many short and long running tasks display updates of various
kinds. Many of these are recorded in the `status bar buffer
<../monitor.html#the-status-buffer>`_.  Messages displayed in the status
bar with a green or red background are recorded in the status bar
buffer with green or red text.  Messages which only indicate the
progress of a long running task are not recorded in the buffer.


The Data list
-------------

The data list starts off with a single control, which is used to
import data into your fitting project. Clicking the
:button:`Add,light` button will open the standard file selection
dialog for your platform. That is, on Windows, the standard Windows
file selection dialog is used; on Linux, the standard Gnome file
selection dialog is used; and so on.

.. _fit-artemisdatalist:

.. figure:: ../../_images/datalist.png
   :target: ../_images/datalist.png
   :align: center

   The data list.


The standard manner of importing data into :demeter:`artemis` is to
use an :demeter:`athena` project file. Thus the file selection dialog
will, by default, look for files with the :file:`.prj` extension. You
may also drag :file:`.prj` files from your computer's file manager and
drop them onto the data list.

As you import data, a stack of buttons |nd| one for each data group |nd| is
made. These buttons are used to show or hide the windows associated
with each data group. In this example, a multiple data set fit
(i.e. one in which models for more than one data set are co-refined)
is shown. One of the associated data windows is displayed on screen,
as indicated by the depressed state of the button labeled
:guilabel:`Dimethyltin dichloride`. The other data window is
hidden. `See the Data window chapter. <../data.html>`__

.. caution:: :demeter:`artemis` has a very different relationship to
   your data than :demeter:`athena`.  The very purpose of
   :demeter:`athena` is to process large quantities of data, thus a
   typical :demeter:`athena` project will contain many |nd| perhaps
   dozens |nd| of data groups. :demeter:`artemis` expects that you
   will import only that data whose EXAFS you intend to analyze.  If
   you are doing a single-data-set analysis, the :guilabel:`Data` list
   will contain only that item.  If you import many data sets without
   actually using them in the fitting model, :demeter:`artemis`
   may get confused.  *And so will you*.


The Athena project selection dialog
-----------------------------------

When importing data from an :demeter:`athena` project file, the
project selection dialog is shown. It presents you with a list of all
data groups from the project file. The file listing is configured such
that only one item can be selected at a time. The selected data group
is also plotted. Any title lines from that data group are displayed in
the text box on the upper right.

.. _fit-artemisathenaselection:

.. figure:: ../../_images/athenaselection.png
   :target: ../_images/athenaselection.png
   :align: center

   The :demeter:`athena` project selection dialog.

The plot that is made when you select a data group is controlled by
the :guilabel:`Plot as` box of radio buttons.  These buttons have no
impact on how the data imported into :demeter:`artemis`.  They are
only used to determine how the data are displayed to you as you select
the data group to import.  Unlike the :demeter:`athena` project
selection dialog, this one only allows you to select one data group at
a time.

The next set of radio buttons selects what set of Fourier transform
and fitting parameters will be used. The first choice says to use the
values found in the :demeter:`athena` project file. The second choice
says to use :demeter:`artemis`'s default values. The third choice is
only relevant when replacing the data in a current fitting project. In
that case, the values currently selected for the data being replaced
will be retained.

To continue importing data, click the :button:`Import,light` button. The
:button:`Cancel,light` button dismisses this dialog without importing data.

The recent data dialog
----------------------

You can access a list of recently imported data by
:mark:`rightclick,..` *right* clicking on the :button:`Add,light`
button. This presents a dialog with a selection list.  Click on one of
your recent files, then click :button:`OK,light` or type
:button:`Return`.  Alternately, :mark:`leftclick,..` double-click on
your choice in the list of recent files.

.. _fit-artemisrecentdata:

.. figure:: ../../_images/recentdata.png
   :target: ../_images/recentdata.png
   :align: center

   The recent data dialog.


The Feff list
-------------

The :demeter:`feff` list starts off with a single control, which is
used to import structural data into your fitting project.  Clicking
the :button:`Add,light` button will open the standard file selection
dialog for your platform. That is, on Windows, the standard Windows
file selection dialog is used; on Linux, the standard Gnome file
selection dialog is used; and so on.

.. _fit-artemisfefflist:

.. figure:: ../../_images/fefflist.png
   :target: ../_images/fefflist.png
   :align: center

   The :demeter:`feff` list.

The standard manner of importing structural data into
:demeter:`artemis` is to import an input file for :demeter:`atoms` or
:demeter:`feff` or to import a CIF file containing crystal data. Thus
the file selection dialog will, by default, look for files with the
:file:`.inp` or :file:`.cif` extension.

As you import structural data, a stack of buttons |nd| one for each
:demeter:`feff` calculation |nd| is made. These buttons are used to
show or hide the windows associated with each data group. In this
example, two :demeter:`feff` calculations have been made. Neither is
being displayed on screen. `See the Atoms/Feff
chapter. <../feff/index.html>`__

:mark:`rightclick,..` *Right* clicking on the :button:`Add,light`
button will present the same recent file selection dialog as for the
data list. In this case, the list will contain recently imported
:demeter:`atoms`, :demeter:`feff`, or CIF files.

You may also drag CIF, :demeter:`atoms` input, or :demeter:`feff`
input files from your computer's file manager and drop them onto the
:demeter:`feff` list.


Fit information
---------------

This section of the main window is used to specify properties of the
fit. The name is a short bit of text that will be used as a label for
each fit. The number will be auto-incremented unless you explicitly
set it.

.. _fit-artemisfitproperties:

.. figure:: ../../_images/fitproperties.png
   :target: ../_images/fitproperties.png
   :align: center

   The fit properties.

The description is a longer bit of text which you can use to describe
the current fitting model. Here, too, the number is auto-incremented
unless you explcitly set it. The text from this box is written to the
log file, thus can be used to document your fitting model.

The set of radio buttons is used to select the space in which the fit
will be evaluated. The default is to evaluate the fit in R space.

Finally, the :button:`Save,light` button is used to quickly save your
fitting model to a project file. If you model is already associated
with a file, this is a quick one-click saving tool. If no project file
is associated, the file selection dialog will prompt you for a
file. The default is to use the .fpj extension.


Fit and log buttons
-------------------

All the way to the right of the main window are the
:button:`Fit,light` and :button:`Show log,light` buttons.  Click the
Fit button to initiate the fit. The log button is used to show and
hide a window which displays the log from the most recent fit. `See
the chapter on the Log and Journal windows. <../logjournal.html>`__ In
the event of a fit that exits abnormally, error messages explaining
the problems will be show in the log window.

.. _fit-artemisfitlogbuttons:

.. figure:: ../../_images/fitlogbuttons.png
   :target: ../_images/fitlogbuttons.png
   :align: center

   The :button:`Fit,light` and :button:`Show log,light` buttons.


At start-up the Fit button is yellow. After each fit, the color of
this button will range from red to green as a heuristic indication of
the fit quality. `See the happiness section for more details
<../fit/happiness.html>`__.

