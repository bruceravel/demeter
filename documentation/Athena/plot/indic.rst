
Indicators
==========

Indicators are vertical lines drawn from the top to the bottom of the
plot frame. They are used to draw attention to specific points in plots
of your data. This can be useful for comparing specific features in
different data sets or for seeing how a particular feature propagates
from energy to k to q.

Points to mark by indicators are chosen using `the pluck
buttons <ui/pluck.html>`__ in the indicators tab. Click on the pluck
button then on a spot in the plot. That value will be inserted into the
adjacent text entry box. When the :quoted:`Display indicators` button is
selected, the indicator lines will be plotted (if possible) in each
subsequent plot.

Points selected in energy, k, or q are plotted in any of those spaces.
Points selected in R can only be plotted in R. Points outside the plot
range are ignored.

.. subfigstart::

.. _fig-indictab:

.. figure::  ../../_images/plot_indic.png
   :target: ../_images/plot_indic.png
   :width: 50%

.. _fig-indicplot:

.. figure::  ../../_images/plot_indicplot.png
   :target: ../_images/plot_indicplot.png
   :width: 100%


.. subfigend::
   :width: 0.45
   :label: _fig-indic

   (Left) The indicator tab. (Right) An example of a plot with indicators.
   Note that plots made in E, k, or q will plot indicators selected in any
   of those three spaces.

The following `preferences <../other/prefs.html>`__ can be set to
customize the appearance of the indicators.

#. :configparam:`Plot,nindicators`: the maximum number of indicators that can be set

#. :configparam:`Plot,indicatorcolor`: the color of the indicator line

#. :configparam:`Plot,indicatorline`: the line type of the indicator

