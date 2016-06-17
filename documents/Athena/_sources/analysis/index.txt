..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Data analysis
=============

:demeter:`athena` provides various kinds of data analysis. None of the
data analysis capabilities in :demeter:`athena` require the use of
:demeter:`feff`. Analysis of data using :demeter:`feff` is a huge
topic and is the purpose of the :demeter:`artemis` program. The data
analysis techniques included in :demeter:`athena` are all purely
empirical. While there is no substitute for careful, sophisticated
analysis of EXAFS data using theory from :demeter:`feff`, often the
empirical techniques described in this chapter are adequate to answer
the questions you have about your data.

:demeter:`athena`'s analysis tools are accessed from the analysis
section of the main menu, as shown below.

.. _fig-analysis:

.. figure:: ../../_images/analysis.png
   :target: ../_images/analysis.png
   :align: center

   The data analysis tools in the main menu.


.. versionadded:: 0.9.25 
   The states of the LCF, PCA, and peak fitting tools are now saved in
   the project file.  These states will be restored from a project
   file if (and only if) the entire project file is imported.
   Importing only a subset of the groups in the project file will *not*
   trigger the import of the analysis states.

   In each case, only the *model* is imported, not the results of the
   analysis.  You will likely want to re-run the analysis after
   importing the project file with saved state for the analysis.

   The recording of these states is turned on and off (default is on)
   by the :configparam:`Athena,analysis_persistence` configuration
   parameter.  The reason you may want to disable saving state of the
   analysis tools is that importing from a project file containing
   that information can change the state of the group list and
   possibly other aspects of :demeter:`athena`.  

   Note that the project files with saved state for the analysis tools
   *should* be backwards compatible to earlier versions.  Please file
   `a bug report
   <http://bruceravel.github.io/demeter/documents/SinglePage/bugs.html>`_
   if this is not the case.

----------------

.. toctree::
   :maxdepth: 2

   lcf
   pca
   peak
   lr
   diff
