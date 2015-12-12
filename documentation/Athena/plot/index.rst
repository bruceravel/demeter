
Plotting Your Data in Athena
============================

Two of the main design goals of :demeter:`athena` are to make basic data
processing, i.e. background removal and Fourier transforms, as
transparent as possible and to make processing of large amounts of data
as seamless as processing a single data group. To this end, there are no
buttons or other kinds of controls that explicitly tell :demeter:`athena` to
perform the basic processing chores. Instead, there are the plot
buttons. When you click one of the plot buttons, the data processing
which is required will be performed before the plot is made. For
example, if you press the R button, the background will be removed from
the current group and the |chi| (k) will be Fourier transformed to |chi| (R). Once
all that is finished, the plot in R-space will be made.

As you change the values of the parameters in the main window, :demeter:`athena`
keeps track of what has been changed and which data processing steps
need to be redone. If you change the :procparam:`krange` parameters, then press the
R button again, the Fourier transform will be updated, but :demeter:`athena` will
recognize that the background removal is still up-to-date.

.. todo:: Write document page for title, legends, single file tab.

.. todo:: display of orange an purple buttons
	  

**Plotting the current group**

The row of orange buttons are used to plot the current group. The
current group is the one highlighted in the group list and the one
whose parameter values are displayed in the main window. The controls
used to determine how the plots are displayed are described in `the
next section <../plot/tabs.html>`__.

#. Clicking the E button brings the background removal up to date and
   plots the |mu| (E) data.

#. Clicking the k button brings the background removal up to date and
   plots the |chi| (k) data.

#. Clicking the R button brings the background removal and Fourier
   transform up to date and plots the |chi| (R) data.

#. Clicking the q button brings the background removal, Fourier
   transform, and backwards transform up to date and plots the |chi| (q)
   data.

#. Clicking the kq button brings the background removal, Fourier
   transform, and backwards transform up to date and plots the |chi| (k) data
   along with the real part of the |chi| (q) data.


**Plotting many groups**

The row of purple buttons are used to plot the set of marked groups. The
marked groups are the ones with their purple button checked in the group
list. More details about the marking groups are found `elsewhere in this
document <../ui/mark.html>`__. The controls used to determine how the
plots are displayed are described in `the next
section <../plot/tabs.html>`__.

#. Clicking the E button brings the background removal up to date for
   all marked groups and plots their |mu| (E) data.

#. Clicking the k button brings the background removal up to date for
   all marked groups and plots their |chi| (k) data.

#. Clicking the R button brings the background removal and Fourier
   transform up to date for all marked groups and plots their |chi| (R) data.

#. Clicking the q button brings the background removal, Fourier
   transform, and backwards transform up to date for all marked groups
   and plots their |chi| (q) data.


**Right clicking on plot buttons**

Several of the plot buttons will respond to a right click by making one
of `the special
plots <../plot/etc.html#specialplotsforthecurrentgroup>`__ from the Plot
menu.

- Right click the E button button: plot |mu| (E) with I\ :sub:`0` and
  the signal.

- Right click the k button button: display the k123 plot.

- Right click the R button button: display the R123 plot.

- Right click the kq button button: display the quad plot.

- Right click the E button button: plot I\ :sub:`0` for each marked group.

All other plot keys respond normally when right-clicked.

The responses of the E button and the E button can be configured with
the :configparam:`Athena,right\_single\_e` and
:configparam:`Athena,right\_marked\_e` `configuration parameters
<../other/prefs.html>`__.

.. toctree::
   :maxdepth: 2

   tabs
   krange
   stack
   indic
   params
   etc
