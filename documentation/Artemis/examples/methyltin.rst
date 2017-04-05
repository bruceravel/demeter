..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


.. |transfer button| image:: ../../_static/plot-icon.png

.. role:: guess
.. role:: def
.. role:: set
.. role:: restrain
.. role:: after

Example 2: Methyltin
====================


Some years ago, some colleagues from the U.S. Environmental Protection
Agency came to me with an interesting problem about the fate and
transport of organic tin compounds through sewage systems.  In the
U.S. (and elsewhere), municipal water is carried into homes and office
buildings with copper pipes and waste water is transported to the
water treatment system in polyvinyl chloride (PVC) pipes.  By itself,
PVC is a highly malleable plastic.  Like many plastics, it is made
stiff by the addition of stiffening agents added to the plastic
matrix.  In the case of PVC, organic tin compounds are used.

The folks from the EPA were studying the accumulation of tin in
municipal waste and trying to understand if there was a mechanism of
transport involving leaching from PVC pipes.  We made a series of XAS
measurements on various organic tin standards as well as direct
measurement of PVC pipes produced by three different manufacturers.

.. bibliography:: ../artemis.bib
   :filter: author % "Impellitteri"
   :list: bullet

Two of the standard compounds we measured were methyltin chloride, as
shown below.

.. subfigstart::

.. _fig-dimethyltindichloride:
.. figure::  ../../_images/dimethyltin_dichloride.png
   :target: ../_images/dimethyltin_dichloride.png
   :width: 50%
   :align: center

   Dimethyltin dichloride |nd| one tin atom with two carbon ligands (in
   the form of methyl groups) and two chlorine ligands.

.. _fig-monomethyltintrichloride:
.. figure::  ../../_images/monomethyltin_trichloride.png 
   :target: ../_images/monomethyltin_trichloride.png 
   :width: 50%
   :align: center

   Monomethyltin trichloride |nd| one tin atom with two carbon ligands
   and two chlorine ligands.

.. subfigend::
   :width: 0.45
   :label: _fig-methyltinchloride

These samples were prepared in solution.  This solution was packed
into a simple transmission sample cell for liquids.  Transmission
EXAFS were measured.  Here is the data:

.. subfigstart::

.. _fig-mtinmu:
.. figure::  ../../_images/mtin_mu.png
   :target: ../_images/mtin_mu.png
   :width: 100%

   |mu|\ (E) data measured on the dimethyltin dichloride and
   monomethyltin trichloride.

.. figure::  ../../_images/mtin_chik.png
   :target: ../_images/mtin_chik.png
   :width: 100%

   |chi|\ (k) data measured on the dimethyltin dichloride and
   monomethyltin trichloride.

.. figure::  ../../_images/mtin_chir.png
   :target: ../_images/mtin_chir.png
   :width: 100%

   |chi|\ (R) data measured on the dimethyltin dichloride and
   monomethyltin trichloride.

.. subfigend::
   :width: 0.30
   :label: _fig-mtindata

These data are quite similar, but there is a distinct change in the
|chi|\ (R) spectrum between the two.

In this section, we will step through the corefinement of these two
data steps, creating a constrained fitting model that uses the
information content of both data sets to allows excellent measurement
of a number of structural parameters.

You can find example EXAFS data and a structure from which to build
the :file:`feff.inp` file at `my XAS Education site
<https://github.com/bruceravel/XAS-Education/tree/master/Examples/Methyltin>`_.
Import the |mu| (E) data into :demeter:`athena`.  When you are content
with the processing of the data, save an :demeter:`athena` project
file and dive into this example.




Import data
-----------

After starting :demeter:`artemis`, :mark:`leftclick,..` click on the
:button:`Add,light` button at the top of the :guilabel:`Data sets`
list in the Main window. This will open a file selection dialog.
Click to find the :demeter:`athena` project file containing the data
you want to analyze.  Opening that project file displays the project
selection dialog.

.. _fig-methyltinimportdata:
.. figure:: ../../_images/methyltin-importdata.png
   :target: ../_images/methyltin-importdata.png
   :width: 50%
   :align: center

   Import data into :demeter:`artemis`

The project file used here has the data from both methyltin standards.
Select :quoted:`Dimethyl Tin` from the list.  That data set gets
plotted when selected.

