..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Calibrating data groups
=======================

Data calibration is the process of selecting a point in your data as
the edge energy and applying an energy shift to your measured data so
that the selected point is at a specified value. Thus, it is intended
to put your data onto an absolute energy grid.  For metals, that
value is usually the tabulated edge energy.

.. _fig-calibrate:
.. figure:: ../../_images/calibrate.png
   :target: ../_images/calibrate.png
   :align: center

   This is the calibration tool.

When this tool above starts, the current group is plotted as the
derivative of |mu| (E). The menu allows you plot the data as |mu| (E),
normalized |mu| (E), derivative of |mu| (E), or second derivative of
|mu| (E). If your data are noisy, you may find it helpful to apply
smoothing.  :demeter:`ifeffit`'s simple three-point smoothing
algorithm is applied the number of times indicated, then the data are
replotted.

The selected point is shown in the plot with the orange circle, as
shown in the plot below. You can type in a new value in the
:guilabel:`Reference` box or click the :button:`Select a point,light`
button then click on a point in the plot. By default, the
:guilabel:`Calibrate to` box contains the tabulated edge energy of the
absorber measured for these data, but that too can be edited.

.. _fig-calplot:
.. figure:: ../../_images/calibrate_plot.png
   :target: ../_images/calibrate_plot.png
   :align: center

   As you work on calibrating your data, the current reference point is
   indicated by a small orange circle.

When you plot the second derivative, the :button:`Find zero
crossing,light` button becomes enabled. This finds the zero crossing
of the second derivative that is nearest to the current value of the
reference point. When plotting the second derivative, smoothing helps,
even for fairly clean data.

When you click the :button:`Calibrate,light` button, the values of
:procparam:`E0` and :procparam:`Energy shift` are set for the current
group such that the selected point in the data takes the calibration
value.
