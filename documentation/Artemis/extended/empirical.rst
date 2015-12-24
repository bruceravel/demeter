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
| Back: `Bond valence                  |
| sums <../extended/bvs.html>`__       |
| Up: `Extended                        |
| topics <../extended/index.html>`__   |
|    Next: `Unique                     |
| potentials <../extended/ipots.html>` |
| __                                   |
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
|   ↪ `Modeling disorder <../extended/ss.html>`__
|   ↪ `Constraints and restraints <../extended/constraints.html>`__
|   ↪ `Bond valence sums <../extended/bvs.html>`__
|   ↪ Using empirical standards
|   ↪ `Unique potentials <../extended/ipots.html>`__
|   ↪ `Fuzzy degeneracy <../extended/fuzzy.html>`__
|   ↪ `Handling dopants <../extended/dopants.html>`__
|   ↪ `5 and 6 legged paths <../extended/fivesix.html>`__

Fitting with empirical standards
================================

Let me just say up front that ARTEMIS is intended as a front-end to FEFF
for the problem of EXAFS analysis. In almost all cases, FEFF is the
right tool for that job and there are extremely few cases where the use
of empirical standards is preferable to using FEFF. As discussed
elsewhere in this manual, there are a situations where the application
of FEFF to a particular problem may not be obvious. Any situation for
which the choice of a starting configuration of atomic coordinates, as
needed for FEFF's input data, is not obvious might fall into that
category. In one of those situations, you might be tempted to puruse
empirical standards. You would, however, usually be better served by
adopting one of the strategies that have been developed for applying
FEFF calculations to unknown structures.

That said, there are a small handful of situations where the use of
empirical standards is justified. In fact, I can think of two. The
situation where an absorber and a scatterer are bound by a hydrogen atom
– i.e. there is a hydrogen atom in the space between the absorber and
scatterer from which the photoelectron might scatter – is poorly handled
by FEFF. In that case, finding a suitable empirical standard will likely
be an improvement over the systematic error introduced by FEFF's poor
handlng of the hydrogen. The second example would be a heterogeneous
sample – like a soil – which contains a component which varies little
from sample to sample. In that case, using an emirical standard to
represent the unchanging component and using FEFF to model the behavior
of the component(s) which do change across the ensemble of measurements
might be a fruitful strategy.

To this end, DEMETER offers a mechanism for generating an empirical
standard from measured data. This is saved in a form that can be used by
ARTEMIS as if it were a normal path imported into the fit in the normal
way.

My example will use the copper foil data at 10 K and 150 K, which can be
found at `at my Github
site <https://github.com/bruceravel/XAS-Education/tree/master/Examples>`__.
In order to demonstrate the gneration and use of an empirical standard,
I will use the uncomplicated example of using the low temperature data
as the standard for the analysis of the higher temperature data. Of
course, a real-world scenario will be much more complicated that this
example, but it should demonstrate the mechanics of making and using the
empirical standard.

--------------

 

Preparing the empirical standard
--------------------------------

It starts by processing the data properly. First, import the two data
sets into ATHENA. Take care that the data are aligned and have the same
values for E₀. Choose a k-range over which both data sets are of good
quality. I have chosen a range of 3Å⁻¹ to 12 Å⁻¹. Then choose an R-range
to enclose and isolate the first peak, which corresponds to the first
coordination shell. Here, I chose 1.8 Å to 2.8 Å.

|image1|

The Cu foil data at two temperatures have been imported into ATHENA,
aligned, and processed.

|  
| |image2|   |foo|

Here are the Cu foil data at the two temperatures plotted in R-space
(left) and back-transform k-space (right).

Select the data set from which you wish to make an empirical standard,
in this case the data measured at 10 K. In the File menu is a “Export”.
One of the options is to export an empirical standard.

|image4|

Exporting the processed data as an empirical standard.

This will prompt you for a file name using the standard file selection
dialog. The default file is the name of the data group with .es as the
extension. It will then prompt you for the species of the scattering
element using a periodic table dialog. ATHENA has no way of knowing the
scatterer species, so you have to provide this information. In this
case, you would click on Cu since this is a copper foil.

|image5|

