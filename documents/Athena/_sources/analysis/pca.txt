.. _pca_sec:

Principle components analysis
=============================


.. todo:: Document all the buttons and whatnot. Document the many
   useful features are still missing.

.. todo:: Need a tutorial on math/science of PCA.  Explain what PCA
   means, what it does, and what it does not do.

---------------


Principle components analysis (PCA) is an abstract decomposition of a
data sequence....


Here, I have imported a project file containing well-processed data on a
time series of samples in which gold chloride is being reduced to gold
metal. The project file includes 8 time steps and 9 standards. I cannot
stress strongly enough the importance of doing a good job of aligning
and normalizing your data before embarking on PCA. This is truly a case
of garbage-in/garbage-out.

I then select the PCA tool from the main menu.

.. _fig-pca:

.. figure:: ../../_images/pca.png
   :target: ../_images/pca.png
   :width: 65%
   :align: center

   The PCA tool.

The operational concept for the PCA tool makes use of the standard
:demeter:`athena` group selection tools. The ensemble of marked groups
are used as the data on which the PCA will be performed. The selected
group (i.e.  the one highlighted in the group list) can be either
reconstructed or target transformed. The relevant controls will be
enabled or disabled depending on whether the selected group is marked
(and therefore one of the data sets in the PCA) or not (and therefore
a subject for target transformation).

Clicking the :button:`Perform PCA,light` button will perform
normalization on all the data as needed, then perform the components
analysis. Upon completion, some results are printed to the text box
and several buttons become enabled.

After the PCA completes, a plot is made of the extracted components.
This plot can be recovered by clicking the :guilabel:`Components`
button under the :guilabel:`Plots` heading. The number spinner is used
to restrict which components are plotted. Because the first component
is often so much bigger than the rest, it is often useful to set that
number to 2, in which case the first (and largest) component is left
off the plot.

Other plotting options include a plot of the data stack, as interpolated
into the analysis range, a scree plot (i.e. the eigenvalues of the PCA)
or its log, and the cumulative variance (i.e. the running sum of the
eigenvalues, divided by the size of the eigenvector space). The cluster
analysis plot is not yet implemented.

Once the PCA has been performed, you can reconstruct your data using 1
or more of the principle components. Here, for example, is the
reconstruction of an intermeidate time point using the top 3 components.

.. subfigstart::

.. _fig-pcacomponents:
   
.. figure:: ../../_images/pca_components.png
   :target: ../_images/pca_components.png
   :width: 100%
   :align: left

   The principle components of this data ensemble.	  
 
.. _fig-pcarecon:
   
.. figure:: ../../_images/pca_recon.png
   :target: ../_images/pca_recon.png
   :width: 100%
   :align: right

   PCA reconstruction

.. subfigend::
   :width: 0.45
   :label: _fig-pcabasics

Selecting one of the standards in the group list enables the
:button:`Target transform` button. Clicking it shows the result of the
transform and displays the coefficients of the transform in the
smaller text box.

.. _fig-pcatt:

.. figure:: ../../_images/pca_tt.png
   :target: ../_images/pca_tt.png
   :width: 65%
   :align: center

   Performing a target transform against a data standard


.. subfigstart::

.. _fig-pcattgood:

.. figure:: ../../_images/pca_tt_good.png
   :target: ../_images/pca_tt_good.png
   :width: 100%
   :align: center

   A successful target transform on Au foil. Au foil is certainly a
   constituent of the data ensemble used in the PCA.

.. _fig-pcattbad:

.. figure:: ../../_images/pca_tt_bad.png
   :target: ../_images/pca_tt_bad.png
   :width: 100%
   :align: center

   An unsuccessful target transform on Au cyanide. Au cyanide is
   certainly not a constituent of the data ensemble used in the PCA.

.. subfigend::
   :width: 0.45
   :label: _fig-pcattgoodbad


The list of chores still undone for the PCA tool can be found at `my
Github
site <https://github.com/bruceravel/demeter/blob/master/todo.org>`__.

