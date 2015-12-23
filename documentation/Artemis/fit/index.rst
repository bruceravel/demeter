..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Running a fit
=============

:demeter:`artemis` is, admittedly, a complex and non-intuitive
program. There are good reasons for :demeter:`artemis` being the way
it is, although those reasons may not be clear if you are coming to
the program for the first time. While it is important that easy things
be easy in :demeter:`artemis`, letting hard things be possible is
central to the intent of the program.

.. admonition:: The central premise of Ifeffit and Artemis
   :class: bigtrick

   The parameters of the EXAFS equation are not the parameters of the fit.
   The parameters of the EXAFS equation are written *in terms of* the
   parameters of the fit.

As a consequence, we have the GDS window where the parameters of the fit
are *defined* and the various Path pages where those parameters are
*used*.

It is instructive to understand a little bit about how the fitting model
is structured internally. The basic definition of a fit consists of
three things: (1) a list of one or more GDS parameters, (2) a list of
one or more data sets, and (3) a list of one or more paths. To make a
fit, all three of those lists must somehow be defined.

The list of data sets is taken from the Data list in the Main window.
All data sets in the Data list which have the :guilabel:`Include in
fit` button checked on will be used in the fit.

Each data set has a list of one or more paths associated with it. In
:demeter:`artemis` a path is associated with a data set by dragging
and dropping it onto a data set's path list. The contrapositive is
also true. All paths used in a fit must be associated with a Data set.

Paths typically come from a :demeter:`feff` calculation explicitly
initiated by the user. That is, the user imports an :demeter:`atoms`
input file, a :demeter:`feff` input file, or a CIF
file. :demeter:`feff` is run and the interpretation list is displayed
in the :demeter:`feff` window. Paths are dragged from that list and
dropped on a Data set. Thus paths are not only associated with a Data
set, they are also associated with a specific :demeter:`feff`
calculation.

Each path must have its path parameters set in some manner, even if they
are merely set to 0 or some other constant. Typically, path parameters
are set to math expressions which depend functionally upon one or more
parameters from the GDS page. Every GDS parameter used in a path
parameter math expression must be defined on the GDS window. Similarly,
every guess or def parameter from the GDS window must be used in at
least one math expression in your fitting model.

All paths which have their :guilabel:`Include in fit` button checked
on will be used in the fit.

When the fit begins, :demeter:`artemis` digs through all the windows,
finding all data sets, paths, and GDS parameters. It runs a number of
sanity checks to avoid certain obvious situations which will result in
an unsuccessful fit. It then makes sure that all of
:demeter:`ifeffit`'s data structure are up to date with respect to
your current settings in :demeter:`artemis`. The fit is run.
Statistics, including error bars and correlations, are calculated. A
log file is written, a plot is made, and the various colored buttons
are set according to the fit happiness.

That's a fit!

There are some details of the fitting process that are
`configurable <../prefs.html>`__. For instance, the log file can be
displayed in either the Log window or in the History window after the
fit finishes. You can also choose not to have it display automatically.
This is set by :configparam:`Artemis,show_after_fit`.

The plot that is made upon completion of the fit is also configurable.
The default is to have `an Rmr plot <../data.html#thermrplot>`__ made
containing the data and the fit. Any of the five plot types from the
Data window can be chosen as the after-fit plot. You may also choose
to have the contents of the plotting list plotted in k-, R-, or
q-space.  This adds value to the :guilabel:`Plot after fit` buttons on
the Data window and Path pages. You may also choose to have no plot
displayed automatically after the fit. This is set by
:configparam:`Artemis,plot_after_fit`.

The fit name and fit description text boxes from the Main window are
also useful for customizing your fit as well as the course of a fitting
project. The fit name is used in many places – most notably in the
legends of plots. Thus you may find it useful to select descriptive
names for each of your fits. The fit description is written to every log
file and can be used to document features of your current fitting model
and how it relates to the development of your fitting project.

-----------------

.. toctree::
   :maxdepth: 2

   sanity.rst
   happiness.rst
   pathlike.rst

