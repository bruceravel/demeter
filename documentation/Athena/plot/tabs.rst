..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Plotting space tabs
===================


Plotting in energy
------------------

The appearance of the plots made in E-, k-, R-, or q-space are
controlled by the contents of the plot options tabs in the lower right
hand corner of :demeter:`athena`. This is highlighted in the following figure.

In energy, you have the option of plotting |mu| (E) normalized or not and
derivative or not. The orange buttons on the left control how the current
group is plotted. The purple buttons on the right control how marked
groups are plotted. For the current group, you also have the option of
plotting the background function, the pre-edge line, or the post-edge
polynomial. As discussed in `the normalization
section <../bkg/norm.html>`__, it is very helpful to examine the pre-
and post-edge lines to verify that data normalization is done correctly.

.. _fig-etab:

.. figure:: ../../_images/plot_etab.png
   :target: ../_images/plot_etab.png
   :width: 65%
   :align: center

   The plot options section with the energy tab showing.

The two text entry boxes at the bottom of the tab are used to
determine the extent of the data range plotted on the x-axis. Both
those these numbers are relative to :procparam:`e0`. The :configparam:`Plot,emin`
and :configparam:`Plot,emax` preferences can be used to set the
default plot range. See also the `plot styles section
<../ui/styles.html>`__.

Plotting in k-space
-------------------

The plot of |chi| (k) is mostly determined by the value of the `plotting
k-weight buttons <../ui/kweight.html>`__. The only option on the k-space
tab is to make the plot as k-weighted |chi| (E) rather than |chi| (k). For the
|chi| (E) plot, the k-axis is translated to absolute energy using the value
of :procparam:`e0`.


.. _fig-ktab:

.. figure:: ../../_images/plot_ktab.png
   :target: ../_images/plot_ktab.png
   :width: 30%
   :align: center

   The k tab.

If the window button is checked, the windowing function used to make the
forward Fourier transform will be plotted along with the plot for the
current group.

The two text entry boxes at the bottom of the tab are used to
determine the extent of the data range plotted on the x-axis. Although
either number can be a negative value, there is no data below k=0. The
:configparam:`Plot,kmin` and :configparam:`Plot,kmax` preferences can
be used to set the default plot range. See also the `plot styles
section <../ui/styles.html>`__.


Plotting in R-space
-------------------

.. _fig-rtab:

.. figure:: ../../_images/plot_rtab.png
   :target: ../_images/plot_rtab.png
   :width: 30%
   :align: center

   The R tab.

The plot of |chi| (R) is determined in part by the value of the `plotting
k-weight buttons <../ui/kweight.html>`__. The options in the tab tell
:demeter:`athena` which part of the complex |chi| (R) to plot. For the current group,
the parts are inclusive. Each selected part is plot.

For the current group, you also have the option of plotting the
envelope, which is the magnitude plotted in the same color as the
negative magnitude. Selecting the envelope deselects the magnitude and
vice versa. For marked groups, the parts are plotted exclusively and the
envelope is not available.

The two text entry boxes at the bottom of the tab are used to determine
the extent of the data range plotted on the x-axis, behave much like the
same boxes on the k tab, and have similar preferences.

When the :guilabel:`phase correction` button is clicked on, the Fourier transform
for that data group will be made by subtracting the central atom phase
shift. This is an incomplete phase correction – in :demeter:`athena` we know the
central atom but do not necessarily have any knowledge about the
scattering atom.

Note that, when making a phase corrected plot, the window function in R
is not corrected in any way, thus the window will not line up with the
central atom phase corrected |chi| (R).


Plotting in q-space
-------------------

The letter *q* is used to denote wavenumber of the filtered |chi| (k)
function and to avoid confusion with unfiltered k-space. The units of
``q`` are inverse Angstroms, just as for ``k``.

.. _fig-qtab:

.. figure:: ../../_images/plot_qtab.png
   :target: ../_images/plot_qtab.png
   :width: 30%
   :align: center

   The q tab.

The plot of |chi| (q) is determined in part by the value of the
`plotting k-weight buttons <../ui/kweight.html>`__. The options in the
tab tell :demeter:`athena` which part of the complex |chi| (q) to
plot. For the current group, the parts are inclusive. Each selected
part is plot.

For the current group, you also have the option of plotting the
envelope, which is the magnitude plotted in the same color as the
negative magnitude. Selecting the envelope deselects the magnitude and
vice versa. For marked groups, the parts are plotted exclusively and the
envelope is not available.

If the window button is checked, the windowing function used to make the
forward Fourier transform will be plotted along with the plot for the
current group.

The two text entry boxes at the bottom of the tab are used to determine
the extent of the data range plotted on the x-axis, behave much like the
same boxes on the k tab, and have similar preferences.

