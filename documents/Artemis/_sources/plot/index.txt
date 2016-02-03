..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. |transfer button| image:: ../../_static/plot-icon.png

Plotting data
=============

.. plotlist::

You have `already been introduced <../startup/plot.html>`__ to the
basic functionality of the Plot window. In this chapter, all the
details of :demeter:`artemis`' plotting system will be
explained. While :demeter:`artemis` does not provide all the plotting
capabilities offered by real plotting tools like Gnuplot, Origin,
Excel, Kaleidagraph, and others, it does provide enough options to
create interesting and instructive visualization of your EXAFS fitting
project.

Let's briefly go over the basic features of the Plot window. The buttons
at the top are used to make plots of data and paths in one of the three
spaces. The data listed in the plotting list at the bottom of the Plot
window will be included in the plots made with those three buttons.

The part of the complex |chi| (R) or |chi| (q) functions is controled
by the two sets of radiobuttons at the top of the :guilabel:`limits`
tab. Additional traces |nd| the fit, the window, and so on – can be
included by clicking on their check buttons. Finally, the plotting
range along the x-axis can be set for each of the three spaces. At the
top of the Plot window are a series of radio buttons used to set the
k-weighting used in plots. A plot of |chi| (k) will be weighted by the
specified factor of k. Plots of |chi| (R) or |chi| (q) will use that
valule of k-weighting for the forward Fourier transform.

The :guilabel:`kw` option for k-weighting will use the user-specified
value of k-weight for each data set included in the plot. That value
will also be used for any paths associated with that data set.

Please note that the value of k-weight selected for plotting has no
bearing on how the fit is performed. The k-weighting specified on the
Data window is used to evaluate the fit. Fit evaluation and
visualization are different tasks, each with their own value of
k-weight.


-------------------

.. toctree::
   :maxdepth: 2

   plotlist.rst
   stack.rst
   indic.rst
   vpaths.rst


