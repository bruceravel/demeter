
Rebinning data groups
=====================

Some beamlines offer the option of slewing the monochromator
continuously from the beginning of the scan to the end. A typical
implementation of this works by driving the mono at a given speed and
reading the measurement channels continuously. The signal is
integrated for bins of time. After each time interval, the integrated
signals are stored in a buffer. At the end of the scan, the buffer is
dumped to disk. At my old beamline (`MRCAT, Sector 10 at the APS
<http://mrcat.iit.edu>`__), a typical EXAFS scan measured in this mode
takes 3 minutes or less.

The drawback of this measurement mode (other than the generation of tons
of data that needs to be analyzed!) is that the data are vastly over
sampled. The energy grid is typically 0.3 to 0.5 eV. That is fine in the
edge region, but much too fine for the EXAFS region.

.. _fig-rebintool:

.. figure:: ../../_images/rebin.png
   :target: ../_images/rebin.png
   :width: 65%
   :align: center

   The rebinning tool.

The tool shown above allows you to specify a simple three-region grid.
Typically, the pre-edge region is sparse in energy, the edge region is
fine in energy, and the EXAFS region is uniform in wavenumber. The
grid sizes and the energies of the boundaries are entered into their
entry boxes. You can view the results of the rebinning by pressing the
:button:`Plot data and rebinned data,light` button. The :button:`Plot data
and rebinned data in k,light` button displays the two spectra as
|chi| (k) using the background removal parameters of the unbinned
data. Clicking the :button:`Make rebinned data group,light` button
performs the rebinning and makes a new group. This group gets placed
in the group list and can be interacted with just like any other
group.

You can bulk process data by marking a number of groups and clicking
the :button:`Rebin marked data and make groups,light` button. This may
take a while, depending on how many groups are being processed.

This deglitching algorithm is the same as the one used by `the rebinning
feature <../import/preproc.html#rebinning-quick-scan-data>`__ of the column
selection dialog.

.. _fig-rebinplot:

.. figure:: ../../_images/rebin_plot.png
   :target: ../_images/rebin_plot.png
   :width: 45%
   :align: center

   Quick scan data that have been rebinned onto a normal EXAFS energy grid.

This uses a boxcar averaging to put the measured data on the chosen
grid. This has the happy effect of cleaning up fairly noisy data, as you
can see in the plot above.

