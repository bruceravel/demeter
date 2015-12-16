
Stacked plots
=============

When marked group plots are made using the purple plot buttons, the
default behavior is to overplot the various data groups. At times, it
might be preferable to place an offset between the plots. This is done
in general by setting the :procparam:`y-axis offset`
parameter. Stacking plots in a systematic manner is done using the
stack tab. Stacking is done by setting the :procparam:`y-axis offset` parameters
of the marked groups sequentially.

This tab contains two text entry boxes. The first is used to set the
:procparam:`y-axis offset` parameter of the first marked group. Subsequent marked
groups have their :procparam:`y-axis offset` parameters incremented by the amount
of the second text entry box. Clicking the :kbd:`Apply to marked,light` button
sets these values for each marked group.

.. subfigstart::

.. _fig-stacktab:

.. figure::  ../../_images/plot_stack.png
   :target: ../_images/plot_stack.png
   :width: 50%

   The plot stacking tab.

.. _fig-stacked:

.. figure::  ../../_images/plot_stacked.png
   :target: ../_images/plot_stacked.png
   :width: 100%

   An example of a stacked plot. Note that the stacking increment is
   negative so that that order of the colors is the same in the legend
   as in the plot.

.. subfigend::
   :width: 0.45
   :label: _fig-stack


