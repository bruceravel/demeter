..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. _normalization_sec:


Normalization
=============

Normalization is the process of regularizing your data with respect to
variations in sample preparation, sample thickness, absorber
concentration, detector and amplifier settings, and any other aspects
of the measurement. Normalized data can be directly compared,
regardless of the details of the experiment. Normalization of your
data is essential for comparison to theory. The scale of the |mu| (E)
and |chi| (k) spectra computed by :demeter:`feff` is chosen for
comparison to normalized data.

The relationship between |mu| (E) and |chi| (k) is:

   |mu| (E) = |mu|\ :sub:`0`\ (E) \* (1 + |chi| (E))

which means that

   |chi| (E) = (|mu| (E) - |mu|\ :sub:`0`\ (E)) / |mu|\ :sub:`0`\ (E)

The approximation of |mu|\ :sub:`0`\ (E) in an experimental spectrum is a topic `that
will be discussed shortly <rbkg.html>`__.

This equation is not, in fact, the equation that is commonly used to
extract |chi| (k) from the measured spectrum. The reason that equation is
problematic is the factor of |mu|\ :sub:`0`\ (E) in the denominator. In practice, one
cannot trust the |mu|\ :sub:`0`\ (E) to be sufficiently well behaved that it can be
used as a multiplicative factor. An example is shown below.

.. _fig-zerocross:
.. figure:: ../../_images/bkg_normzerocross.png
   :target: ../_images/bkg_normzerocross.png
   :align: center

   |mu| (E) data for gold hydroxide, which crosses the zero axis in the EXAFS
   region.

In the case of the gold spectrum, the detector setting were such that
the spectrum crosses the zero-axis. Dividing these spectra by |mu|\
:sub:`0`\ (E) would be a disaster as the division would invert the
phase of the extracted |chi| (k) data at the point of the
zero-crossing.

To address this problem, we typically avoid functional normalization and
instead perform an *edge step normalization*. The formula is

|chi| (E) = (|mu| (E) - |mu|\ :sub:`0` (E)) / |mu|\ :sub:`0`\ (E\ :sub:`0`)

The difference is the term in the denominator. |mu|\ :sub:`0`\ (E\
:sub:`0`) is the value of the background function evaluated at the
edge energy. This addresses the problem of a poorly behaved |mu|\
:sub:`0` (E) function, but introduces another issue. Because the true
|mu|\ :sub:`0` (E) function should have some energy dependence,
normalizing by |mu|\ :sub:`0`\ (E\ :sub:`0`) introduces an attenuation
into |chi| (k) that is roughly linear in energy. An attenuation that
is linear in energy is quadratic in wavenumber. Consequently, the edge
step normalization introduces an artificial |sigma|\ :sup:`2` term to
the |chi| (k) data that adds to whatever thermal and static |sigma|\
:sup:`2` may exist in the data.

This artificial |sigma|\ :sup:`2` term is typically quite small and
represents a much less severe problem than a misbehaving functional
normalization.



The normalization algorithm
---------------------------

The normalization of a spectrum is controlled by the value of the :procparam:`e0`,
:procparam:`pre-edge range`, and :procparam:`normalization range` parameters. These parameters
are highlighted in this screenshot.

.. _fig-normparams:
.. figure:: ../../_images/bkg_normparams.png
   :target: ../_images/bkg_normparams.png
   :align: center

   Selecting the normalization parameters in :demeter:`athena`.

The :procparam:`pre-edge range` and :procparam:`normalization range`
parameters define two regions of the data |nd| one before the edge and
one after the edge. A line is regressed to the data in the
:procparam:`pre-edge range` and a polynomial is regressed to the data
in the :procparam:`normalization range`. By default, a three-term
(quadratic) polynomial is used as the post-edge line, but its order
can be controlled using the :procparam:`normalization order`
parameter. Note that *all* of the data in the :procparam:`pre-edge
range` and in the :procparam:`normalization range` are used in the
regressions, thus the regressions are relatively insensitive to the
exact value of boundaries of those data ranges.

The criteria for good pre- and post-edge lines are a bit subjective. It
is very easy to see that the parameters are well chosen for these copper
foil data. Both lines on the left side of this figure obviously pass
through the middle of the data in their respective ranges.

.. subfigstart::

.. _fig-prepost:
.. figure::  ../../_images/bkg_prepost.png
   :target: ../_images/bkg_prepost.png
   :width: 100%

   Cu foil |mu| (E) with pre and post lines.

.. _fig-norm:
.. figure::  ../../_images/bkg_norm.png
   :target: ../_images/bkg_norm.png
   :width: 100%

   Normalized |mu| (E) data for a copper foil.

.. subfigend::
   :width: 0.45
   :label: _fig-normalization

Data can be plotted with the pre-edge and normalization lines using
controls in the `energy plot
tabs <../plot/tabs.html#plotting-in-energy>`__. It is a very good idea to
visually inspect the pre-edge and normalization lines for at least some
of your data to verify that your choice of normalization parameters is
reasonable.

When plotting the pre- and post-edge lines, the positions of the
:procparam:`pre-edge range`, and :procparam:`normalization range`
parameters are shown by the little orange markers. (The upper bound of
the :procparam:`normalization range` is off screen in the plot above of the
copper foil.)

The normalization constant, |mu|\ :sub:`0`\ (E\ :sub:`0`) is evaluated by extrapolating the
pre- and post-edge lines to :procparam:`e0` and subtracting the e0-crossing of the
pre-edge line from the e0-crossing of the post-edge line. This
difference is the value of the :procparam:`edge step` parameter.

The pre-edge line is extrapolated to all energies in the measurement
range of the data and subtracted from |mu| (E). This has the effect of
putting the pre-edge portion of the data on the y=0 axis. The pre-edge
subtracted data are then divided by |mu|\ :sub:`0`\ (E\ :sub:`0`). The
result is shown on the right side of the figure above.

