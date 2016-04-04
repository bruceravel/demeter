..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Plotting Your Data
==================


Two of the main design goals of :demeter:`athena` are to make basic
data processing, i.e. background removal and Fourier transforms, as
transparent as possible and to make processing of large amounts of
data as seamless as processing a single data group. To this end, there
are no buttons or other kinds of controls that explicitly tell
:demeter:`athena` to perform the basic processing chores. Instead,
there are the plot buttons. When you click one of the plot buttons,
the data processing which is required will be performed before the
plot is made. For example, if you press the :button:`R,orange` button,
the background will be removed from the current group and the
|chi| (k) will be Fourier transformed to |chi| (R). Once all that is
finished, the plot in R-space will be made.

As you change the values of the parameters in the main window,
:demeter:`athena` keeps track of what has been changed and which data
processing steps need to be redone. If you change the
:procparam:`krange` parameters, then press the :button:`R,orange` button
again, the Fourier transform will be updated, but :demeter:`athena`
will recognize that the background removal is still up-to-date.


**Plotting the current group**

The row of orange buttons are used to plot the current group. The
current group is the one highlighted in the group list and the one
whose parameter values are displayed in the main window. The controls
used to determine how the plots are displayed are described in `the
next section <../plot/tabs.html>`__.

#. Clicking :mark:`leftclick,..` the :button:`E,orange` button brings the background removal
   up to date and plots the |mu| (E) data

#. Clicking :mark:`leftclick,..` the :button:`k,orange` button brings the background removal
   up to date and plots the |chi| (k) data

#. Clicking :mark:`leftclick,..` the :button:`R,orange` button brings the background removal
   and Fourier transform up to date and plots the |chi| (R) data

#. Clicking :mark:`leftclick,..` the :button:`q,orange` button brings the background removal,
   Fourier transform, and backwards transform up to date and plots the
   |chi| (q) data

#. Clicking :mark:`leftclick,..` the :button:`kq,orange` button brings the background removal,
   Fourier transform, and backwards transform up to date and plots the
   |chi| (k) data along with the real part of the |chi| (q) data


**Plotting many groups**

The row of purple buttons are used to plot the set of marked
groups. The marked groups are the ones with their purple button
checked in the group list. More details about the marking groups are
found `elsewhere in this document <../ui/mark.html>`__. The controls
used to determine how the plots are displayed are described in `the
next section <../plot/tabs.html>`__.

#. Clicking :mark:`leftclick,..` the :button:`E,purple` button brings the background removal
   up to date for all marked groups and plots their |mu| (E) data

#. Clicking :mark:`leftclick,..` the :button:`k,purple` button brings the background removal
   up to date for all marked groups and plots their |chi| (k) data

#. Clicking :mark:`leftclick,..` the :button:`R,purple` button brings the background removal
   and Fourier transform up to date for all marked groups and plots
   their |chi| (R) data

#. Clicking :mark:`leftclick,..` the :button:`q,purple` button brings the background removal,
   Fourier transform, and backwards transform up to date for all
   marked groups and plots their |chi| (q) data


**Right clicking on plot buttons**

Several of the plot buttons will respond to a right click by making
one of `the special plots <../plot/etc.html>`__ from the
:guilabel:`Plot` menu.

- Right click :mark:`rightclick,..` the :button:`E,orange` button: plot |mu| (E) with I\
  :sub:`0` and the signal

- Right click :mark:`rightclick,..` the :button:`k,orange` button: display the k123 plot

- Right click :mark:`rightclick,..` the :button:`R,orange` button: display the R123 plot

- Right click :mark:`rightclick,..` the :button:`kq,orange` button: display the quad plot

- Right click :mark:`rightclick,..` the :button:`E,purple` button: plot I\ :sub:`0` for each
  marked group

- Right click :mark:`rightclick,..` the :button:`q,purple` button: display the bi-quad plot

All other plot keys respond to a right-click :mark:`rightclick,..` in the same way as a
left-click :mark:`leftclick,..`.

The responses of the :button:`E,orange` button and the :button:`E,purple`
button can be configured with the
:configparam:`Athena,right\_single\_e` and
:configparam:`Athena,right\_marked\_e` `configuration parameters
<../other/prefs.html>`__.


----------------

.. toctree::
   :maxdepth: 2

   tabs
   krange
   other
   params
   etc