Now :mark:`leftclick,..` click the :button:`Import,light` button. That
data set gets imported into :demeter:`artemis`.  An entry for the
dimethyl tin is created in the Data list, a window for interacting
with the dimethyl tin data is created, and the dimethyl tin data are
plotted as |chi| (k).


The next step is to import some structural data that can be used to
make the :demeter:`feff` calculation.  Since this is a solution
standard, there is obviously not an :file:`atoms.inp` file.  So we
need to find another way to create the :file:`feff.inp` file.

A bit of searching on Google eventually turned up the following
structural information for dimethyltin dichloride in the form of a
Protein Data Bank file.  PDB is a format that is usually used to store
structural data for large macromolecules, but is also quite suitable
to tiny molecules like our methyl tin sample.  This example has some
chaff that is not of interest to us for our EXAFS analysis problem,
but among the chaff is **all** the information we need.

.. code-block:: text

   COMPND    5261536
   HETATM    1  C1  LIG     1      -0.027   2.146   0.014  1.00  0.00
   HETATM    2 SN2  LIG     1       0.002  -0.004   0.002  1.00  0.00
   HETATM    3  C3  LIG     1       1.042  -0.716   1.744  1.00  0.00
   HETATM    4 CL4  LIG     1      -2.212  -0.821   0.019  1.00  0.00
   HETATM    5 CL5  LIG     1       1.107  -0.765  -1.940  1.00  0.00
   HETATM    6 1H1  LIG     1       0.996   2.523   0.006  1.00  0.00
   HETATM    7 2H1  LIG     1      -0.554   2.507  -0.869  1.00  0.00
   HETATM    8 3H1  LIG     1      -0.537   2.497   0.911  1.00  0.00
   HETATM    9 1H3  LIG     1       0.532  -0.365   2.641  1.00  0.00
   HETATM   10 2H3  LIG     1       1.057  -1.806   1.738  1.00  0.00
   HETATM   11 3H3  LIG     1       2.065  -0.339   1.736  1.00  0.00
   END

Note that columns 6, 7, and 8 contain the Cartesian coordinates of the
tin, chlorine, carbon, and hydrogen atoms that make up the dimethyltin
dichloride molecule.  The third column identifies which atomic species
lives at each of the sites.  Perfect!

A bit of cutting and pasting into en empty template for a
:file:`feff.inp` file, resulted in the following:

.. code-block:: text

   TITLE dimethyltin dichloride

   HOLE 1   1.0   *  Sn K edge  (29200.0 eV), second number is S0^2

   *         mphase,mpath,mfeff,mchi
   CONTROL   1      1     1     1
   PRINT     1      0     0     0

   RMAX        6.0

   *CRITERIA     curved   plane
   *DEBYE        temp     debye-temp
   NLEG         4

   POTENTIALS
   *    ipot   Z  element
         0   50   Sn        
         1   17   Cl
         2    6   C
         3    1   H

   ATOMS
   *   x          y          z      ipot  tag              distance
     -0.027   2.146   0.014  2
      0.002  -0.004   0.002  0
      1.042  -0.716   1.744  2
     -2.212  -0.821   0.019  1
      1.107  -0.765  -1.940  1
      0.996   2.523   0.006  3
     -0.554   2.507  -0.869  3
     -0.537   2.497   0.911  3
      0.532  -0.365   2.641  3
      1.057  -1.806   1.738  3
      2.065  -0.339   1.736  3

This was saved to disk, then imported into :demeter:`artemis` by
:mark:`leftclick,..` left clicking on the line in the Data window that
says :guilabel:`Import crystal data or a Feff calculation`, then
selecting our :file:`feff.inp` file from the column selection dialog.


.. _fig-methyltinimportfeff:
.. figure:: ../../_images/methyltin-importfeff.png
   :target: ../_images/methyltin-importfeff.png
   :width: 50%
   :align: center

   Importing information for making the :demeter:`feff` calculation.

With the methyltin structural data imported, run :demeter:`feff` by
:mark:`leftclick,..` clicking the :button:`Run Feff,light` button
to compute the scattering potentials and to run the pathfinder.

