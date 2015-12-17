.. _rbkg_sec:

The AUTOBK Algorithm and the Rbkg Parameter
===========================================

The frequency cutoff between the background and the data discussed in
the previous section is determined by the :procparam:`rbkg`
parameter. This is the second parameter displayed in the background
removal section of the main window.

When data are imported into :demeter:`athena`, :procparam:`rbkg` is
set to its `default value <../params/defaults.html>`__, normally 1.

This example, like many of the examples in this Users' Guide, can be
found `among the examples at my XAS-Education
site <http://bruceravel.github.io/XAS-Education/>`__.

Among these example files is one called :file:`fe.060`, which contains a
spectrum from an iron foil measured at 60 K. Import this by selecting
:menuselection:`File --> Import data` or by pressing
:button:`Control`-:button:`o`. Navigate to the location of your example
files and select :file:`fe.060`. The `column selection dialog
<../import/columns.html>`__ then appears. For now, just click OK.

The data is imported and :procparam:`rbkg` is set to its default value
of 1. The data and the background function found using the default
parameter values can be found by pressing the :button:`E,orange`
button. This is shown here on the left.

.. subfigstart::

.. _fig-rbkginitial1:

.. figure::  ../../_images/rbkg_initial.png
   :target: ../_images/rbkg_initial.png
   :width: 100%

   The :file:`fe.060` data and its default background function.

.. _fig-rbkginitial_k:

.. figure::  ../../_images/rbkg_initial_k.png
   :target: ../_images/rbkg_initial_k.png
   :width: 100%

   The :file:`fe.060` |chi| (k) data with its default background function.

.. _fig-rbkginitial_r:

.. figure::  ../../_images/rbkg_initial_r.png
   :target: ../_images/rbkg_initial_r.png
   :width: 100%

   The :file:`fe.060` |chi| (R) data with its default background function.

.. subfigend::
   :width: 0.45
   :label: _fig-rbkginitial


The background function is subtracted from the data and normalized,
resulting in a |chi| (k) function. Press the :button:`k,orange` button to
see |chi| (k), shown in the right panel above.

When you press the :button:`R,orange` button, the Fourier transform is
plotted, as in the bottom panel above.

So :procparam:`rbkg` is the value below which the :demeter:`autobk`
algorithm removes Fourier components. As you can see, below 1 the
|chi| (R) function is essentially 0, but above 1 the spectrum is
non-zero.

Now let's examine the effect of choosing different values for
:procparam:`rbkg`.  First, make a copy of the data so we can directly
compare different values. Do that by selecting :menuselection:`Group
--> Copy current group` or by pressing
:button:`Alt`-:button:`y`. :demeter:`athena` now looks like this.

.. _fig-rbkg:

.. figure:: ../../_images/rbkg.png
   :target: ../_images/rbkg.png
   :width: 65%
   :align: center

   The original :file:`fe.060` data and a copy of that data.

Click on the group *Copy of fe.060* to display its parameters in the
main window. Change :procparam:`rbkg` to 0.2. Now we want to directly
compare these two ways of removing the background. The way of plotting
multiple items in the groups list involves the row of purple plotting
buttons and the little check buttons next to the items in the group
list. Click on the little check buttons next to :guilabel:`fe.060` and
:guilabel:`Copy 1 of fe.060`, as shown in the screenshot above. Now
plot these two items by clicking the :button:`R,purple` button. It should
look something like this.

.. subfigstart::

.. _fig-rbkg102:

.. figure::  ../../_images/rbkg_1_0_2.png
   :target: ../_images/rbkg_1_0_2.png
   :width: 100%

   Comparing |chi| (R) for the data and its copy with
   :procparam:`rbkg` values of 1 and 0.2.

.. _fig-rbkg102k:

.. figure::  ../../_images/rbkg_1_0_2k.png
   :target: ../_images/rbkg_1_0_2k.png
   :width: 100%

   Comparing |chi| (k) for the data and its copy with
   :procparam:`rbkg` values of 1 and 0.2.

.. _fig-rbkg02e:

.. figure::  ../../_images/rbkg_0_2e.png
   :target: ../_images/rbkg_0_2e.png
   :width: 100%

   |mu| (E) and the background for the copy with an :procparam:`rbkg`
   value 0.2.

.. subfigend::
   :width: 0.45
   :label: _fig-rbkg10


I suspect the blue spectrum is something like what you expect EXAFS data
to look like, while the red one seems somehow worse. In fact, it is easy
to understand why the red one looks the way it does. The :procparam:`rbkg`
parameter specifies the R value below which the data is removed from the
|mu| (E) spectrum. That is exactly what has happened in the red spectrum --
below 0.2 the signal is very small and the first big peak is, in fact,
above 0.2.

Those two, plotted as |chi| (k), are shown above on the right.

The blue spectrum oscillates around the zero axis, as one would expect.
The red one has an obvious, long-wavelength oscillation. It is that
oscillation that gives rise to the low-R peak in the |chi| (R) spectrum.

The background function, computed using 0.2 as the value of
:procparam:`rbkg` and plotted in energy, is shown above in the bottom
panel.

Using an :procparam:`rbkg` value of 0.2 yields a background function
that is not able to follow the actual shape of the data.

What happens if the value of :procparam:`rbkg` is set to a very large
value? The |chi| (R) data for the values 1 and 2.5 are shown here.

.. _fig-rbkg_125:

.. figure:: ../../_images/rbkg_1_2_5.png
   :target: ../_images/rbkg_1_2_5.png
   :width: 45%
   :align: center

   (Right) Comparing |chi| (R) for the data and its copy with :procparam:`rbkg` values
   of 1 and 2.5. (Left) |mu| (E) and the background for the copy with an
   :procparam:`rbkg` value 2.5.

Using a very large value of :procparam:`rbkg` results in significant change to the
first peak in |chi| (R). We can see why by looking at the background function
in energy . With such a large value of :procparam:`rbkg`, the background function
has enough freedom to oscillate with frequencies that resemble the data.
This results in a reduction of intensity under the first peak.

The spline used to compute the background function has a limited amount
of freedom to oscillate. The number of spline knots is determined by the
Nyquist criterion. This number is proportional to the extent of the data
in k-space multiplied by :procparam:`rbkg`. These knots are spaced evenly in
wavenumber. Thus the spline function can only have frequency components
below :procparam:`rbkg`.

So where does that leave us? We want to make :procparam:`rbkg` as big as possible
so that the low-R peaks are as well suppressed as possible. On the other
hand, too large of a value will result in damage to the data. The trick
is to find a balance.

A good rule of thumb is that :procparam:`rbkg` should be about half the distance to
the nearest neighbor. But that is only a rule of thumb. Real data can be
really difficult. Noisy data, data with strong white lines, data
truncated by the appearance of another edge -- all of these require
careful consideration. While :procparam:`rbkg` is the primary background removal
parameter, several others should be investigated to yield a good
background removal. Several of these are the subjects of the following
sections.

The literature reference for the :demeter:`autobk` algorithm is:

.. bibliography:: ../athena.bib
   :filter: author % "Newville" and year == '1993'
   :list: bullet
