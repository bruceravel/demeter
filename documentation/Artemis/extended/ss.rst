`The Artemis Users' Guide <../index.html>`__

+--------------------------------------+--------------------------------------+
| «\ `DEMETER <http://bruceravel.githu |
| b.io/demeter/>`__\ »                 |
|                                      |
| «\ `IFEFFIT <https://github.com/newv |
| ille/ifeffit>`__\ »                  |
|                                      |
| «\ `xafs.org <http://xafs.org>`__\ » |
|                                      |
| Back: `Modeling bond                 |
| length <../extended/delr.html>`__    |
|    Up: `Extended                     |
| topics <../extended/index.html>`__   |
|    Next: `Constraints and            |
| restraints <../extended/constraints. |
| html>`__                             |
+--------------------------------------+--------------------------------------+

| |[Artemis logo]|
|  `Home <../index.html>`__
|  `Introduction <../intro.html>`__
|  `Starting Artemis <../startup/index.html>`__
|  `The Data window <../data.html>`__
|  `The Atoms/Feff window <../feff/index.html>`__
|  `The Path page <../path/index.html>`__
|  `The GDS window <../gds.html>`__
|  `Running a fit <../fit/index.html>`__
|  `The Plot window <../plot/index.html>`__
|  `The Log & Journal windows <../logjournal.html>`__
|  `The History window <../history.html>`__
|  `Monitoring things <../monitor.html>`__
|  `Managing preferences <../prefs.html>`__
|  `Worked examples <../examples/index.html>`__
|  `Crystallography for EXAFS <../atoms/index.html>`__
|  `Extended topics <../extended/index.html>`__
|   ↪ `Quick first shell theory <../extended/qfs.html>`__
|   ↪ `Characteristic value <../extended/cv.html>`__
|   ↪ `Modeling bond length <../extended/delr.html>`__
|   ↪ Modeling disorder
|   ↪ `Constraints and restraints <../extended/constraints.html>`__
|   ↪ `Bond valence sums <../extended/bvs.html>`__
|   ↪ `Using empirical standards <../extended/empirical.html>`__
|   ↪ `Unique potentials <../extended/ipots.html>`__
|   ↪ `Fuzzy degeneracy <../extended/fuzzy.html>`__
|   ↪ `Handling dopants <../extended/dopants.html>`__
|   ↪ `5 and 6 legged paths <../extended/fivesix.html>`__

Modeling disorder
=================

The σ² term in the EXAFS equation accounts for the mean square variation
in path length. This variation can be due to thermal or structural
disorder. Even in a well-ordered material, like Cu or another FCC metal,
data are measured at finite temperature. The absorber and scatterer are
both in motion due to the finite temperature. Each interaction of the
incident X-ray and the absorber is like a femtosecond snapshot of the
coordination environment. As those snapshots are averaged in the EXAFS
measurement, σ² is non-zero, even in the well-ordered material.

A structural disordered contributes another term to σ². Due to
structural disorder, the scatterers which are nominally contained in a
scattering shell may be centered around somehwat different distances.
When the contributions from those scatterers are considered, σ² will be
larger than what is expected from purely thermal effects.

Consequently, σ² is always non-zero in an EXAFS fit and a proper
interpretation of the fitted value of σ² will take into account both the
thermal and structural component.

It is usually a challenge to distinguish the thermal and structural
contributions to σ². As with any highly correlated effects, the only way
to disentangle the two contributions is to do something in the
experiment which is sensitive to one or both.

One common approach for understanding the thermal part of σ² is to
measure the sample at two or more temperatures. Assuming the material
does not change phase in that temperature range, we expect the thermal
part of σ² to have a temperature dependence while the structural part
may reman fixed (or at least change much less). Another possible way to
disentangle the two contributions is to measure EXAFS data as a function
of pressure. In that case the thermal contribution can be modeled as a
function of pressure and a Grüneisen parameter.

--------------

 

Debye and Einstein models
-------------------------

