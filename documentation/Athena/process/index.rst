..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Data processing
===============


:demeter:`ATHENA` offers a variety of data processing chores |nd| chores
which modify the data or its parameters in some way to prepare it for
more extensive analysis. With the exception of merging data groups,
all data processing features are accesses through the main menu, shown
below. All these entries in the main menu, replace the main window
with a tool specially designed for the data processing chore.

You can work on more than one data group in any tool without having to
return to the main menu. Clicking on a group label in the group list
will make that group current, display parameters appropriate to the data
processing tool, sometimes plotting the data in some appropriate manner.

When you are finished using the data processing tool, you can press
the button labeled :button:`Return to the main window,light`. Doing so
will close the special tool and redisplay the main window.

.. _fig-process:
.. figure:: ../../_images/process.png
   :target: ../_images/process.png
   :align: center

   The main menu is used to access almost all data processing
   functionality.


----------------

.. toctree::
   :maxdepth: 2

   cal
   align
   merge
   rebin
   deg
   smooth
   conv
   deconv
   sa
   pixel
   mee
   series
   sum
