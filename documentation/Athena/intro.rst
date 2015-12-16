.. _intro_chapter:

Introduction to ATHENA
======================

:demeter:`athena` is an interactive graphical utility for processing
EXAFS data. It handles most of the common data handling chores of
interest at the beamline or for preparing your data to begin
analysis. :demeter:`athena` is a graphical front end to Matt
Newville's :demeter:`ifeffit` library written entirely in the Perl
programming language and using the Gnuplot program for data
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
   :target: _images/athena_main.png
   :width: 65%
   :align: center

   The parts of the ATHENA.

At the top of the window is a menu bar. This works much like the menu
bar in any program. Much of the functionality in :demeter:`athena` is
accessed through those menus.

The largest part is the main window, highlighted in the picture above
with a red border. The red border does not happen in the real program --
it's there simply to clarify this discussion. The main window is divided
into six parts. The top box identifies the file name of the current
`project file <output/project.html>`__. Below that, are various
parameters identifying the current data group.

The next three boxes are used to define the parameters associated with
normalization and background removal, forward Fourier transforms, and
reverse Fourier transforms. At the bottom of the main window are a
couple of parameters associated with plotting.

At the bottom of the screen is the echo area. This very important space
is used by :demeter:`athena` to communicate with you, the user. This space is used
to display informational messages while :demeter:`athena` is working on your data,
error messages when it runs into trouble, and other kinds of messages.

The large blank area on the right is `the group list
area <ui/glist.html>`__. As data are imported into :demeter:`athena`, they will be
listed in this space. Access to the data already imported is made by
clicking in this space.

Above the group list area are `the mark buttons <ui/mark.html>`__ The
blank space next to the mark buttons is the modified project indicator.
This indicator shows when your project has been modified and needs to be
saved.

Below the group list area are the plot buttons. Below that are the
buttons used to set the k-weighting for use when plotting in k-space or
when making a forward Fourier transform. Below that are various other
`plotting controls <ui/mark.html>`__ in the plotting options section.

.. _fig-athenawithdata:

.. figure:: ../_images/athena_withdata.png
   :target: _images/athena_withdata.png
   :width: 65%
   :align: center

   Athena, after importing some data.

After importing several data files, each is made into a *data group* and
listed in the group list. The label and the check button next to it are
the main controls for interacting with data in :demeter:`athena`.


Getting help
------------

There is quite a bit of help built right into
:demeter:`athena`. Typing :kbd:`Control`-:kbd:`m` or selecting
:title:`Document` from the Help menu will display :demeter:`athena`'s
document in a web browser or in the built-in document viewer. The
:title:`Document sections` submenu allows you to jump directly to a
particular topic. Also, many parts of the program have a button which
will take you directly to the part of the document that describes that
part of the program.



Folders and log files
---------------------

On occasion, it is helpful to know something about how :demeter:`athena` writes
information to disk during its operations.

**working folder**
    Many of :demeter:`athena`'s chores involve writing temporary files. Many file
    type plugins write temporary files after performing some
    transformation on the original data. GNUPLOT writes temporary
    files as part of its plot creation. These files are stored in the
    :title:`stash folder`. On linux (and other unixes) this is
    ``$HOME/.horae/stash/``. On Windows this is
    ``%APPDATA%\\demeter\\stash``.

**log files**
    When :demeter:`athena` runs into problems, it attempts to write enough
    information to the screen that the problem can be addressed. This
    screen information is what Bruce needs to troubleshoot bugs. On a
    linux (or other unix) machine, simply run :demeter:`athena` from the command
    line and the informative screen messages will be written to the
    screen. You can cut-n-paste that text or capture the output by
    running :demeter:`athena` through
    `tee <http://www.gnu.org/software/coreutils/manual/html_node/tee-invocation.html>`__:
    ``~> dathena | tee capture.log``
    On a Windows machine, it is uncommon to run the software from the
    command line, so :demeter:`athena` has been instrumented to write a run-time
    log file. This log file is called dathena.log and can be found in
    the ``%APPDATA%\\demeter`` folder.

``%APPDATA% is C:\\Users\\<username>\\AppDataRoaming\\`` on Windows 7 and 8.

It is ``C:\\Documents and Settings\\<username>\\Application Data\\`` on
Windows XP and Vista.

In either case, ``<username>`` is your log-in name.

