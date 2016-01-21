
.. role:: guess
.. role:: def
.. role:: set
.. role:: lguess
.. role:: restrain
.. role:: skip
.. role:: after
.. role:: penalty
.. role:: merge

Guess/Def/Set Parameters
========================

In :demeter:`demeter`, every part of a fit is an object. The same is true of the
parameters of the fit. A new guess parameter is defined like so:


.. code-block:: perl

   my $new_param = Demeter::GDS->new(gds     => 'guess',
                                     name    => 'deltar',
                                     mathexp => 0.0); 

Every GDS object requires specifying these three attributes. The type
of parameter, denoted by the ``gds`` attribute, is explained in detail
below.  The ``name`` is the string that identifies the parameter and
is used in the math expressions for path parameters and other kinds of
GDS objects. In the case of a guess parameter, the ``mathexp`` is the
initial value of the parameter to be used at the start of the fit. For
other kinds of GDS ojbects, the ``mathexp`` attributes might take an
actual math expression, i.e. a character string to be interpreted and
evaluated by :demeter:`ifeffit`.

``gds``, ``name``, and ``mathexp`` are normal attributes of the GDS
object and can be treated like attributes of any object. So, for
instance, if you wish to change the starting valule of the ``deltar``
parameter, you can do like so:

.. code-block:: perl

   my $new_param = mathexp(0.025);

Here is another example, this time for a def parameter that takes an
actual math expression:

.. code-block:: perl

   my $new_param = Demeter::GDS->new(gds     => 'def',
                                     name    => 'c',
                                     mathexp => '(a + b) * tan(angle/2) / (a - b)'); 

 

Simplified interface
--------------------

Although the syntax for the GDS object is identical to the syntax for
all other :demeter:`demeter` objects, it seems somehow more cumbersome
in this case |nd| particularly for anyone who goes back to the good ol'
days of writing :file:`feffit.inp` files. As a bit of syntactic sugar,
the :demeter:`demeter` base class offers a method that takes a
character string as its sole argument. That character string is parsed
the same way as a parameter definition in a :file:`feffit.inp` file.

.. code-block:: perl

      my $new_param = $any_object->simpleGDS('guess deltar = 0.0'); 

The ``simpleGDS`` simply parses the string and uses that to create a GDS
object, which it then returns. The normal and simple syntax can be used
interchangeably and for all GDS types. They are completely equivalent.


Parameter types
---------------

There are 9 types of GDS parameters, that is, 9 possible values for
the ``gds`` attribute. Several of these will be familiar to users of
:demeter:`ifeffit` and :demeter:`artemis`, a few are newly introduced
by :demeter:`demeter`.

:guess:`guess`
    A parameter which is varied in a fit.

:def:`def`
    A parameter whose math expression is continuously updated throughout
    the fit.

:set:`set`
    A parameter which is evaluated at the beginning of the fit and
    remains unchanged after that.

:lguess:`lguess`
    A locally guessed parameter. In a multiple data set fit, this will
    be expanded to one :guess:`guess` parameter per data set. See `the section on
    local guess parameters <../lgcv.html>`__ for more details.

:restrain:`restrain`
    A restrain parameter is defined in an :demeter:`ifeffit` script as a :def:`def`
    parameter but is used as a restraint in the call to :demeter:`ifeffit`'s
    ``feffit`` command. In a multiple data set fit, all restraints are
    defined in the first call to the ``feffit`` command.

:skip:`skip`
    A skip is a parameter that is defined but then ignored. Setting a
    variable to a :skip:`skip` is useful in a GUI as a way of :quoted:`commenting out` a
    parameter without removing it from the fitting project.

:after:`after`
    This is like a :def:`def` parameter, but is not used in the fitting model
    and only evaluated when the fit finishes. It is then reported in the
    log file.

:penalty:`penalty`
    This is like a :def:`def` parameter, but is used as a user-defined penalty
    to the `happiness parameter <../fit/happiness.html>`__, which is
    evaluated at the end of the fit.  *This is not currently implemented.*

:merge:`merge`
    A merge is the type given to a parameter that cannot be
    unambiguously resolved when two Fit objects are merged into a single
    Fit object.  A fit cannot proceed until all merge parameters are
    resolved.  It is unlikely that a variable would ever be declared as a
    merge by a user, although if a user script makes use of any of
    :demeter:`demeter`'s (*as yet unimplemented*) project merging features, it will
    certainly be necessary to resolve a merge parameter by renaming it
    globally and resetting the ``gds`` attribute.

.. todo:: :penalty:`penalty` and :merge:`merge` types are currently unimplemented.


Reporting on and annotating GDS parameters
------------------------------------------

:demeter:`demeter` provides several ways of examining GDS objects. Along with
direct examination of the attributes, such as ``bestfit`` and ``error``,
there are several kinds of textual reports on the state of the GDS
object and its parameter. This example shows three of these:

.. code-block:: perl

    my $amp_param = Demeter::GDS -> new(gds     => 'guess',
                                        name    => 'amp',
                                        mathexp => 1);
    ## ... some time later, after a fit ...
    print $amp_param -> note, $/;
    print $amp_param -> report, $/;
    print $amp_param -> full_report, $/;

The ``note`` attribute contains the annotation. By default, the
annotation for a :guess:`guess` parameter is set after a fit using the
best fit value and the uncertainty, as shown below. For most other
parameter types, annotation is set using the evaluation of the
parameter as stored in the ``bestfit`` attribute.

::

    amp:   0.98096480 +/-   0.08074672

There is the option of annotating a parameter to a user-defined string.
When explicitly set, the automatic annotation after a fit finishes does
not happen. The purpose of the annotation is to store a description of
the purpose served in a fitting model by a parameter.  In the example
used here, you might annotate the parameter like so:

.. code-block:: perl

   $amp_param -> note("This parameter represents S_0^2."); 

The ``report`` method is used after a fit to write out parameter results
to a log file. It looks like this:

::

    amp                =   0.98096480    # +/-   0.08074672     [1]

The ``full_report`` writes out a more complete description of the state
of the object. It looks like this:

::

    amp
      guess parameter
      math expression: 1
      evaluates to   0.98096480 +/-   0.08074672
      annotation: "This parameter represents S_0^2."

