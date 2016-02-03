..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Modeling disorder
=================

The |sigma|\ :sup:`2` term in the EXAFS equation accounts for the mean
square variation in path length. This variation can be due to thermal
or structural disorder. Even in a well-ordered material, like Cu or
another FCC metal, data are measured at finite temperature. The
absorber and scatterer are both in motion due to the finite
temperature. Each interaction of the incident X-ray and the absorber
is like a femtosecond snapshot of the coordination environment. As
those snapshots are averaged in the EXAFS measurement, |sigma|\
:sup:`2` is non-zero, even in the well-ordered material.

A structural disordered contributes another term to |sigma|\
:sup:`2`. Due to structural disorder, the scatterers which are
nominally contained in a scattering shell may be centered around
somehwat different distances.  When the contributions from those
scatterers are considered, |sigma|\ :sup:`2` will be larger than what
is expected from purely thermal effects.

Consequently, |sigma|\ :sup:`2` is always non-zero in an EXAFS fit and
a proper interpretation of the fitted value of |sigma|\ :sup:`2` will
take into account both the thermal and structural component.

It is usually a challenge to distinguish the thermal and structural
contributions to |sigma|\ :sup:`2`. As with any highly correlated
effects, the only way to disentangle the two contributions is to do
something in the experiment which is sensitive to one or both.

One common approach for understanding the thermal part of |sigma|\
:sup:`2` is to measure the sample at two or more
temperatures. Assuming the material does not change phase in that
temperature range, we expect the thermal part of |sigma|\ :sup:`2` to
have a temperature dependence while the structural part may reman
fixed (or at least change much less). Another possible way to
disentangle the two contributions is to measure EXAFS data as a
function of pressure. In that case the thermal contribution can be
modeled as a function of pressure and a Grüneisen parameter.


Debye and Einstein models
-------------------------

:demeter:`ifeffit` provides two bult-in functions for modeling
|sigma|\ :sup:`2` as a function of temperature.

**Einstein model**
    The Einstein model assumes that the absorber and scatter are balls
    connected by a quantum spring. They oscillate with a single
    frequency and the low-temperature motion saturates to a zero-point
    motion. The function for computing |sigma|\ :sup:`2` from the
    Einstein is a function of the measurement temperature, an Einstein
    temperature, and the reduced mass of the absorber/scatterer
    pair. In :demeter:`artemis` one writes:

    ::

        path:
            sigma2 = eins(temperature, thetae)

    Typically, ``temeprature`` is a set parameter whise value is the
    mesurement tempreature of the data and ``thetae`` is a guess
    parameter representing the Einstein temprature |nd| i.e. the
    characteristic frequency of vibration expressed in temeprature
    units |nd| of the absorber-scatterer pair. The reduced mass is
    computed by :demeter:`ifeffit` from the information provided by
    :demeter:`feff` about the scattering path.

    The Einstein function is most useful as part of a multiple data
    set fit. In that case, a path can have its |sigma|\ :sup:`2`
    parametrized using the ``eins`` function and a single |Theta|\
    :sub:`E` guess parameter is used for all temperatures.

    When using :demeter:`ifeffit`, the Einstein function is called
    ``eins()``.  When using :demeter:`larch`, it is called
    ``sigma2_eins()``. The user of :demeter:`artemis` can use either
    form with either backend and the correct thing will happen.

**Correlated Debye model**
    The correlated Debye model assumes that the |sigma|\ :sup:`2` for
    any pair of atoms can be computed from the acoustic phonon
    spectrum. That is, a single charcteristic energy |nd| the same
    Debye temperature, , that is determined from the heat capacity of
    the material |nd| can be used to compute |sigma|\ :sup:`2` for any
    path in the material. In :demeter:`artemis` one writes:

    ::

        path:
            sigma2 = debye(temperature, thetae)

    This is a very powerful concept. All |sigma|\ :sup:`2` parameters
    in the fit are determined from a single variable |Theta|\
    :sub:`D`. The caveat is that the correlated Debye model is only
    strictly valid for a monoatomic material. In practice, the Debye
    model works well for metals like Cu, Au, and Pt. It works poorly
    for any material that has two or more atomic species.

    When using :demeter:`ifeffit`, the Debye function is called
    ``debye()``. When using :demeter:`larch`, it is called
    ``sigma2_debye()``. The user of :demeter:`artemis` can use either
    form with either backend and the correct thing will happen.



Both models are described in

.. bibliography:: ../artemis.bib
   :filter: author % 'Sevillano'
   :list: bullet


Colinear multiple scattering paths
----------------------------------

This valuable paper explains the relationships between |sigma|\
:sup:`2` parameters for single scattering paths and certain multiple
scattering paths:

.. bibliography:: ../artemis.bib
   :filter: author % 'Hudson'
   :list: bullet

