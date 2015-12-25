..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: guess
.. role:: def
.. role:: set
.. role:: lguess


Characteristic value
====================

At the top of `the Data window <../data.html>`__ is the control for
setting the *characteristic value*, or *CV*, of a data group. In this
section, the purpose and use of the CV is explained.

The CV is a user-defined number which is associated with the data set
and is used for special purposes when evaluating the math expressions
associated with :def:`def` and path parameters. By default,
:demeter:`artemis` simply increments the CV value for each data set
imported |nd| the first is set to 1, the second to 2, and so on. These
values can be changed, but should always be integer-valued.

The CV value is used in two ways to construct rich math expressions and
expressive fitting models.



The CV token
------------

Consider a multiple data set fit to a material measured at various
temperatures. For this discussion, let's consider a rock salt structured
metal oxide, for instance ZnO. Let's also suppose that we have measured
data at three temperatures, 10 K, 300 K, and 500 K.

In a multiple data set fit, you may choose to model the |sigma|\
:sup:`2` of the first shell Zn-O bond using an Einstein model. This
allows you to parameterize the |sigma|\ :sup:`2` at each temperature
as a function of a single variable parameter, the Einstein
temperature. To do this, you must define a :guess:`guess` parameter to
represent the Einstein temperature like so:

::

    guess thetae = 500

The functional form of the Einstein model takes the variable Einstein
temperature and the sample's measurement temperature as its arguments.

.. bibliography:: ../artemis.bib
   :filter: author % "Sevillano"
   :list: bullet


::

    path {
           sigma2 = eins(temp, thetae)
    }

where ``temp`` represents the sample temparature. The pseudo-syntax
used here is simply meant to represent the |sigma|\ :sup:`2` parameter
on a `the Path page <../path/index.html>`__.

In a multiple data set fit, you would have to take care that ``temp`` is
replaced each time it is used. That could be done in two ways. You could
use various :set:`set` parameters:

::

    set temp1 = 10
    set temp2 = 300
    set temp3 = 500

    path for data set 1 {
           sigma2 = eins(temp1, thetae)
    }
    path for data set 2 {
           sigma2 = eins(temp2, thetae)
    }
    path for data set 3 {
           sigma2 = eins(temp3, thetae)
    }

Or you could simply state the temperature explicitly in the path
parameter math expressions:

::

    path for data set 1 {
           sigma2 = eins(10,  thetae)
    }
    path for data set 2 {
           sigma2 = eins(300, thetae)
    }
    path for data set 3 {
           sigma2 = eins(500, thetae)
    }

Both of those solutions work. But neither make effective use of the
model building automation in :demeter:`artemis`. In the chapter on
`the Path window <../path/mathexp.html>`__, you learned about various
ways of pushing path parameter values onto other paths. One efficient
way of setting up a multiple data set fit would be to edit the path
parameters for one of the data sets, then push the path parameters
onto the other data sets.

Using the two strategies summarized above, you would need to do
considerable editing after pushing the path parameter values. That sort
of editing is often error-prone.

Here is a third way of solving this problem.

#. Set the CV for the three data sets to the temperature at which the
   data were measured. In our example, the three data sets would get CV
   values of 10, 300, and 500.

#. Next, edit the |sigma|\ :sup:`2` path parameter for one of the data
   sets to read

   ::

       path for data set 1 {
              sigma2 = eins([CV],  thetae)
       }

#. Finally, push this |sigma|\ :sup:`2` value on the other data sets
   without editing those to which it is pushed.

When :demeter:`artemis` evaluates the fitting model, it will replace
the ``[CV]`` token with the appropriate characteristic value. In
short, the computer handles the error-prone (for a human) task of
editing the many |sigma|\ :sup:`2` path parameters.

While this may seem like a small improvement over handling the editing
chores yourself, use of the CV really pays off for large or complicated
fitting models. For a multiple data set fit with many data sets, use of
the CV saves quite a bit of editing. Furthermore, you can use the CV
value in many path parameter math expressions. For example, suppose you
were to model the |Delta| R values with a temperature-dependent, linear
explansion coefficient. The use of the CV in those math expressions
saves even more error-prone, manual editing!



Use in lguess parameters
------------------------

The second use of the CV is along with :lguess:`lguess`
parameters. These parameters are an eficient way of generating
per-data-set guess parameters in a multiple data set fit while still
making good use of the automation in :demeter:`artemis` for pushing
path parameter math expressions between data sets.

Let's again consider the ZnO sample measured at the same three
temparatures. This time, however, we choose to float an independent σ²
parameter at each temperature.

The straightforward way of doing this would be something like

::

    guess ss1 = 0.002
    guess ss2 = 0.004
    guess ss3 = 0.006

    path for data set 1 {
           sigma2 = ss1
    }
    path for data set 2 {
           sigma2 = ss2
    }
    path for data set 3 {
           sigma2 = ss3
    }

Here is how this can be done using the CV and an :lguess:`lguess`
parameter.  First, set the CV values to the temperature values, as
before. Next, do the following:

::

    lguess ss = 0.002

    path for data set 1 {
           sigma2 = ss
    }
    path for data set 2 {
           sigma2 = ss
    }
    path for data set 3 {
           sigma2 = ss
    }

:demeter:`artemis` will notice that ``ss`` is an :lguess:`lguess`
parameter. For each data set in which it is used, :demeter:`artemis`
will create a :guess:`guess` parameters named ``ss_[CV]``, where, as before,
the ``[CV]`` is replaced by the CV value.

In the case of our example, three :guess:`guess` parameters will be
created called ``ss_10``, ``ss_300``, and ``ss_500``. Each of those
will be given the initial value of the coresponding :lguess:`lguess`
parameter (0.002 in this case). The :lguess:`lguess` parameter will
not be used in the fit, but each of the generated :guess:`guess`
parameters will be floated. At the end of the fit, the log file will
report on each as for any other :guess:`guess` parameter.

The utility of the :lguess:`lguess` parameter is that it allows you to
define a common fitting model used across many data sets. You can use
the automation built into :demeter:`artemis` to push those path
parameter math expressions between paths and data sets. Without
further editing, the desired fitting model |nd| with one
:guess:`guess` parameter for each data set |nd| is correctly made.

