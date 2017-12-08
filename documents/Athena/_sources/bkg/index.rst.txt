..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. _bkg-chapter:

Normalization and background removal
====================================


The primary function of :demeter:`athena` is to import and process XAS
data. In the broadest sense, this task takes three steps:

-  Import raw data and convert it to |mu| (E).

-  Normalize the data so that the measurement is independent of the
   details of the sample or the detector setup.

-  Determine the background function and subtract it from the data to
   make |chi| (k).

Of course, there are many other details, such as calibration,
alignment, deglitching, and so on. Those will be discussed in detail
in later sections of the document. In this section, we will cover the
details of the normalization algorithm and the :demeter:`autobk`
background removal algorithm.  Special attention will be payed to the
most important background removal parameters.

For many measured |mu| (E) spectra, :demeter:`athena` will do a good
job of normalizing data and removing the background using its default
parameters. In other situations |nd| noisy data, data with large white
lines, data which terminate in the appearance of another edge |nd| user
intervention is required. for those situations it is important that
you understand well how the various parameters in the background
removal section of the main window affect the data.

----------------

.. toctree::
   :maxdepth: 2

   norm
   rbkg
   kweight
   range
   ednorm
   short
