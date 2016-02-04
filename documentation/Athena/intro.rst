..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Introduction to ATHENA
======================

:demeter:`athena` is an interactive graphical utility for processing
EXAFS data. It handles most of the common data handling chores of
interest at the beamline or for preparing your data to begin
analysis. :demeter:`athena` is a graphical front end to Matt
Newville's :demeter:`ifeffit` library written entirely in the Perl
programming language and using the :program:`Gnuplot` program for data
display. It is being developed on Linux and tested on various flavors
of Windows, but should work on any unix-like, Windows, or Mac
operating system.

:demeter:`athena` is intended to provide high quality analysis with a
highly usable interface. It allows very fine grained control over the
processing and plotting of individual data sets while still enabling
the processing and visualization of large quantities of data.

Among :demeter:`athena`'s many, many features, you will find:

- Convert raw data to |mu| (E)

- File import plugins for reading arbitrary data files

- Process and plot multiple data scans simultaneously

- Merge data as |mu| (E), normalized |mu| (E), or |chi| (k)

- Energy calibration

- Align data scans with or without a reference channel

- Deglitch, truncate, convolve, or smooth |mu| (E) data

- Self-absorption corrections for fluorescence spectra

- Compute difference spectra

- Fit linear combinations of standards to |mu| (E), derivative of |mu| (E), or
  |chi| (k) data

- Fit peak functions to XANES data

- Log-ratio/phase-difference analysis

- Background removal using the :demeter:`autobk` algorithm

- Forward and backward Fourier transforms

- Save data as |mu| (E), normalized |mu| (E), |chi| (k), |chi| (R), or
  back-transformed |chi| (k)

- Save project files, allowing you to return to your analysis later

- ... and much, MUCH more!



First Look at ATHENA
--------------------

When :demeter:`athena` first starts, something like the picture below
appears on your computer screen. The :demeter:`athena` window is
divided into several parts.  We will discuss each of these parts and
give each a name.

.. _fig-athenamain:
.. figure:: ../_images/athena_main.png
   :align: center

   The parts of ATHENA.

At the top of the window is a menu bar. This works much like the menu
bar in any program. Much of the functionality in :demeter:`athena` is
accessed through those menus.

The largest part is the main window, the region with all the controls
greyed out in :numref:`Fig. %s <fig-athenamain>`. The main window is
divided into six parts. The top box identifies the file name of the
current `project file <output/project.html>`__. Below that, are
various parameters identifying the current data group.

The next three boxes are used to define the parameters associated with
normalization and background removal, forward Fourier transforms, and
reverse Fourier transforms. At the bottom of the main window are a
couple of parameters associated with plotting.

At the bottom of the screen is the echo area. This very important
space is used by :demeter:`athena` to communicate with you, the
user. This space is used to display informational messages while
:demeter:`athena` is working on your data, error messages when it runs
into trouble, and other kinds of messages.

The large blank area on the right is `the group list area
<ui/glist.html>`__. As data are imported into :demeter:`athena`, they
will be listed in this space. Access to the data already imported is
made by clicking in this space.

Adjacent to the top of the group list area are `the mark buttons
<ui/mark.html>`__, which are used to plot multiple data sets and for
many other chores in :demeter:`athena`.

Below the group list area are the plot buttons. Below that are the
buttons used to set the k-weighting for use when plotting in k-space or
when making a forward Fourier transform. Below that are various other
`plotting controls <ui/mark.html>`__ in the plotting options section.

.. _fig-athenawithdata:
.. figure:: ../_images/athena_withdata.png
   :align: center

   After importing data.

After importing several data files, each is made into a *data group* and
listed in the group list. The label and the check button next to it are
the main controls for interacting with data in :demeter:`athena`.


Getting help
------------

There is quite a bit of help built right into
:demeter:`athena`. Typing :button:`Control`-:button:`m` or selecting
:menuselection:`Help --> Document` will display :demeter:`athena`'s
document in a web browser or in the built-in document viewer.  Many
parts of the program have a button which will take you directly to the
part of the document that describes that part of the program.



Folders and log files
---------------------


Many of :demeter:`athena`'s chores involve writing temporary
files. Many file type plugins write temporary files after performing
some transformation on the original data.  :program:`gnuplot` writes
temporary files as part of its plot creation.

**working folder**
    These files are stored in the :quoted:`stash folder`. On linux (and
    other unixes) this is ``$HOME/.horae/stash/``. On Windows this is
    ``%APPDATA%\\demeter\\stash``.


:demeter:`athena` writes information to screen or to disk during its
operations.  This information is essential when making a bug report.
While the content of this operations log may be inscrutable to you, it
contains information that is invaluable for troubleshooting a bug
report.  If you make a bug report and ask a question about the
operation of the program, it is essential that you include this
information.  If you post a message to the `mailing list
<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>`_ reporting some
kind of problem and you do not include this information, it will be
the first thing Bruce asks for.


**log files**
    When :demeter:`athena` runs into problems, it attempts to write enough
    information to the screen that the problem can be addressed. This
    screen information is what Bruce needs to troubleshoot bugs. On a
    linux (or other unix) machine, simply run :demeter:`athena` from the command
    line and the informative screen messages will be written to the
    screen. You can cut-n-paste that text or capture the output by
    running :demeter:`athena` through `tee <http://www.gnu.org/software/coreutils/manual/html_node/tee-invocation.html>`__
    ::

       ~> dathena | tee capture.log

    On a Windows machine, it is uncommon to run the software from the
    command line, so :demeter:`athena` has been instrumented to write
    a run-time log file. This log file is called :file:`dathena.log` and
    can be found in the ``%APPDATA%\\demeter`` folder.

``%APPDATA%`` is usually ``C:\\Users\\<username>\\AppDataRoaming\\`` on
Windows 7, 8, and 10.

It is usually ``C:\\Documents and Settings\\<username>\\Application
Data\\`` on Windows XP and Vista.

In either case, ``<username>`` is your log-in name.

