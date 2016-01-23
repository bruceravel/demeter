
Config object
=============

The Config object is a `singleton
object <http://en.wikipedia.org/wiki/Singleton_pattern>`__ which is used
to contain all of :demeter:`demeter`'s configuration parameters as well as
providing an simple way for user-defined parameters to be stored and
made available to the `templating system <dispose.html>`__.

At start-up, :demeter:`demeter` reads the :demeter:`demeter`
configuration files, then updates those values from the demeter.ini
file, which is stored in :file:`$HOME/.horae` on unix systems and in
:file:`%APPDATA%/demeter` on Windows systems.

To make the Config object readily accessible at all times in your
program, the ``co`` method is a method of the base class and is
inherited by all :demeter:`demeter` objects. Thus, given any object,
you can :quoted:`find` the Config object like so:

.. code-block:: perl

   $the_config_object = $any_object -> co;

Any method of the plot object is easily called by chaining with the
``co`` method. For example to get the configured default value for the
``bkg_rbkg`` attribute of the Data object, you do this

.. code-block:: perl

   $any_object -> po -> default('bkg', 'rbkg'); 

The configuration file format
-----------------------------

This is the configuration file for the parameters controlling the
back-Fourier transform of data. The format of the file is somewhat rigid
in order to simplify the parsing of these files.

.. code-block:: text

    ######################################################################
    section=bft
    section_description
      These parameters determine how backward Fourier transforms
      are done by Demeter.

    variable=dr
    type=real
    default=0.0
    units=Angstroms
    description
      The default width of the window sill used in the backward Fourier
      transform.  0 is used if this is set to less than 0.

    variable=rwindow
    type=list
    default=hanning
    options=hanning kaiser-bessel welch parzen sine
    description
      The default window type to use for the backward Fourier transform.

    variable=rmin
    type=real
    default=1
    units=Angstroms
    description
      The default value for the lower range of the backward Fourier
      transform.

    variable=rmax
    type=real
    default=3
    units=Angstroms
    description
      The default value for the upper range of the backward Fourier
      transform.


User-defined configuration files
--------------------------------


Using and resetting configuration parameters
--------------------------------------------


The Config object and the templating system
-------------------------------------------


WxWidgets and the configuration system
--------------------------------------