Once the :demeter:`feff` calculation is finished, the path
intepretation list is shown in the Paths tab. This is the list of
scattering paths, sorted by increasing path length. Select the first
2 paths by :mark:`leftclick,..` clicking on the path
:guilabel:`0000`, then :button:`Control`-:mark:`leftclick,..` clicking
on path :guilabel:`0002`.  The selected paths will be highlighted.
:mark:`leftclick,..` Click on one of the highlighted paths and,
without letting go of the mouse button, :mark:`drag,..` drag the paths
over to the Data window and drop them onto the empty Path list.

.. _fig-methyltinpathsdnd:
.. figure:: ../../_images/methyltin-pathsdnd.png
   :target: ../_images/methyltin-pathsdnd.png
   :width: 50%
   :align: center

   :mark:`drag,..` Drag and drop paths onto a data set

:mark:`drag,..` Dropping the paths on the Path list will associate
those paths with that data set. That is, that group of paths is now
available to be used in the fitting model for understanding the
methyltin data.

Each path will get its own Path page. The Path page for a path is
displayed when that path is clicked upon in the Path list. Shown below
is the dimethyltin dichloride data with 2 paths.  The first path in
the list, the one representing the contribution to the EXAFS from the
C single scattering path nominally at 2.150 |AA|, is currently displayed.
The second path represents the contribution to the EXAFS from the Cl
single scattering path nominally at 2.360 |AA|.


.. _fig-methyltinpathsimported:
.. figure:: ../../_images/methyltin-pathsimported.png
   :target: ../_images/methyltin-pathsimported.png
   :width: 50%
   :align: center

   Paths associated with a data set 



Examine the scattering paths
----------------------------

The first chore is to understand how these two paths from the
:demeter:`feff` calculation relate to the data.  To this end, we need
to populate the Plotting list with data and paths and make some plots.

Mark single scattring paths for the C and Cl by :mark:`leftclick,..`
clicking on their check buttons.  Transfer those two paths to the
Plotting list by selecting :menuselection:`Actions --> Transfer
marked`.

With the Plotting list poluated as shown below, :mark:`leftclick,..`
click on the :button:`R,light` plot button in the Plot window to make
the plot shown.

.. _fig-methyltinsspaths:
.. figure:: ../../_images/methyltin-sspaths.png
   :target: ../_images/methyltin-sspaths.png
   :width: 50%
   :align: center

   Methyltin data plotted with the first four single scattering paths


These two paths reasonably might represent the peak in the dimethyltin
dichloride data, although it is not clear how the lower part of that
peak will be represented by these two paths.  It is instructive also
to look at the data as the real part of the Fourier transform.  To do
so, :mark:`leftclick,..` click the :guilabel:`Real` radiobutton under
:guilabel:`Plot`\ |chi|\ :guilabel:`(R)` in the Plotting window.  This
will display the following plot:

.. _fig-methyltinsspathschir:
.. figure:: ../../_images/methyltin-sspaths_chir.png
   :target: ../_images/methyltin-sspaths_chir.png
   :width: 50%
   :align: center

   The data and two paths, plotted as Re[\ |chi|\ (R)].

Viewed this way, it is clear that this :demeter:`feff` calculation is
likely to do a good job fitting these data.  The missing spectral
weight at low R could likely be recovered by a |Delta|\ R shift of the
the C scatterer to lower R.

Fit to the dimethyltin dichloride data
--------------------------------------

As in many fits, we will use a single parameter to represent the 
S\ :sup:`2`\ :sub:`0` for each path.  This is reasonable as this is a
parameter of the absorber and we are making only one :demeter:`feff`
calculation in this fit.  For the same reason, we will use a single 
E\ :sub:`0` parameter for each path.  We don't have any *a priori*
knowledge of how the Sn-C and Sn-Cl bonds might be related.  As a
result, we will float independent |Delta|\ R and |sigma|\ :sup:`2` for
the two ligands.  This results in 6 fitting parameters.

#. Make sure both the C and Cl paths are included in the fit.  That
   is, each should have its :guilabel:`Include path` button checked.

#. Set the values of R\ :sub:`min` and R\ :sub:`max` to cover just the
   first peak.  1 |AA| to 2.4 |AA| is a good choice.

