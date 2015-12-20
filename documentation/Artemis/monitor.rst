`The Artemis Users' Guide <./index.html>`__

+--------------------------------------+--------------------------------------+
| «\ `DEMETER <http://bruceravel.githu |
| b.io/demeter/>`__\ »                 |
|                                      |
| «\ `IFEFFIT <https://github.com/newv |
| ille/ifeffit>`__\ »                  |
|                                      |
| «\ `xafs.org <http://xafs.org>`__\ » |
|                                      |
| Back: `The History                   |
| window <./history.html>`__           |
| Next: `Managing                      |
| preferences <./prefs.html>`__        |
+--------------------------------------+--------------------------------------+

| |[Artemis logo]|
|  `Home <./index.html>`__
|  `Introduction <./intro.html>`__
|  `Starting Artemis <./startup/index.html>`__
|  `The Data window <./data.html>`__
|  `The Atoms/Feff window <./feff/index.html>`__
|  `The Path page <./path/index.html>`__
|  `The GDS window <./gds.html>`__
|  `Running a fit <./fit/index.html>`__
|  `The Plot window <./plot/index.html>`__
|  `The Log & Journal windows <./logjournal.html>`__
|  `The History window <./history.html>`__
|  Monitoring things
|  `Managing preferences <./prefs.html>`__
|  `Worked examples <./examples/index.html>`__
|  `Crystallography for EXAFS <./atoms/index.html>`__
|  `Extended topics <./extended/index.html>`__

Monitoring things
=================

ARTEMIS provides a number of tools for keeping track of things going on
behind the scenes. These tools are found either in the Monitor menu on
the Main window or the Debug menu on the Data window.

In the normal course of operations, consulting the monitoring tools
should not be necessary. But if something is not working quite right,
they can be invaluable for diagnosing the problem.

--------------

 

Command and status buffers
--------------------------

--------------

 

The Command buffer
~~~~~~~~~~~~~~~~~~

|command\_buffer.png| The command buffer window contains a record of
every data processing and fitting command sent to IFEFFIT. At the bottom
of this window is the plotting buffer, which contains every command sent
to the plotting backend (usually Gnuplot).

These are very useful both for diagnosing problems and for learning the
details of how IFEFFIT and Gnuplot work.

At the bottom of the window is a simple command line for sending
instructions directly to IFEFFIT.

--------------

 

The Status buffer
~~~~~~~~~~~~~~~~~

|status\_buffer.png| Every message sent to any of the status bars in
ARTEMIS is time-stamped and logged in the status buffer. This provides a
sort of record of the major actions taken during your current ARTEMIS
session. The contents of this buffer can be saved to a file.

--------------

 

Interacting with Ifeffit
------------------------

|show\_arrays.png| One of the submenus in the Monitor menu on the Main
window allows you to examine IFEFFIT data structures. The results of
these examination commands are displayed in the command buffer. In this
example, all arrays currently defined in IFEFFIT have been shown.

Options exist for showing specific IFEFFIT data group, all arrays, all
scalars, all strings, all paths, or all FEFF paths. The last one is
simply a listing all feffNNNN.dat files imported into IFEFFIT.

You can also inquire about how much of IFEFFIT's statically allocated
memory is in use and whether you are in danger of exceeding capacity.
This information is displayed in the Main window status bar.

--------------

 

Debugging Demeter
-----------------

Several additional menu items are turned on when ♦Artemis → debug\_menus
is set to a true value. The items in these menus provide tools for
debugging ARTEMIS by showing the current state of DEMETER and its data
structures. These tools are invaluable for developing the software, but
are probably of limited value to the general user.

| 

--------------

--------------

| DEMETER is copyright © 2009-2015 Bruce Ravel — This document is
copyright © 2015 Bruce Ravel

|image4|    

| This document is licensed under `The Creative Commons
Attribution-ShareAlike
License <http://creativecommons.org/licenses/by-sa/3.0/>`__.
|  If DEMETER and this document are useful to you, please consider
`supporting The Creative
Commons <http://creativecommons.org/support/>`__.

.. |[Artemis logo]| image:: ./../images/Artemis_logo.jpg
   :target: ./diana.html
.. |command\_buffer.png| image:: ../images/command_buffer.png
   :target: ../images/command_buffer.png
.. |status\_buffer.png| image:: ../images/status_buffer.png
   :target: ../images/status_buffer.png
.. |show\_arrays.png| image:: ../images/show_arrays.png
   :target: ../images/show_arrays.png
.. |image4| image:: ../images/somerights20.png
   :target: http://creativecommons.org/licenses/by-sa/3.0/
