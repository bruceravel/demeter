..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Starting Artemis
================

The :demeter:`artemis` program is launched on Windows by
double-clicking the :demeter:`artemis` icon on the desk top, by
selecting ``artemis`` from the :demeter:`demeter` menu in the Start
Menu, or by typing :command:`dartemis` (with a :button:`d`) at the
command prompt. If you installed :demeter:`demeter` using the standard
installer package, you can also double click on an :demeter:`artemis`
project file (i.e. one with a :file:`.fpj` extension) to open it in
:demeter:`artemis`.

On a unix computer, :demeter:`artemis` is launched by typing
``dartemis`` in the shell. Depending on how :demeter:`demeter` was
installed on your computer, there may be some kind of application
launcher, such as a desktop icon, a panel or dashboard launcher, or an
entry in some kind of application menu.

.. todo:: Describe how this is done on a Mac once the Mac installer
	  exists....

Once started, :demeter:`artemis` displays two windows, as shown below.

.. _fig-artemisstartup:

.. figure:: ../../_images/startup.png
   :target: ../_images/startup.png
   :width: 100%

   The program, as it appears upon starting.  The :quoted:`main
   window` is the one accross the top of the screen.  The
   :quoted:`Plot window` is the skinny one on the left side.

Everything will certainly look a little different on your computer. This
and all other screenshots in this document were taken on an Ubuntu Linux
computer running KDE with custom window decorations. Although the
details of the appearance may differ, all functionality is the same on
all platforms. (You may not have a cool insect as the background image.
Your loss.)

The window across the top of your screen is the :quoted:`main
window`. It provides an overview of the state of the program and of
your fitting project. The window along the left side of the screen is
the :quoted:`Plot window`. It is used to control how certain plots of
your data, fits, paths, and other things are displayed.

The plot window can be hidden by clicking the :button:`Plot,light`
button on the left side of the main window. Clicking that button again
will make the plot window reappear in the same place on your screen.

The following two sections provide an overview of the functionality in
these two windows. We will return these many times throughout this
document.


Folders and log files
---------------------

On occasion, it is helpful to know something about how
:demeter:`artemis` writes information to disk during its operations.

**working folder**

    Many of :demeter:`artemis`' chores involve writing temporary
    files. Project files are unpacked in temporary
    folders. :program:`Gnuplot` writes temporary files as part of its
    plot creation. These files are stored in the :quoted:`stash
    folder`. On linux (and other unixes) this is
    :file:`~/.horae/stash/`.  On Windows this is
    :file:`%APPDATA%\\demeter\\stash`.

**log files**

    When :demeter:`artemis` runs into problems, it attempts to write
    enough information to the screen that the problem can be
    addressed. This screen information is what Bruce needs to
    troubleshoot bugs. On a linux (or other unix) machine, simply run
    :demeter:`artemis` from the command line and the informative
    screen messages will be written to the screen. On a Windows
    machine, it is uncommon to run the software from the command line,
    so :demeter:`artemis` has been instrumented to write a run-time
    log file. This log file is called dartemis.log and can be found in
    the :file:`%APPDATA%\\demeter` folder.

``%APPDATA%`` is :file:`C:\\Users\\<username>\\AppDataRoaming\\` on
Windows 7.

It is :file:`C:\\Documents and Settings\\<username>\\Application Data`
on Windows XP and Vista.

In either case, ``<username>`` is your log-in name.

-------------

.. toctree::
   :maxdepth: 2

   main.rst
   plot.rst