#. We need parameters to represent S\ :sup:`2`\ :sub:`0` and E\
   :sub:`0`.  The parameters ``amp`` and ``enot`` are defined in the GDS
   window and given sensible initial :guess:`guess` values.

#. We need |Delta|\ R and |sigma|\ :sup:`2` for each ligand type.
   The |Delta|\ R parameters are called ``drc`` and ``drcl``.  The
   |sigma|\ :sup:`2` are called ``ssc`` and ``sscl``.


.. _fig-dimethyltinmodel:
.. figure:: ../../_images/methyltin-dmt-model.png
   :target: ../_images/methyltin-dmt-model.png
   :width: 50%
   :align: center

   Six parameters are defined and used as path parameters.

At this point we are ready to :mark:`leftclick,..` click the big fit
button.  Doing so yields the following:

.. _fig-dimethyltinfit:
.. figure:: ../../_images/methyltin-dmt-fit.png
   :target: ../_images/methyltin-dmt-fit.png
   :width: 50%
   :align: center

   Fit to the dimethyltin dichloride data using the simple,
   6-parameter fitting model.

Glancing at the plot window, this looks like a decent enough fit.
Examining the log file, we find that the fit is fairly well
interpretable.

#. The S\ :sup:`2`\ :sub:`0` value is 1.27 |pm| 0.28, which is rather
   larger than expected

#. E\ :sub:`0` is 4.1 |pm| 2.5 eV, a reasonable value which suggests
   that E\ :sub:`0` was chosen reasonably in :demeter:`athena`.

#. As expected, |Delta|\ R for the C ligand is negative and fairly
   large at -0.057 |pm| 0.036 |AA|.  The |Delta|\ R for the Cl ligand
   is positive, but consistent with zero, 0.020 |pm| 0.024 |AA|.

#. Both |sigma|\ :sup:`2` values are of a reasonable size, 0.00291
   |pm| 0.00542 |AA|\ :sup:`2` for C and 0.00595 |pm| 0.00366 |AA|\
   :sup:`2` for Cl.

Note, however, that the information content of this fit is being
heavily strained.  With a k-range of 2 |AA|\ :sup:`-1` to 10.5 |AA|\
:sup:`-1` and an R-range of 1 |AA| to 2.4 |AA|, there are only about
7.4 independent measurements in these data.  The six parameters
floated in this fit are a significant burden on these data.

The benefit of multiple k-weight fitting
----------------------------------------

Before extending this fitting project to consider corefinement of the
two methyltin data sets, let us pause and consider the merits of
multiple k-weight fitting.

The default in :demeter:`artemis` is to perform the fit with
k-weighting of 1, 2, **and** 3.  The implementation of this is quite
simple.  The normal |chi|\ :sup:`2` fitting metric is evaluated for
each value of k-weighting considered.  The sum of all these |chi|\
:sup:`2` evaluations is then minimized to produce the fit.  The
advantage of doing this can be seen when considering the impact of the
various path parameters on the EXAFS equation.

A |sigma|\ :sup:`2` parameter is always multiplied by k\ :sup:`2` in
the EXAFS equation.  Thus the portion of the fitting metric evaluated
at high k is much more sensitive to a poorly chosen value of |sigma|\
:sup:`2` than the portion evaluated at low k.  Since a k-weighting of
3 amplifies the value of the data (and theory) more and more as k
increases, evaluating the fit with a k-weight of 3 will provide more
sensitivity to |sigma|\ :sup:`2` parameters.  The other amplitude
parameter, S\ :sup:`2`\ :sub:`0`, affects all regions of the k-range
equally.

Similarly, |Delta|\ R is multiplied by k in the EXAFS equation, thus
the evaluation of the fitting metric at high k is much more sensitive
to a poorly chosen value.  E\ :sub:`0`, on the other hand, has a much
bigger impact on the evaluation of the fitting metric at *low* k.
Thus a k-weight of 3 will provide greater sensitivity to |Delta|\ R in
the fit while a k-weight of 1 will provide a greater sensitivity to E\
:sub:`0`.

One might think, then, that a k-weight of 2 would be a good compromise
between the demands of the various parameters.  Let's check that out.

