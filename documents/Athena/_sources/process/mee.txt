
Multi-electron excitation removal
=================================

:mark:`bend,..` XAS is normally thought of in terms of a single
electron phenomenon. A photon goes in and a photoelectron goes out. In
fact multi-body phenomena are possible and, on occasion, must be
considered in the interpretation of XAS data. One such is the
so-called :quoted:`shake-off` effect in which the photoelectron has
sufficient kinetic energy to excite a high-lying electron. For
example, at around 415 eV above the uranium L\ :sub:`III` edge, the
photoelectron can excite an N\ :sub:`6` or N\ :sub:`7` transition.

The cross-section of this secondary edge can be quite small. In the
example of the L\ :sub:`III`\ N\ :sub:`6,7` transition, the secondary
cross section is about 3 orders of magnitude smaller than the primary
L\ :sub:`III` edge. If, in this example, you have very good data with
measurable EXAFS beyond about 10.5 |AA|\ :sup:`-1`, the multi-electron
excitation will not be small compared to the L\ :sub:`III`
EXAFS. Other multi-electron excitations have even larger
cross-sections compared to their primary excitations. For a much more
complete discussion of multi-electron excitations see `Iztok Arcon's
Mulielectron Photoexcitations page
<http://www.p-ng.si/~arcon/xas/mpe/mpe.htm>`__.

Another similar phenomenon is the presence of a small impurity of the
Z+1 element, leading to a small edge step well above the measured edge.
In some cases this small edge step might be hard to see in your |mu| (E)
data, but are clearly visible as a step in the |chi| (k) which Fourier
transforms into a low-R contribution in the |chi| (R) spectrum.

:demeter:`athena` offers two relatively simple algorithms to attempt to remove the
effect of a step due to multi-electron excitations or small impurities
from your data. One models the multi-electron excitation as a reflection
of the data translated to the position in energy of the excitation. The
other places an arctangent function at the specified energy. Be warned
that the algorithm described here requires considerable user input and
sufficient knowledge to properly evaluate the results.

That said, let's carry on.

.. _fig-mee:

.. figure:: ../../_images/mee.png
   :target: ../_images/mee.png
   :width: 65%
   :align: center

   The multi-electron excitation removal tool.

Unfortunately, :demeter:`athena` has no practical way of guessing
sensible starting values for the three parameters. So it is entirely
up to the user to set these appropriately.

Shown below are data on LaCoO\ :sub:`3` which display a [3p4d]5d
excitation at about 120 volts above the edge.

.. subfigstart::

.. _fig-meee:

.. figure::  ../../_images/mee_e.png
   :target: ../_images/mee_e.png
   :width: 100%

   The results of removing the [3p4d]5d multi-electron excitation in
   La L\ :sub:`III`-edge data, which occurs at about 120 volts above
   the edge.  This excitation is seen near the cursor in the energy
   plot. 

.. _fig-meek:

.. figure::  ../../_images/mee_k.png
   :target: ../_images/mee_k.png
   :width: 100%

   Its effect is much more pronounced in the |chi| (k) data on
   the right.

.. subfigend::
   :width: 0.45
   :label: _fig-meedone

   

For more information about multi-electron excitations, see

    .. bibliography:: ../athena.bib
       :filter: author % "Kodre"
       :list: bullet


Using the parameter shown inthe screen shot above, the removal is
performed and shown as the red line in the figures. The shift was
first guessed as the separation between the white line in the XANES
data and the prominant feature at 5.7 |AA|\ :sup:`-1`. That came out to
be 121.04 eV. After a bit of examination, I settled on 122 eV.

The amplitude by which the reflected data is scaled is 0.014 in this
example. That number is a fraction of the edge step. That is, its value
is to be compared to the normalized data. If this is set to a negative
number, it will be reset to zero (which has the effect of not doing a
removal).

Finally, the XANES data are broadened by a couple volts. If you set this
to be zero or a negative number, a value of 0.01 eV will be used.

Once you find a set of parameters that does a good job of removing the
excitation, the excitation-subtracted data can be saved as a group in
the group list.

This is a good reference on the effect of small multi-electron
excitations on otherwise excellent |chi| (k) data:

    .. bibliography:: ../athena.bib
       :filter: author % "Hennig"
       :list: bullet
       
Note that this tool can also be used to approximately remove the
contamination from a small edge of another element that shows up in the
data.

