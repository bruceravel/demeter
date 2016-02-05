..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


The heuristic happiness parameter
=================================

:demeter:`artemis` evaluates a variety of statistical parameters
relevant to the evaluation of your fit.  These include the fitting
metric |chi|\ :sup:`2`, the fitting metric normalized by the degrees
of freedom in the fit |chi|\ :sup:`2`\ :sub:`v`, an R-factor, and the
uncertainties of and correlations between the variable parameters.

In a formal sense, the most important of these parameters is |chi|\
:sup:`2`\ :sub:`v`, which is the statistical parameter allowing you to
distinguish between different fitting models applied to the same data.
Unfortunately, |chi|\ :sup:`2`\ :sub:`v` is difficult to interpret
directly.  In practice, the EXAFS analysis problem using
:demeter:`feff` is not a well-posed problem in the sense required by
Gaussian statistics. This is true for a variety of reasons. In EXAFS,
the signal is not ideally packed |nd| that is, the signal is not
composed of pure sine waves. In general, you cannot guarantee that
errors in your fitting parameters are normally distributed. In
general, we cannot actually identify and enumerate all sources of
measurement error, many of which are complex and systematic, such as
sample inhomogeneity, detector non-linearity, and so on.  Finally, we
do not know the true line shape of our signal |nd| instead we use
:demeter:`feff` to approximate the lineshape.  All of this is
discussed further in my `Advanced Topics in EXAFS Analysis talk
<https://speakerdeck.com/bruceravel/advanced-topics-in-exafs-analysis?slide=6>`_

For all those reasons, |chi|\ :sup:`2`\ :sub:`v` is rarely |nd| if
ever |nd| close to 1 as expected for a good fit. Although |chi|\
:sup:`2`\ :sub:`v` for different fitting models can be compared
effectively, it is, generally speaking, not a sufficient criterion for
evaluating the quality of an individual fit.

Happily, this is not an insolvable problem. After decades of analyzing
EXAFS data, using :demeter:`feff`, and using :demeter:`ifeffit`, we
know a lot about what constitutes a good fit. For instance, a good fit
has a small R-factor, which is a measure of the percentage misfit
between the data and theory.  We know things about individual
parameter types, e.g. that an E\ :sub:`0` is rarely more than 10 eV or
less than -10 eV, that S\ :sup:`2`\ :sub:`0` and |sigma|\ :sup:`2`
should never be negative. We know that a robust fit does not have
excessive correlation between variable parameters.

:demeter:`artemis` offers a heuristic tool called :quoted:`happiness`
which is an attempt to enumerate the knowledge and experience we bring
to a fit. After a fit, this heuristic parameter is evaluated and
reported in the log file.  It has no meaning other that to give you a
general sense of how the fit came out.

.. caution:: The word :quoted:`happiness` was chosen for this
   parameter because it is a silly word in a statistics context.
   Happiness is an ad-hoc, semantic metric.  It has no basis in formal
   statistics. It is a functionally meaningless parameter and should
   **NEVER** be published.  **NEVER**!


Evaluation of the happiness parameter
-------------------------------------

The happiness parameter begins with a value of 100, indicating complete
happiness. After the fit is evaluated, a series of tests are run against
the fitting results. If a test hits, it removes points from the
happiness. The final evaluation is reported in the log file and used to
color the Fit and plot buttons.

**R-factor**
    Assess a penalty for an R-factor that is larger than 0.02. That
    is, any fit which has 2% or less misfit between data and theory is
    not assessed a penalty. Above that, the penalty scales linearly in
    R-factor up to a maximum penalty of 40.

**Parameter values**
    After every path parameter for every path is evaluated, assess a
    penalty of 2 for each path parameter that fails a sanity
    check. The sanity checks include checking that E₀ is not too large
    either positively or negatively, checking that neither of S\
    :sup:`2`\ :sub:`0` or |sigma|\ :sup:`2` is negative, and checking
    that neither of |sigma|\ :sup:`2` or |Delta| R is too large.

**Restraints**
    If any restraints are placed upon the fit, assess a penalty for
    every restraint which evaluates to something non-zero. The penalty
    scales linearly with the size of the evaluated restraint.

**Number of independent points**
    Assess a penalty if the number of guess parameters is larger than
    2/3 of the total number of independent points as evaluated by the
    Nyquist criterion. Above the 2/3 threshold, the penalty scales
    linearly.

**Correlations**
    Assess a penalty for each correlation that exceeds a cutoff value.

**Penalty parameters**
    Assess a penalty equal to the evaluation of a penalty parameter.
    *Penalty parameters have not yet been implemented.*


Configuring the happiness evaluation
------------------------------------

Note that everything above is something that Bruce made up out of whole
cloth, inlcuding the parametrization. That said, every part of the
happiness calculation is configurable. That means that you, the user,
can tune the happiness evaluation to report on fit quality in a way that
is meaningful and useful for your data and your fits.

The configuration parameters are spread over `two configuration groups
<../prefs.html>`__. The parameters in the :quoted:`Happiness` group
control the evaluation of the penalties. Those in the
:quoted:`Warning` group control the assessment of path parameter
values.

For example, to tune the assessment of the penalty for an excessive
number of guess parameters, you can change two configuration
parameters.  :configparam:`Happiness,nidp_cutoff` default to 2/3 and
sets the cutoff below which no penalty is assessed. This parameter is
interpreted as a fraction of total number of independent points in the
fit. :configparam:`Happiness,nidp_scale` sets the maximum penalty to
assess for using up all the independent points.

The path parameter penalties can also be fine tuned. A couple
examples: the value above which a penalty is assessed for an
excessively large E\ :sub:`0` is set with
:configparam:`Warnings,e0_max` and the assessment of a penalty for a
negative |sigma|\ :sup:`2` can be turned off by toggling
:configparam:`Warnings,ss2_neg`.

Since this happiness thing is an artificial and statistically
meaningless creation, it can be changed as you like.  Do you have any
ideas for penalty assessments?  Open `an issue
<https://github.com/bruceravel/demeter/issues>`_ at the
:demeter:`demeter` website.  Do you have a suggestion for how the
existing penalties should be tuned?  Post your configuration parameter
values `as an issue <https://github.com/bruceravel/demeter/issues>`_.

