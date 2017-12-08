..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: penalty

The non-statistical happiness metric
====================================

The :quoted:`happiness` is a non-statistical metric that evaluates the
fit in a semantic sense.  As explained elsewhere, :demeter:`ifeffit`
uses a Levenberg-Marquardt fitting algorithm and applies Gaussian
statistics to the EXAFS analysis problem.  For a host of reasons, the
application of Gaussian statistics is troublesome for EXAFS.  The most
striking result is that the reduced |chi|\ :sup:`2` of a good fit is
rarely close to 1, as one would expect for a properly conceived
Gaussian problem.  Even for a very good fit to a metallic standard
which returns very sensible parameter values, the reduced |chi|\
:sup:`2` is likely to be in the 10s or 100s.

Although the Gaussian problem is ill-posed, years of experience
fitting EXAFS data has taught us much about what constitutes as a good
fit.  We expect that the R-factor is small.  We expect that S\
:sup:`2`\ :sub:`0` and |sigma|\ :sup:`2` are non-negative.  We expact
neither |Delta| R nor E\ :sub:`0` will be too large.  We know that we
should not use too many of the independent points contained in the
data.

All of those are things that we consider when examining the results of
a fit. When one or more of those things does not hold for a fit, we
are unhappy and thus wary of the fit.  If, however, all of them hold
true, then we might have confidence in the fit, thus making us happy.



A semantic parameter
--------------------

:demeter:`demeter` has a simple mechanism for parameterizing the
results of the fit to evaluate a semantic assessment of the fit. Each
fit starts with a score of 100. Each of those semantic evaluations of
the fit are subjected to the simple algorithm. Each such evaluation is
a penalty which is subtracted from the score. A fit with a score near
100 is :quoted:`happy`, which a fit with a score of 60 or below is
:quoted:`unhappy`. It is, therefore, a tool to help you evaluate the
result of your fit.

.. caution:: The word :quoted:`happiness` was chosen for this
   parameter because it is silly. This is an ad-hoc, semantic metric.
   It has no basis in formal statistics. It is, therefore, meaningless
   and should **never** be published.



How the happiness is calculated
-------------------------------

The fit's happiness is computed using a bunch of `configuration
parameters <../highlevel/config.html>`__ from the ``happiness``
configuration group.  Here is a summary of how the happiness is
calculated.  All numbers given in the following descriptions can be
set using the configuration system.

#. It should have a small R-factor. An R-factor below 0.2 gives no
   penalty.  An R-factor above 0.6 gives a penalty of 40.  R-factors
   between those values scale linearly between 0 and 40.

#. If the number of guess parameters is fewer than 2/3 of the number
   of independent points, no penalty is given.  As the number of guess
   parameters approaches the number of independent points, the penalty
   grows.

#. A penalty of 2 is given for each Path with a negative |sigma|\
   :sup:`2` or |sigma|\ :sup:`2` value.

#. A penalty of 2 is given for each E\ :sub:`0`, |Delta| R, or
   |sigma|\ :sup:`2` path parameter of each Path that is too big.

#. For each restraint that evaluates to something non-zero, a penalty is
   given that is proportional to the value of the restraint divided by
   the value of |chi|\ :sup:`2`.

The Fit object's ``happiness`` attribute is set to the evaluation of
the happiness metric.  A color is also computed based on this value
for use as a semantic indicator in a GUI or web program. The idea
behind the color is to serve as a sort of :quoted:`environmental
indicator` providing immediate feedback as to the state of the most
recent fit.  For instance, a fit that looks good in the sense that the
red line plots nicely over the blue line but which displays the
unhappy color will induce the user to explore the problem making the
fit unhappy.  Without that environmental indication, one might see a
nice plot and assume that the fit is, in fact, a good one.

The default values of the configuration parameters related to the
happiness calculation seems to be reasonable, but you are certainly
encouraged to tune those values to give you results that are more
useful for your experience.  If you do so, please share your work with
Bruce so that your experience can be folded back into
:demeter:`demeter`.

.. todo:: In a future version of :demeter:`demeter` it will be
   possible to define a :penalty:`penalty` parameter, which is a
   special kind of GDS object. It will be like an after parameter in
   the sense that it is evaluated at the end of the fit. Its
   evaluation will be used as an additional, user-defined subtraction
   from the happiness. This will give a dynamic, aspect to the
   happiness evaluation which is specific to the fitting model.



Happiness is not a real statistical parameter
---------------------------------------------

One final note about the happiness metric. Use it to evaluate your
progress through a fitting project, but don't publish it.  Really. If
you do publish it, we will both look like twits.

