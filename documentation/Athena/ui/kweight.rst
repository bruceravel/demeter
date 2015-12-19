..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


k-weights in plots and Fourier transforms
=========================================

It is common practice in EXAFS to multiply |chi| (k) by different
*k-weights*. That is, the |chi| (k) array is multiplied point-by-point
by k-array. For k\ :sup:`1` weighted data, |chi| (k) at k=5 is
multiplied by 5 and |chi| (k) at k=10 is multiplied by 10. Similarly,
for k\ :sup:`2` weighted data, |chi| (k) at k=5 is multiplied by 25 and
|chi| (k) at k=10 is multiplied by 100. This has the effect of
amplifying the spectrum at the high-k end. Since the oscillations
attenuate quickly after the edge, k-weighting is a way of making the
high-k oscillations visible in a plot.

A common approach to choosing a k-weight is to make the size of the
oscillation roughly constant over the range of the data. Weighting
data in that manner makes all parts of the data rage contribute
equivalently.  When Fourier transformed, the |chi| (R) spectrum is
then dominated by the oscillatory structure of |chi| (k). The Fourier
transform of an :quoted:`under-weighted` spectrum may be dominated by
a low-R peak representing the attenuation of the |chi| (k) spectrum.

k-weighting is also used to change the emphasis of different
contributions to the measured |chi| (k) spectrum. Low Z elements such
as O and C have scattering amplitudes that peak and low-k and become
quite small at high-k. Heavier elements, such as the transition
metals, have small scattering amplitudes at low-k but continue to have
large scattering amplitude at very high values of k. Very heavy
elements, such as Pb or Sn, have minima in their scattering amplitudes
around 5 to 7 |AA|\ :sup:`-1`. (See `my presentation on the Ramsauer-Townsend
effect
<https://speakerdeck.com/bruceravel/the-ramsauer-townsend-effect-in-x-ray-absorption-spectroscopy>`__.)

By weighting |chi| (k) with different k-weightings, the low and high portions
of the |chi| (k) spectrum can be differently emphasized in a Fourier
transform. Doing so may help you better understand your data.

The k-weighting is controlled by the bank of check buttons labeled
:guilabel:`0`, :guilabel:`1`, :guilabel:`2`, :guilabel:`3`, and
:guilabel:`kw`, and located just beneath the purple plot buttons.
This is highlighted in the figure below The buttons selected
determines the k-weighting used in a plot of |chi| (k) data or in a
Fourier transform.

.. _fig-uikweights:

.. figure:: ../../_images/ui_kweights.png
   :target: ../_images/ui_kweights.png
   :width: 65%
   :align: center

   The controls for setting the amount of k-weighting in a plot or
   Fourier transform.

The k-weight button labeled :guilabel:`kw` is used in conjunction with the
:procparam:`arbitrary k-weight` parameter. When the :guilabel:`kw` button is
selected, the |chi| (k) data are weighted by the value of the
:procparam:`arbitrary k-weight`. This can be used in a number of
ways. The simplest is if you simply want a non-integer weight. If you
want to overplot two different data groups each with a different
k-weight, that can be done by setting the :procparam:`arbitrary
k-weight` of each group appropriately.