IFEFFIT provides two bult-in functions for modeling σ² as a function of
temperature.

 Einstein model
    The Einstein model assumes that the absorber and scatter are balls
    connected by a quantum spring. They oscillate with a single
    frequency and the low-temperature motion saturates to a zero-point
    motion. The function for computing σ² from the Einstein is a
    function of the measurement temperature, an Einstein temperature,
    and the reduced mass of the absorber/scatterer pair. In ARTEMIS one
    writes:

    ::

        path:
            sigma2 = eins(temperature, thetae)

    Typically, ``temeprature`` is a set parameter whise value is the
    mesurement tempreature of the data and ``thetae`` is a guess
    parameter representing the Einstein temprature – i.e. the
    characteristic frequency of vibration expressed in temeprature units
    – of the absorber-scatterer pair. The reduced mass is computed by
    IFEFFIT from the information provided by FEFF about the scattering
    path.

    The Einstein function is most useful as part of a multiple data set
    fit. In that case, a path can have its σ² parametrized using the
    ``eins`` function and a single Θ\ :sub:`E` guess parameter is used
    for all temperatures.

    | When using IFEFFIT, the Einstein function is called ``eins()``.
    When using LARCH, it is called ``sigma2_eins()``. The user of
    ARTEMIS can use either form with either backend and the correct
    thing will happen.

 Correlated Debye model
    The correlated Debye model assumes that the σ² for any pair of atoms
    can be computed from the acoustic phonon spectrum. That is, a single
    charcteristic energy – the same Debye temperature, , that is
    determined from the heat capacity of the material – can be used to
    compute σ² for any path in the material. In ARTEMIS one writes:

    ::

        path:
            sigma2 = debye(temperature, thetae)

    This is a very powerful concept. All σ² parameters in the fit are
    determined from a single variable Θ\ :sub:`D`. The caveat is that
    the correlated Debye model is only strictly valid for a monoatomic
    material. In practice, the Debye model works well for metals like
    Cu, Au, and Pt. It works poorly for any material that has two or
    more atomic species.

    | When using IFEFFIT, the Debye function is called ``debye()``. When
    using LARCH, it is called ``sigma2_debye()``. The user of ARTEMIS
    can use either form with either backend and the correct thing will
    happen.

Both models are described in S. Sevillano, H. Meuth, and J.J. Rehr,
*Phys. Rev.*, **B20:12**, (1979) p. 4908-4911\ `(DOI:
10.1103/PhysRevB.20.4908) <http://dx.doi.org/10.1103/PhysRevB.20.4908>`__.

--------------

 

Collinear multiple scattering paths
-----------------------------------

|collinear.png|\ A valuable paper by E.A. Hudson et al., *Phys. Rev.*,
**B54:1**, (1996) p. 156-165\ `(DOI:
10.1103/PhysRevB.54.156) <http://dx.doi.org/10.1103/PhysRevB.54.156>`__
explains the relationships between σ² parameters for single scattering
paths and certain multiple scattering paths.

The diagram to the right demonstrates the various kinds of collinear MS
paths and how they relate to the corresponding SS path.

To begin, we define guess parameters for the σ² of the SS paths to atoms
1 and 2.

::

    guess  ss1 = 0.003
    guess  ss2 = 0.003

The next two paths are double and triple scattering paths that scatter
in the forward direction from atom 1, then in the backward direction
atom 2. As explained by Hudson, et al., these paths have the same σ² as
the SS path to atom 2, i.e. σ²=\ ``ss2`` for both these paths.

The next three paths involve scattering from the absorber. The collinear
DS and TS paths simply have σ²=\ ``2*ss1``. The path in which the
photoelectron rattles back and forth between the absorber and atom 1 has
σ²=\ ``4*ss1``.

The caveat to these relationships is that the motion of the intervening
atom in the perpendicular direction is presumed to be a negligible
contribution to the mean square variation in path length. This is, of
course, not strictly true. In very high quality data, you may see
deviations from the expressions presented by Hudson, et al., but in most
cases they are an excellent approximation and a powerful constraint that
you can apply to the paths in your fit.