.. _fig-colinear:
.. figure:: ../../_images/collinear.png
   :target: ../_images/collinear.png
   :align: center

   This diagram demonstrates the various kinds of collinear MS paths
   and how they relate to the corresponding SS path.

To begin, we define guess parameters for the |sigma|\ :sup:`2` of the
SS paths to atoms 1 and 2.

::

    guess  ss1 = 0.003
    guess  ss2 = 0.003

The next two paths are double and triple scattering paths that scatter
in the forward direction from atom 1, then in the backward direction
atom 2. As explained by Hudson, et al., these paths have the same
|sigma|\ :sup:`2` as the SS path to atom 2, i.e. |sigma|\ :sup:`2` =
``ss2`` for both these paths.

The next three paths involve scattering from the absorber. The
collinear DS and TS paths simply have |sigma|\ :sup:`2` =
``2*ss1``. The path in which the photoelectron rattles back and forth
between the absorber and atom 1 has |sigma|\ :sup:`2` = ``4*ss1``.

The caveat to these relationships is that the motion of the intervening
atom in the perpendicular direction is presumed to be a negligible
contribution to the mean square variation in path length. This is, of
course, not strictly true. In very high quality data, you may see
deviations from the expressions presented by Hudson, et al., but in most
cases they are an excellent approximation and a powerful constraint that
you can apply to the paths in your fit.



Sensible approximations for triangular multiple scattering paths
----------------------------------------------------------------

In `the FeS2 example <../examples/fes2.html>`__, we saw that a couple
of non-collinear multiple scattering paths contributed significantly
to the EXAFS. For these triangular paths, unlike for collinear paths,
there is no obvious relationship between their |sigma|\ :sup:`2`
parameters and the |sigma|\ :sup:`2` for the SS paths.

One of the triangular paths in the FeS\ :sub:`2` fit was of the form
Abs-Fe-S-Abs. The S-Abs leg is like half the first neighbor path. The
Fe-S is also like half the first neighbor path. The mean square
vairation in path length along those two legs of the path **is** the
|sigma|\ :sup:`2` for the first path. Finally, the Abs-Fe leg is like
half the fourth shell path.

The math epression for the |sigma|\ :sup:`2` of this triangle path was
set as

::

    path Fe-S triangle:
        sigma2 = ss1 + ss_fe/2

This approximation of |sigma|\ :sup:`2` has the great virtue of not
introducing a new parameter to the fit. It neglects any attenuation
to the path due to thermal variation in sattering angle. While that is
an important effect, there is no simple and accurate way to model it.

This example demonstrates the decision that must be made every time a
non-colinear multiple scattering path is considered for a fitting
model. In short, you have three choices:

#. Do nothing, leave the MS path out of the fit.

#. Include the MS path, but allow it to have it's own |sigma|\
   :sup:`2` parameter.

#. Include the MS path, but approximate it's |sigma|\ :sup:`2` in
   terms of parameters which are already part of the fitting model,
   presumably the parameters of the SS |sigma|\ :sup:`2` values.

The Abs-Fe-S-Abs path in FeS\ :sub:`2` was really quite large. Going for
choice number 1 and leaving it out of the fit is clearly a poor choice.

Number 2 is, in principle, the best choice. As an independently
floated parameter, it's |sigma|\ :sup:`2` will account for the mean
square vriation in path length **and** the effect of variation in the
scattering angle.  Unfortunately, this parameter is likely not to be
highly robust because it is only used for this one path. There just is
not much information available to determine its proper value. And if
the fit includes several triangle paths, each of which has a |sigma|\
:sup:`2` parameter of similarly weak robustness, the problem becomes
amplified.

In almost all cases, option number 3 is the best choice. The
approximation is not horribly wrong, thus it introduces only a little
bit of systematic error into the fitting model. Including the Fourier
components from the path is better than neglecting the path. Since a
reasonable approximation can be made without introducing new variable
parameters to the fit, the triangle path should be included.

The Abs-Fe-S-Abs path had the virtue that all of its legs were
represented by SS paths already included in the fit. Another triangle
path was included: Abs-S-S-Abs. In this case, the first and last legs
are related to the first coordination shell. The middle leg, S-S, has
no corresponding SS path. In `the FeS2 example
<../examples/fes2.html>`__, this triangle path was given a |sigma|\
:sup:`2` math expression of 1.5 times the first shell |sigma|\
:sup:`2`.

This is obviously not accurate. Like all such triangle paths, the
decision outlined above must be worked through. In this case, the fit
benefits by including this triangle path, but it does not merit having
its own floating parameter. I assert that value of |sigma|\ :sup:`2`
that is :quoted:`a bit more than the first shell` is reasonable.

This is discussed in more detail in Scott Calvin's book,

.. bibliography:: ../artemis.bib
   :filter: title % 'Everyone'
   :list: bullet
