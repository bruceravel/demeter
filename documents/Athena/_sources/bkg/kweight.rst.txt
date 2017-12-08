..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. _clamps_sec:


Spline clamps and k-weight in background removal
================================================

Spline clamps
-------------

One of the shortcomings of the use of piece-wise splines to approximate
the background function is that the ends of spline are somewhat
ill-defined by virtue of not having more data preceding or following. At
times, this can result in the end of the spline splaying up or down,
away from the |mu| (E) data. This results in significant distortion to |chi| (k)
data.

:demeter:`ifeffit` provides a tool called *spline clamps*. These work
by adding an additional term to the |chi|\ :sup:`2` metric used to fit
the spline to the |mu| (E) data. The difference between the spline and
the data is computed for the first and last five data points. This sum
of differences computed in energy is multiplied by a user-chosen
scaling factor and added to the |chi|\ :sup:`2`  computed from the R-range
below :procparam:`rbkg`. This has the effect of :quoted:`clamping` the
spline to the ends of the data range. In other words, we use the prior
knowledge that |mu|\ :sub:`0`\ (E) is a smooth function through the
oscillatory structure of |mu| (E) to put a restraint on the fit used
to determine |mu|\ :sub:`0`\ (E).

The user-selected multiplicative coefficient takes one of six
predefined values: :guilabel:`none`, :guilabel:`slight`,
:guilabel:`weak`, :guilabel:`medium`, :guilabel:`strong`, or
:guilabel:`rigid`. These have values of 0, 3, 6, 12, 24, and 96,
respectively and serve to set the strength of the clamp in the
evaluation of |chi|\ :sup:`2`.

.. subfigstart::

.. _fig-clamp_mu:

.. figure::  ../../_images/clamp_mu.png
   :target: ../_images/clamp_mu.png
   :width: 100%

   EuTiO\ :sub:`3` Ti K-edge data with the background subtracted using
   a :procparam:`kweight` of 1 and a high-end spline clamp of
   :guilabel:`none`. Note that the end of the spline deviates
   significantly from the end of the data.

.. _fig-clamp_chi:

.. figure::  ../../_images/clamp_chi.png
   :target: ../_images/clamp_chi.png
   :width: 100%

   Comparing the effects of different values of the high-end spline
   clamp on the EuTiO\ :sub:`3` data with all other parameters
   equal. The data using the :guilabel:`rigid` clamp show the most
   physically reasonable behavior at the end of the data range.

.. subfigend::
   :width: 0.45
   :label: _fig-clamp


The default value of the clamp is :guilabel:`none` at the low end of the energy
range and :guilabel:`strong` at the high end. Clamps tend not to help at the low
energy end of the data. Since the |mu| (E) data is changing so quickly near
the edge, biasing the spline to follow the data closely rarely helps
improve the quality of the |chi| (k) data. A strong clamp at the high energy
frequently improves the behavior of the spline near the end of the data.

The behavior of the clamping mechanism can be configured using the
`preference tool <../other/prefs.html>`__. The
:configparam:`Bkg,nclamp` preference changes the number of points at
the end of the data range included in the calculation of the effect of
the clamp. The :configparam:`Bkg,clamp1` and :configparam:`Bkg,clamp2`
parameters set the strengths of the two clamps. The strengths of the
clamps can be fine tuned by changing the numeric values. The parameter
:configparam:`Clamp,weak` sets the the weak clamp value, and so on.


The effect of k-weight on background removal
--------------------------------------------

The background removal section has its own :procparam:`kweight` parameter which is
distinct from the k-weight used for `plotting and Fourier
transforms <../ui/kweight.html>`__. The background removal :procparam:`kweight` is
the value used to evaluate the Fourier transform performed to determine
the background spline. By varying the value of this :procparam:`kweight`, you can
emphasize the lower or upper end of the data in the determination of the
background.

For clean data with oscillatory structure at high energy that is small
but observable, you may find that a larger value of the background
removal :procparam:`kweight` produces a better |chi| (k) spectrum. In fact, setting
this parameter to 2 or 3 can have a similar impact on the data as the
highest value of the spline clamp shown in the image above.

However, in data which are quite noisy, amplifying the noise by a
large value of :procparam:`kweight` can have a dramatic effect leading to a very
poor evaluation of |mu|\ :sub:`0`\ (E). Indeed, the |mu|\ :sub:`0`\ (E)
evaluated from noisy data with a large value of :procparam:`kweight` will
sometimes oscillate wildly, as shown in the example below.

.. _fig-bkgbadkw:
.. figure:: ../../_images/bkg_badkw.png
   :target: ../_images/bkg_badkw.png
   :align: center

   Noisy data with |mu| \ :sub:`0`\ (E) computed using the default
   :procparam:`kweight` of 2. With a :procparam:`kweight` of 1, the
   data are still noisy (of course!)  but the background function
   properly follows the data.

The interaction between spline clamps and k-weight
--------------------------------------------------

The spline clamp and :procparam:`kweight` parameters sometimes interact strongly.
The criterion that |mu|\ :sub:`0`\ (E) follow closely to the end of the data that is
imposed by the spline clamp can have a surprising effect on noisy,
heavily k-weighted data. This is what happened in the data shown in the
previous section. Reducing the strength of the spline clamp can
sometimes help.

.. _fig-bkg_badkw_clamp0:
.. figure:: ../../_images/bkg_badkw_clamp0.png
   :target: ../_images/bkg_badkw_clamp0.png
   :align: center

   The same noisy data as in the last figure, also with a background
   :procparam:`kweight` of 2. However, this time the high-end spline clamp was
   set to :title:`none`.

Sometimes your data are well served by a low :procparam:`kweight` and a strong
spline clamp. Other times, a large :procparam:`kweight` and a weak clamp work
better. Still other times, a strong :procparam:`kweight` *and* a strong clamp work
best. How do you know what to do? There are no hard and fast rules,
although you will develop an intuition for how different data will
respond to different parameter values. Don't be shy about trying
different combinations.
