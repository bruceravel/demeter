..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. _splinerange_sec:

Spline range in background removal
==================================

Two parameters that can have a big effect on the quality of the
background removal are the limits of the spline range. By default, the
spline used to approximate the background function is computed between
0.5 |AA|\ :sup:`-1` and the end of the data range. (Those defaults can
be set with the :configparam:`Bkg,spl1` and :configparam:`Bkg,spl2`
preferences.)  In the main menu, there are entry boxes for the values
of the spline range in k and in energy.  You can edit those
interchangeably, when one pair is changed, the other pair is
updated. The same is true if you use `the pluck buttons
<ui/pluck.html>`__ to set their values.

There are good reasons to try changing the lower or upper bounds of
the spline range. In the case of data with a large, sharp white line,
the :demeter:`autobk` algorithm might have a hard time following that
swiftly changing part of |mu| (E). The background removal might be
improved by starting the spline range at a higher value. A good way to
test the effect of spline range is to make a copy
(:button:`Alt`-:button:`y`) of the data group, change the lower spline
boundary to a large value for the copy, and plot both groups as
|chi| (k) or |chi| (R) using the :button:`k,purple` button or the
:button:`R,purple` button.

Changing the upper bound of the spline range is often helpful in data
where the signal becomes very small at high k such that the level of
greatly exceeds the |chi| (k) data when k-weighted or if the shape of the
background function is unstable due to sample inhomogeneity or some
other measurement problem.

This shows an example of a change in the upper bound of the spline
range.

.. _fig-bkg_splinerange:

.. figure:: ../../_images/bkg_splinerange.png
   :target: ../_images/bkg_splinerange.png
   :width: 45%
   :align: center

   Gold foil data showing the effect of changing the upper end of the
   spline range.

The obvious effect of changing the spline range is that |chi| (k) is 0
outside the spline range, as seen on the high-k end of the plot.
Changing one end of the spline range can also have an effect on the
opposite end of the spectrum. This can be seen on the low-k end of the
spectrum in the plot.

When you are working on data for which a good background removal is
difficult, changing the spline range is one of the tricks you can pull
out of your tool box.