To perform a fit with just k-weight of 2, :mark:`leftclick,..` unclick
the :guilabel:`1` and :guilabel:`3` buttons as shown in
:numref:`Fig. %s <fig-dimethyltinfitkw2>`.

.. _fig-dimethyltinfitkw2:
.. figure:: ../../_images/methyltin-fitkw2.png
   :target: ../_images/methyltin-fitkw2.png
   :align: center

   Changing the fitting k-weight so that the fit is made only with
   k-weight equal to 2.


We :mark:`leftclick,..` click the big fit button and a minute later we
see this:

.. _fig-dimethyltinfitwithkw2:
.. figure:: ../../_images/methyltin-fit-with-kw2.png
   :target: ../_images/methyltin-fit-with-kw2.png
   :width: 50%
   :align: center

   The result of the fit using k-weight of 2.


On the surface, this appears to be a comparable fit to the one made
with multiple k-weighting.  The quality of the plot is similar, as is
the value of R-factor.  Closer examination of the fitting parameters
turns up a number of serious problems.

#. The value of S\ :sup:`2`\ :sub:`0` is 3.26 |pm| 1.38!  The result
   with multiple k-weight fitting was also greater than 1, but could
   possibly be explained as a problem of sample preparation or mean
   free path.  This value is just nonphysically enormous.

#. To compensate for the large S\ :sup:`2`\ :sub:`0`, the values for
   |sigma|\ :sup:`2` are also unreasonably large, 0.05444 |pm| 0.03785
   |AA|\ :sup:`2` for C and 0.01785 |pm| 0.00562 |AA|\ :sup:`2` for Cl.

The effect of these hard-to-understand values for S\ :sup:`2`\
:sub:`0` and |sigma|\ :sup:`2` can be seen in :numref:`Fig. %s
<fig-mtinfitkw2>`.  Both contributions are very broad, as expected
given their large values for |sigma|\ :sup:`2`.  This is in contrast
to the contributions from the multiple k-weight fit shown in
:numref:`Fig. %s <fig-mtinfitmkw>`, where they are of a width that
seems more reasonable for tightly bound ligands.

.. subfigstart::

.. _fig-mtinfitmkw:
.. figure::  ../../_images/mtin_fit_mkw.png
   :target: ../_images/mtin_fit_mkw.png
   :width: 100%
   :align: center

   The C and Cl contributions to the multiple k-weight fit.

.. _fig-mtinfitkw2:
.. figure::  ../../_images/mtin_fit_kw2.png
   :target: ../_images/mtin_fit_kw2.png
   :width: 100%
   :align: center

   The C and Cl contributions to the fit using k-weight of 2.

.. subfigend::
   :width: 0.45
   :label: _fig-mtin_fit_kw


In this situation, where the number of :guess:`guess` parameters is
such a large fraction of the total information content of the data,
the use of multiple k-weight fitting is essential.  The added
sensitivity to the various regions of k-space afforded by the
evaluation of the fitting metric with different k-weight values helps
reduce the very high correlations between the S\ :sup:`2`\ :sub:`0`
and |sigma|\ :sup:`2` parameters, resulting in a much more defensible
fit.

Corefining multiple data sets
-----------------------------

The solution to the problem of the number of :guess:`guess` parameters
being so close to the number of independent points is to expand the
bandwidth of the data.  This is often done by extending the fitting
model to include higher coordination shells, then importing and
parameterizing additional :demeter:`feff` paths to account for the
structure at higher R.  In this case, that will not work.  These data
have very little structure beyond about 2.5 |AA|.  In this case, what
we have fit so far is all there is to the data.

Another way of increasing the information content is to corefine
multiple data sets.  Adding a second data can double the information
content of the fitting model.  If the fitting model can be made to
accommodate the new data set without doubling the number of
:guess:`guess` parameters, the model should be more robust.

In this case, we will double the information content by adding the
monomethyltin trichloride to the project |nd| both methyltin data sets
were measured over the same k-range and consist of a single peak
in R.  If we assume that the sate of the Sn atom is the same in both
materials and we take care to align the data well in
:demeter:`athena`, then we will not need to introduce new parameters
for S\ :sup:`2`\ :sub:`0` or E\ :sub:`0`.

