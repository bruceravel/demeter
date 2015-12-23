..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Monitoring things
=================

:demeter:`artemis` provides a number of tools for keeping track of
things going on behind the scenes. These tools are found either in the
Monitor menu on the Main window or the Debug menu on the Data window.

In the normal course of operations, consulting the monitoring tools
should not be necessary. But if something is not working quite right,
they can be invaluable for diagnosing the problem.


The Command buffer
------------------

The command buffer window contains a record of every data processing
and fitting command sent to :demeter:`ifeffit`. At the bottom of this
window is the plotting buffer, which contains every command sent to
the plotting backend (usually :program:`Gnuplot`).

These are very useful both for diagnosing problems and for learning
the details of how :demeter:`ifeffit` and :program:`Gnuplot` work.

.. _fig-commandbuffer:
.. figure:: ../_images/command_buffer.png
   :target: _images/command_buffer.png
   :align: center

   The command buffer window



At the bottom of the window is a simple command line for sending
instructions directly to :demeter:`ifeffit`.


The Status buffer
-----------------

Every message sent to any of the status bars in :demeter:`artemis` is
time-stamped and logged in the status buffer. This provides a sort of
record of the major actions taken during your current
:demeter:`artemis` session. The contents of this buffer can be saved
to a file.

.. _fig-statusbuffer:
.. figure:: ../_images/status_buffer.png
   :target: _images/status_buffer.png
   :align: center

   The status buffer window


Interacting with Ifeffit
------------------------

One of the submenus in the Monitor menu on the Main window allows you
to examine :demeter:`ifeffit` data structures. The results of these
examination commands are displayed in the command buffer. In this
example, all arrays currently defined in :demeter:`ifeffit` have been
shown.

.. _fig-showarrays:
.. figure:: ../_images/show_arrays.png
   :target: _images/show_arrays.png
   :align: center

   Showing Ifeffit arrays


Options exist for showing specific :demeter:`ifeffit` data group, all
arrays, all scalars, all strings, all paths, or all :demeter:`feff`
paths. The last one is simply a listing all :file:`feffNNNN.dat` files
imported into :demeter:`ifeffit`.

You can also inquire about how much of :demeter:`ifeffit`'s
statically allocated memory is in use and whether you are in danger of
exceeding capacity.  This information is displayed in the Main window
status bar.


Debugging Demeter
-----------------

Several additional menu items are turned on when
:configparam:`Artemis,debug_menus` is set to a true value. The items
in these menus provide tools for debugging :demeter:`artemis` by
showing the current state of :demeter:`demeter` and its data
structures. These tools are invaluable for developing the software,
but are probably of limited value to the general user.

