..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: guess
.. role:: def
.. role:: after

After a fit
===========

After a fit finishes, each of the following tasks happens:

#. Best fit values and error bars are stored for each GDS object
   defining a :guess:`guess` parameter.

#. Final values are stored for each GDS object defining a :def:`def` parameter.

#. All :after:`after` parameters are evaluated.

#. The residual of the fit is calculated.

#. The statistics of the fit, including |chi|\ :sup:`2`, reduced
   |chi|\ :sup:`2`, R-factor, and all correlations between guess
   parameters are stored in the Fit object.

#. All path parameters are evaluated and stored in the Path objects.

#. The fit's :quoted:`happiness` (see the next section for details) is
   evaluated.

#. All GDS parameters flagged for automatic annotation are annotated.

All of that is a detailed way of saying that every object involved in
the fit is ready to be used for useful and interesting chores after
the fit.  All Data and Path objects are ready to be plotted.  The fit
can be saved a Fit serialization.  Column data files can be exported.
A log file can be written.  Any of the chores can happen with
confidence that every thing is completely up-to-date with the results
of the fit.

Picking up from the example of `the multiple data set fit
<collection.html>`__, the following example demonstrates how to
perform several of the common after-fit chores that might be part of a
fitting script.  The previous example demonstrated how to make an
interesting plot using the two data sets and their fits.

.. code-block:: perl
   :linenos:

    ### ... picking up at line 61 of the previous example ...

    ## do the fit
    $fit -> fit;

    ## write a log file
    my ($header, $footer) = ('', '');
    $fit -> logfile("cufit.log", $header, $footer);

    $fit -> freeze(file=>"cu_temperature.dpj");

    $data[0]->save("fit", "cu_10K.fit");
    $data[1]->save("fit", "cu_150K.fit");

    $fit -> interview;

**Log file**
    At line 8 a log file is written. The first argument of the
    ``logfile`` method is the name of the output log file. The other two
    arguments, both set to empty strings in this example, contain
    user-specified text that is written to the beginning and end of log
    file.
**Fit serialization**
    At line 10 the fit is serialized. This serialization file is simply
    a normal zip file containing the serializations of all the objects
    used in the fit along with a log file and a few other results of the
    fit. The convention is for this zip file to have the extension
    ``.dpj`` (i.e. :demeter:`demeter` project).
**Saving column data**
    At lines 12 and 13, the results of the fit to each data set are
    saved as column data files. These files contain columns with the k,
    data, the fit, the window, the residual, and the background function
    is it was corefined. See the `chapter on output
    formats <../output.html>`__ for more details on this and other
    column output formats.
**Fit interview**
    At line 15, the ``interview`` method is called. This is a simple
    terminal application for examining the results of the fit. The log
    file and statistical parameters of the fit can be examined using
    this application and simple plots can be made. The interview is a
    bare-bones tool. But it is a nice compromise between using a GUI
    and writing your own tools to examine the results of the
    fit. :demeter:`demeter` ships with a command line program called
    ``rdfit`` which is a wrapper around the ``interview`` method. It
    reads a ``.dpj`` file specified at the command line, imports it
    into a Fit object, then runs the ``interview`` method. The
    ``interview`` method and the ``rdfit`` program are described in
    more detail in `chapter on user interfaces <../ui.html>`__.