If we further assume that the nature of the Sn-C and Sn-Cl bonds are
very similar in the two forms of methyltin, then we can reuse the
|Delta|\ R and |sigma|\ :sup:`2` parameters for the C and Cl
scatterers.

Thus we can double the information content of the fit while adding *no
new parameters*!

To start, use the file selection dialog to again open the
:demeter:`athena` project file containing the methyltin data.  Select
the monomethyltin data.  This will import the second data set, add it
to the :guilabel:`Data sets` list in the main window, and create a
Data window for monomethyltin.  All of this is shown in
:numref:`Fig. %s <fig-methyltinmdsimport>`.

.. _fig-methyltinmdsimport:
.. figure:: ../../_images/methyltin-mds-import.png
   :target: ../_images/methyltin-mds-import.png
   :width: 50%
   :align: center

   Importing the monomethyltin trichloride data into the fitting project.

Re-open the window containing the :demeter:`feff` calculation, then
:mark:`drag,..` drag and drop the same two paths onto the
monomethyltin window.

.. _fig-methyltineditn:
.. figure:: ../../_images/methyltin-edit-N.png
   :target: ../_images/methyltin-edit-N.png
   :align: center

   Reuse the :guess:`guess` parameters from before, but change the
   coordination numbers for C and Cl to 1 and 3, respectively.

Edit the path parameters so that the paths in the new monomethyltin
window use the same parameters for S\ :sup:`2`\ :sub:`0`, E\ :sub:`0`,
|Delta|\ R, and |sigma|\ :sup:`2` as were used for the dimethyltin.

To account for the different numbers of C and Cl ligands, the N path
parameters must be changed to 1 for C in the dimethyltin data window
and 3 for the Cl.

Make sure the R-range is set sensibly.  You are now ready to hit the
big fit button.


.. subfigstart::

.. _fig-mtinmdsfitm:
.. figure::  ../../_images/mtin_mdsfit.png
   :target: ../_images/mtin_mdsfit.png
   :width: 100%
   :align: center

   The data and fitted paths for the multiple data set fit to the
   dimethyltin and monomethyltin data.

.. _fig-mtinmdslog:
.. figure::  ../../_images/mtin_mdslog.png
   :target: ../_images/mtin_mds_log.png
   :width: 100%
   :align: center

   The log file from the multiple data set fit to the
   dimethyltin and monomethyltin data.

.. subfigend::
   :width: 0.45
   :label: _fig-mtin_mdsfit


This is a decent fit.  The :guess:`guess` parameters are mostly
reasonable, although the S\ :sup:`2`\ :sub:`0` parameter is still
somewhat large.  E\ :sub:`0`, |Delta|\ R, and |sigma|\ :sup:`2` values
are all defensible.  The uncertainties on most of the parameters are
smaller than in earlier fits.  Most importantly, we are not stressing
the information content of the data so severely by fitting 6
parameters.  

My having more unused information available, we can explore other
possibilities in these data that would not have been possible in the
single data set fit.  For example, we could examine the impact of the
H single scattering paths on the fit or we could try lifting the
constrains on the |Delta|\ R and |sigma|\ :sup:`2` parameters of the
two ligand types.



Further exploration
-------------------


#. Could the Fourier transform range be longer?  Look at the `k123
   plot <../data.html#special-plots>`_ for each data set.

#. Could the fitting range be longer?  Well, there is not much signal
   beyond the first shell above the noise level.  Simply expanding the
   R-range to make N\ :sub:`idp` larger without actually including
   signal is cheating.

#. Is the assumption about the bonds in the two samples valid?  How
   would you go about testing that assumption?

#. Trimethyltin monochloride would have been a useful measurement....

#. The |Delta|\ Rs for both Sn-C and the Sn-Cl are somewhat large.
   The fit might be improved by adjusting the original
   :file:`feff.inp`, re-running :demeter:`feff`, and re-doing the fit.

#. The structure used in the :demeter:`feff` calculation is unbounded
   from the outside, which might effect the construction of muffin
   tins.  Packing water molecules around the DMT molecule might help.

#. Is the dimethyltin feff calculation really transferable to
   monomethyltin?  You could test this by finding or creating a
   structure for monomethyltin trichloride and running :demeter:`feff`
   on that.
