..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Data summation
==============

This tool is used to make arbitrary sumations of data.
This is a little bit like the `linear combination
fitting <../analysis/lcf.html>`__ tool and a little bit like the
`difference spectrum <../analysis/diff.html>`__ tool, but different.
This tool allows you to make an arbitrary summation of |mu| (E), normalized
|mu| (E), or |chi| (k) data. There is no requirement that the specified weights
be positive or sum to one.

Plots can optionally include the scaled components or the marked groups
from the group list. If the summation is made on |chi| (k) data, the button
for plotting as |chi| (R) will be enabled.

A group can be made from the summation and inserted into the group list.
That new group will be treated like normal data.

.. _fig-summer:

.. figure:: ../../_images/sum.png
   :target: ../_images/sum.png
   :width: 65%
   :align: center

   The data summation tool.

.. _fig-summerplot:

.. figure:: ../../_images/sum_plot.png
   :target: ../_images/sum_plot.png
   :width: 45%
   :align: center

   A plot containing an arbitrary sum of three standards. Included in the
   plot is the marked group from the group list and the three standards
   scaled by the specified weight.

