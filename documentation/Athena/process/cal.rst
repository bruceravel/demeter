
Calibrating data groups
=======================

Putting data on an absolute energy grid
---------------------------------------

Data calibration is the process of selecting a point in your data as the
edge energy and applying an energy shift to your measured data so that
the selected point is at a specified value. For metals, that value is
usually the tabulated edge energy.

.. _fig-calibrate:

.. figure:: ../../_images/calibrate.png
   :target: ../../_images/calibrate.png
   :width: 65%
   :align: center

   This is the calibration tool.

When this tool above starts, the current group is plotted as the
derivative of |mu| (E). The menu allows you plot the data as |mu| (E),
normalized |mu| (E), derivative of |mu| (E), or second derivative of
|mu| (E). If your data are noisy, you may find it helpful to apply
smoothing.  :demeter:`ifeffit`'s simple three-point smoothing
algorithm is applied the number of times indicated, then the data are
replotted.

The selected point is shown in the plot with the orange circle, as shown
in the plot below. You can type in a new value in the :quoted:`Reference` box or
click the :quoted:`Select a point` button then click on a point in the plot. By
default, the :quoted:`Calibrate to` box contains the tabulated edge energy of
the absorber measured for these data, but that too can be edited.

.. _fig-calplot:

.. figure:: ../../_images/calibrate_plot.png
   :target: ../../_images/calibrate_plot.png
   :width: 45%
   :align: center

   As you work on calibrating your data, the current reference point is
   indicated by a small orange circle.

When you plot the second derivative, the :quoted:`Find zero crossing` button
becomes enabled. This finds the zero crossing of the second derivative
that is nearest to the current value of the reference point. When
plotting the second derivative, smoothing helps, even for fairly clean
data.

When you click the :quoted:`Calibrate` button, the values of :procparam:`E0`
and :procparam:`Energy shift` are set for the current group such that
the selected point in the data takes the calibration value.