.. versionadded:: 0.9.18, an option was added to the context menu
   attached to the :procparam:`edge step` label for approximating the
   error bar on the edge step.


The flattening algorithm
------------------------

For display of XANES data and certain kinds of analysis of |mu| (E) spectra,
:demeter:`athena` provides an additional bit of sugar. By default, the *flattened*
spectrum is plotted in energy rather than the normalized spectrum. In
the following plot, flattened data are shown along with a copy of the
data that has the flattening turned off.

.. _fig-flattened:
.. figure:: ../../_images/bkg_normvflat.png
   :target: ../_images/bkg_normvflat.png
   :align: center

   Comparing normalized (red) and flattened (blue) data using a Cu foil.

To display the flattened data, the difference in slope and quadrature
between the pre- and post-edge lines is subtracted from the data, but
only after :procparam:`e0`. This has the effect of pushing the oscillatory part of
the data up to the y=1 line. The flattened |mu| (E) data thus go from 0 to
1. Note that this is for display and has no impact whatsoever on the
extraction of |chi| (k) from the |mu| (E) spectrum.

This is a nice way of displaying XANES data as it removes many
differences in the shape of the post-edge region from the data.
Computing `difference spectra <../analysis/diff.html>`__ or `self
absorption corrections <../process/sa.html>`__, performing `linear
combination fitting <../analysis/lcf.html>`__ or `peak
fitting <../analysis/peak.html>`__, and many other chores often benefit
from using flattened data rather than simply normalized data.

This idea was swiped from
`SixPACK <http://www.sams-xrays.com/#!sixpack/rovht>`__.


Getting the post-edge right
---------------------------

It is important to always take care selecting the post-edge range.
Mistakes made in selecting the :procparam:`normalization range`
parameters can have a profound impact on the extracted |chi| (k)
data. Shown below is an extreme case of a poor choice of
:procparam:`normalization range` parameters. In this case, the upper
bound was chosen to be on the high energy side of a subsequent edge in
the spectrum. The resulting :procparam:`edge step` is very wrong and
the flattened data are highly distorted.


.. subfigstart::

.. _fig-postbad:
.. figure::  ../../_images/bkg_postbad.png
   :target: ../_images/bkg_postbad.png
   :width: 100%

   The post-edge line is chosen very poorly for this BaTiO\ :sub:`3`
   spectrum. The upper end of the normalization range is on the other side
   of the Ba L\ :sub:`III` edge.

.. _fig-normbad:
.. figure::  ../../_images/bkg_normbad.png
   :target: ../_images/bkg_normbad.png
   :width: 100%

   The poor choice of normalization range for BaTiO\ :sub:`3` results
   in very poorly normalized Ti K edge data.

.. subfigend::
   :width: 0.45
   :label: _fig-badnorm

The previous example is obviously an extreme case, but it illustrates
the need to examine the normalization parameters as you process your
data. In many cases, subtle mistakes in the choice of normalization
parameters can have an impact on how the XANES data are interpreted and
in how the |chi| (k) data are normalized.


.. subfigstart::

.. _fig-subtlepost1:
.. figure::  ../../_images/bkg_subtlepost.png
   :target: ../_images/bkg_subtlepost.png
   :width: 100%

   One choice of :procparam:`norm1`.

.. _fig-subtlepost2:
.. figure::  ../../_images/bkg_subtlepost2.png
   :target: ../_images/bkg_subtlepost2.png
   :width: 100%

   Another choice of :procparam:`norm1`.

.. _fig-subtlepost3:
.. figure::  ../../_images/bkg_subtlepost_compare.png
   :target: ../_images/bkg_subtlepost_compare.png
   :width: 100%

   Example of a subtle effect in how the post-edge line is chosen in a
   hydrated uranyl species.  This compared the flattened XANES data
   for different choices of post-edge line in a hydrated uranyl
   species.

.. subfigend::
   :width: 0.45
   :label: _fig-subtlepost

In this example, the different choice for the lower bound of the
normalization range (42 eV in one case, 125 eV in the other) has an
impact on the flattening of these uranium edge data data, which in
turn may have in impact in the evaluation of average valence in the
system.  The small difference in the :procparam:`edge step` will also
slightly attenuate |chi| (k).



Getting the pre-edge right
--------------------------

The choice of the :procparam:`pre-edge range` parameters is similarly
important and also requires visual inspection. A poor choice can
result in an incorrect value of the :procparam:`edge step` and in
distortions to the flattened data. In the following spectrum, we see
the presence of a small yttrium K-edge at 17038 eV which distorts the
pre-edge for a uranium L\ :sub:`III`-edge spectrum at 17166 eV as
shown in the figure below. In this case the :procparam:`pre-edge
range` should be chosen to be entirely above the yttrium K-edge
energy.

.. _fig-uy:
.. figure:: ../../_images/bkg_uy.png
   :target: ../_images/bkg_uy.png
   :align: center

   A sediment sample with both uranium and yttrium.


Measuring and normalizing XANES data
------------------------------------

If time and the demands of the experiment permit, it is always a good
idea to measure significant amounts of the pre- and post-edge regions.
About 150 volts in the pre-edge and at least 300 volts in the
post-edge is a good rule of thumb. With shorter regions, it may be
difficult to find normalization boundaries that provide good
normalization lines.  Without a good normalization, it can be
difficult to compare a XANES measurement quantitatively with other
measurements.

Reducing the :procparam:`normalization order` might help in the case
of limited post-edge range. When measuring XANES spectra in a step
scan, it is often a good idea to add several widely spaced steps to
the end of a scan to extend the :procparam:`normalization range`
without adding excessive time to scan.