Select the species of the scatterer from the periodic table interface.

--------------

 

Using the empirical standard
----------------------------

Now fire up ARTEMIS and import the 150 K data from the ATHENA project
file you saved before closing ATHENA. (You **did** save your work,
didn't you?!) The k- and R-ranges will be imported as they were set in
ATHENA. To begin the analysis using the empirical standard, click on the
hot text indicated in the figure below. You can also import this sort of
standard from the “Data->Other fitting standards...” menu.

|image6|

The 150 K data have been imported into ARTEMIS and we are ready to
import the prepared empirical standard.

Once the empirical standard is imported, it will be displayed just like
a normal path. You can tell it is an empirical standard because its
label contains the token “[Emp.]”.

Here I have set up a 4-parameter fit typical for a first shell analysis,
except that I have set the E₀ parameter to 0. The amplitude, σ², and ΔR
are guess parameters.

|image7|

The 150 K data and the empirical standard have been imported into
ARTEMIS.

We are now ready to hit the Fit button. Shown below are the results of
the fit with the fitting space chosen first as R, then as q.

|  
| |image8|   |foo|

The results of the fit with the fitting space selected as R and the plot
displayed in R.

|  
| |image10|   |foo|

The results of the fit with the fitting space selected as q and the plot
displayed in q.

The results fitting in R or q are pretty similar, which is reassuring.

The value for the amplitude is consistent with and close to 1, which is
should be since the copper metal is 12-fold coordinate at both
temperatures.

The value for the change in σ² is 0.0017±3, which seems reasonable for
this change in temperature.

The value for ΔR fitted in q space is 0.001±1. Fitted in R space, the
uncertainty is 0.002. That's kind of interesting. In either case, the
uncertainty in R is smaller than for a Feff-based fit for a number of
reasons. Probably the most significant is that both standard and data
are of excellent quality. Were the data the sort of marginal data that
comes from most research problems on difficult materials, the effects of
statistical and systematic noise would be much more dramatic. Also
relevant to the small uncertainty is that this fitting problem has been
contrived (by virtue of careful alignment and choice of E₀ back in
Athena) to remove the fitted change in E₀ from the problem. By removing
the parameter most correlated with ΔR, we significantly reduces the
uncertainty in ΔR.

I would not interpret all of this to mean that use of empirical
standards is superior to the use of Feff. In the specific case where the
first coordination shell is of known contents and can be well isolated
from higher shells and where you are confident that your unknown is
identical to your standard except for small changes in N, R, or σ², then
empirical standards are a useful tool for your EXAFS toolbox.

| 

--------------

--------------

| DEMETER is copyright © 2009-2015 Bruce Ravel — This document is
copyright © 2015 Bruce Ravel

|image12|    

| This document is licensed under `The Creative Commons
Attribution-ShareAlike
License <http://creativecommons.org/licenses/by-sa/3.0/>`__.
|  If DEMETER and this document are useful to you, please consider
`supporting The Creative
Commons <http://creativecommons.org/support/>`__.

.. |[Artemis logo]| image:: ../../images/Artemis_logo.jpg
   :target: ../diana.html
.. |image1| image:: ../../images/emp_athena.png
.. |image2| image:: ../../images/emp_rplot.png
   :target: ../../images/emp_rplot.png
.. |foo| image:: ../../images/emp_qplot.png
   :target: ../../images/emp_qplot.png
.. |image4| image:: ../../images/emp_export.png
.. |image5| image:: ../../images/emp_ptable.png
.. |image6| image:: ../../images/emp_importdata.png
.. |image7| image:: ../../images/emp_importes.png
.. |image8| image:: ../../images/emp_fitr.png
   :target: ../../images/emp_fitr.png
.. |foo| image:: ../../images/emp_gdsr.png
   :target: ../../images/emp_gdsr.png
.. |image10| image:: ../../images/emp_fitq.png
   :target: ../../images/emp_fitq.png
.. |foo| image:: ../../images/emp_gdsq.png
   :target: ../../images/emp_gdsq.png
.. |image12| image:: ../../images/somerights20.png
   :target: http://creativecommons.org/licenses/by-sa/3.0/