--------------

 

Sensible approximations for triangular multiple scattering paths
----------------------------------------------------------------

In `the FeS2 example <../examples/fes2.html>`__, we saw that a couple of
non-collinear multiple scattering paths contributed significantly to the
EXAFS. For these triangular paths, unlike for collinear paths, there is
no obvious relationship between their σ² parameters and the σ² for the
SS paths.

One of the triangular paths in the FeS\ :sub:`2` fit was of the form
Abs→Fe→S→Abs. The S→Abs leg is like half the first neighbor path. The
Fe→S is also like half the first neighbor path. The mean square
vairation in path length along those two legs of the path **is** the σ²
for the first path. FinallyThe Abs→Fe leg is like half the fourth shell
path.

The math epression for the σ² of this triangle path was set as

::

    path Fe-S triangle:
        sigma2 = ss1 + ss_fe/2

This approximation of σ² has the great virtue of not introducing a new
parameter to the fit. It neglects any attenutation to the path due to
thermal variation in sattering angle. While that is an important effect,
there is no simple and accurate way to model it.

This example demonstrates the decision that must be made every time a
non-collinear multiple scattering path is considered for a fitting
model. In short, you have three choices:

#. Do nothing, leave the MS path out of the fit.

#. Include the MS path, but allow it to have it's own σ² parameter.

#. Include the MS path, but approximate it's σ² in terms of parameters
   which are already part ofthe fitting model, presumably the parameters
   of the SS σ² values.

The Abs→Fe→S→Abs path in FeS\ :sub:`2` was really quite large. Going for
choice number 1 and leaving it out of the fit is clearly a poor choice.

Number 2 is, in principle, the best choice. As an independently floated
parameter, it's σ² will account for the mean square vriation in path
length **and** the effect of variation in t he scattering angle.
Unfortunately, this parameter is likely not to be highly robust because
it is only used for this one path. There just is not much information
available to determine its proper value. And if the fit includes several
triangle paths, each of which has a σ² parameter of similarly weak
robustness, the problem becomes amplified.

In almost all cases, option number 3 is the best choice. The
approximation is not horribly wrong, thus it introduces only a little
bit of systematic error into the fitting model. Including the Fourier
components from the path is better than neglecting the path. Since a
reasonable approximation can be made without introducing new variable
parameters to the fit, the triangle path should be included.

The Abs→Fe→S→Abs path had the virtue that all of its legs were
represented by SS paths already included in the fit. Another triangle
path was included: Abs→S→S→Abs. In this case, the first and last legs
are related to the first coordination shell. The middle leg, S→S, has no
corresponding SS path. In `the FeS2 example <../examples/fes2.html>`__,
this triangle path was given a σ² math expression of 1.5 times the first
shell σ².

This is obviously not accurate. Like all such triangle paths, the
decision outlined above must be worked through. In this case, the fit
benefits by including this triangle path, but it does not merit having
its own floating parameter. I assert that value of σ² that is “a bit
more than the first shell” is reasonable.

This is discussed in more detail in Scott Calvin's book, `XAFS for
Everyone <http://www.amazon.com/XAFS-Everyone-Scott-Calvin-ebook/dp/B00CUNBZA4>`__.

| 

--------------

--------------

| DEMETER is copyright © 2009-2015 Bruce Ravel — This document is
copyright © 2015 Bruce Ravel

|image2|    

| This document is licensed under `The Creative Commons
Attribution-ShareAlike
License <http://creativecommons.org/licenses/by-sa/3.0/>`__.
|  If DEMETER and this document are useful to you, please consider
`supporting The Creative
Commons <http://creativecommons.org/support/>`__.

.. |[Artemis logo]| image:: ../../images/Artemis_logo.jpg
   :target: ../diana.html
.. |collinear.png| image:: ../../images/collinear.png
   :target: ../../images/collinear.png
.. |image2| image:: ../../images/somerights20.png
   :target: http://creativecommons.org/licenses/by-sa/3.0/
