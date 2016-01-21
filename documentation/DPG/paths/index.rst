Scattering paths
================

This chapter explains how to use the results of a :demeter:`feff`
calculation. The Path object is the component of a fitting model that
encapsolates the contribution from an individual scattering
geometry. Here is an example of a typical Path object:

.. code-block:: perl
   :linenos:

    my $paths = Demeter::Path -> new(parent => $feff_object,
                                     data   => $data_object,
                                     sp     => $sp_object,
                                     s02    => "amp",
                                     e0     => "enot",
                                     delr   => "deltaa",
                                     sigma2 => "ssn",
                                    );

In lines 4 through 7, the path parameters are set using the names of
`GDS parameters <../gds/index.html>`__. More information about setting
and querying path parameter values `later in this
chapter <pathparams.html>`__.

Lines 1 through 3 show the hierarchy of the Path object. The Path object
relies upon connections to :demeter:`demeter` objects to do its work.

``parent``
    At line 1, the :quoted:`parent` `Feff object <../feff/index.html>`__. is
    identified. The parent is the Feff object that was used to run the
    :demeter:`feff` calulcation that generated this scattering path. The Path
    object needs to know

``data``
    At line 2, the `Data object <../feff/index.html>`__ containing the
    data for which this scattering path is being used to model. This
    connection is required for two reasons. The `Fit
    object <../feff/index.html>`__ uses this linkage to properly create
    the :demeter:`ifeffit` commands involved in running the fit. The other use of
    the Data object connection is to plot the Path object properly. The
    Fourier transform parameters of the Data object are used to process
    the scattering path for plotting.

    The ``data`` attribute is not stricly required. When :demeter:`demeter` is
    imported at the beginning of your program, a `default Data
    object <../highlevel/methods.html>`__ is created using a sensible
    set of processing parameters. If the ``data`` attribute is not
    explicitly set, the default Data object is used. This allows you to
    sensibly plot scattering paths without actually importing data into
    a Data object. When using a Path object as part of a simulation or a
    fit, it is important to properly identify the ``data`` attribute so
    that the path is Fourier transformed in the same manner as its
    associated data.


``sp``
    The final part of the Path object's hierarchy is shown in line 3.
    The ScatteringPath object is the thing that links the :demeter:`feff`
    calculation with the Path object. This is explained in detail in
    `the next section <paths.html>`__. As it might seem confusing that
    two different objects are involved in defining a scattering path,
    here is the way to think about it. The Path object is outward
    expression of the scattering path and is intended to resemble a path
    paragraph in a :file:`feffit.inp` file or a ``path`` command in an :demeter:`ifeffit`
    script. The ScatteringPath object is aware of all the details of the
    path finder and encapsolates the results of the :demeter:`feff` calculation,
    much like the :file:`feffNNNN.dat` but with lots of object-oriented
    functionality surrounding it.

---------------------

**Contents**

.. toctree::
   :maxdepth: 2

   paths.rst
   semantic.rst
   pathparams.rst
   plot.rst
   existing.rst

