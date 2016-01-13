..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


.. role:: guess
.. role:: def
.. role:: set
.. role:: lguess
.. role:: skip
.. role:: restrain
.. role:: after
.. role:: penalty
.. role:: merge

The GDS window
==============

.. admonition:: The Big Trick in Artemis
   :class: bigtrick

   The parameters of the EXAFS equation are not the parameters of the fit.
   The parameters of the EXAFS equation are written *in terms of* the
   parameters of the fit.

As a consequence, path parameter values are *math expressions*. These
math expressions are functions of the actual fitting parameters.

Some of these math expressions are quite simple. For example, in the
gold metal example in `the previous chapter <path/mathexp.html>`__,
the math expressions for S\ :sup:`2`\ :sub:`0` and E\ :sub:`0` were
simple functions, each of a single parameter. The math expression for
|Delta| R, however, was a function of ``alpha`` and ``reff``, while
the |sigma|\ :sup:`2` math expression used the ``debye`` function and
two parameters.

All of these parameters must be defined in the GDS window. This window
contains a grid with a series of buttons down the right side. It is
displayed and hidden using the GDS button on the left side of the Main
window. Here are the contents of the GDS window from the gold metal
example. The four variable parameters in the fit along with the fixed
sample temperature needed by the ``debye`` function are shown. A new
variable parameter is being defined in line 6.

The second, third, and fourth columns in the grid are filled by simple
text boxes. The first column contains a drop down menu from which the
parameter types can be chosen.

.. _fig-gds:
.. figure:: ../_images/gds.png
   :target: _images/gds.png
   :align: center

   The GDS window.


Parameter types
---------------

Every parameter of any type used in any math expression must be defined
on the GDS widow. Any variable parameter defined on the GDS window must
be used in a math expression.

There are 9 types of parameters in :demeter:`artemis`. They are color
coded in the grid to give you a visual indication of each parameter's
type.

:guess:`guess`
    This is a parameter of the fit. Its value will be adjusted
    to find the best fit of the model to your data.
:def:`def`
    This is a parameter that is defined as a math expression
    dependent upon other :guess:`guess`, :def:`def`, or :set:`set` parameters. Its value is
    updated throughout the fit. As discussed elsewhere in this manual,
    sophisticated use of :def:`def` parameters is key to successful model
    building and effective use of :demeter:`artemis`.
:set:`set`
    A :set:`set` parameter is one that is evaluated at the beginning of
    the fit, but not evaluated subsequently. Although a :set:`set` parameter
    can take a math expression as its value, it is more typically used
    to represent a constant value used elsewhere in the fitting model.
:lguess:`lguess`
    An :lguess:`lguess` parameter is a tool used to simplify model
    creation for a multiple data set fit. It can be used in math
    expressions for two or more data sets. When the fit started, an
    actual guess parameter will be created for each data set in which
    the :lguess:`lguess` is used. As an example, suppose your multiple data set
    fit includes data on a series of binary alloys. If ``x`` is a mixing
    parameter between the two alloys and is different for each sample,
    you might then use math expressions containing ``x`` and ``(1-x)``
    for  S\ :sup:`2`\ :sub:`0` parameters of paths representing the two metallic species in
    each fit. With ``x`` an :lguess:`lguess` parameter, independent mixing
    parameters will be floated for each data set. The point, then, of an
    :lguess:`lguess` is to facilitate the chore of editing path parameter math
    expressions using :demeter:`artemis`' tools for pushing path parameter values
    across paths. This is discussed in more detail in `the discussion of
    the characteristic
    value <extended/cv.html#useinlguessparameters>`__.
:skip:`skip`
    A :skip:`skip` parameter is one that is not used in any capacity in
    the fit, but which you do not want to discard from your fitting
    project.
:restrain:`restrain`
    A :restrain:`restraint` is a math expression that is evaluated and
    added in quadrature to |chi|\ :sup:`2` to evaluate the fit. That is, the fit is
    optimized in the presence of the restraint. The point of this is to
    add prior knowledge to a fit. Restraints will be discussed in more
    detail later in this document.
:after:`after`
    An :after:`after` parameter is very similar to a :def:`def` parameter in that
    it takes a math expression that depends on other parameters. It is
    not, however, used in any way in the fit. Instead, it is evaluated
    at the end of the fit and reported to the log file. This is used to
    make interesting calculations based on other parameters as part of
    the record of the fit.
:penalty:`penalty`
    This takes a math expression representing a user defined
    penalty to the happiness calculation. *This feature has not yet been
    implemented in* :demeter:`artemis`.
:merge:`merge`
    A merge parameter is a parameter which has been
    multiply defined under the same name as part of combining fitting
    projects or importing structural units. A fit cannot proceed with
    any parameters in this state. *This feature has not yet been
    implemented in* :demeter:`artemis`.

.. todo:: Penalty and merge parameters have not been implemented.



User interaction
----------------

.. todo:: Explain drag and drop



Button bar
~~~~~~~~~~

The stack of buttons on the right side of the GDS window contains many
of the main functions of the GDS window.

:button:`Use best fit,light`
    This button makes the most recent best fit value into the initial
    guess for every guess parameter in the grid.
:button:`Reset all,light`
    This button tells :demeter:`ifeffit` to reset all parameters to their initial
    values.
:button:`Highlight,light`
    This button prompts you for a string. All parameters with names or
    math expressions matching the string provided will be highlighted
    with a yellow background. This feature is particularly useful in
    large fitting models with many parameters. In the image above, you
    can see that all parameters matching :regexp:`brc1` have been highlighted.
    The string to match can actually be any valid Perl regular
    expression.
:button:`Evaluate,light`
    Clicking this button will evaluate all parameters and insert their
    evaluations into the fourth column of the grid. This is used to
    “spell-check” your math expressions for def and other parameters. In
    the image above, this button has been clicked and the evaluations
    have been inserted into the fourth column.
:button:`Import GDS,light`, :button:`Export GDS,light`
    The next two buttons are used to import or export a simple text file
    with the names and definitions of all the parameters.
:button:`Discard all,light`
    This button does just that, after prompting to be sure that is what
    you want to do.
:button:`Add a site,light`
    This button appends a blank row to the end of the grid.


Keyboard shortcuts
~~~~~~~~~~~~~~~~~~

When one or more rows are selected, you can use the following keyboard
shortcuts to change the parameter type of that set of parameters.

-  :button:`Alt`-:button:`g`: :guess:`convert to guess`

-  :button:`Alt`-:button:`d`: :def:`convert to def`

-  :button:`Alt`-:button:`s`: :set:`convert to set`

-  :button:`Alt`-:button:`l`: :lguess:`convert to lguess`

-  :button:`Alt`-:button:`k`: :skip:`convert to skip`

-  :button:`Alt`-:button:`r`: :restrain:`convert to restrain`

-  :button:`Alt`-:button:`a`: :after:`convert to after`

-  :button:`Alt`-:button:`p`: :penalty:`convert to penalty`



Context menu
~~~~~~~~~~~~

Clicking on a line in the grid selects the entire line.
:button:`Control` clicking of a line adds that line to the
selection. :button:`Shift` clicking adds all lines between the
selected and clicked upon lines.

.. _fig-gdsmenu:
.. figure:: ../_images/gds-menu.png
   :target: _images/gds-menu.png
   :align: center

   Right clicking on any line in the grid, including the label containing
   the line number, will post this menu.

:guilabel:`Copy, cut, paste`
    These three options copy, cut, and paste lines from or to the GDS
    grid. The cut function is one way of discarding a parameter. Another
    is to simply delete the name in the second column.
:guilabel:`Insert blank lines`
    The insertion options complement the “Add a site” button by adding
    blank rows to the middle of the grid.
:guilabel:`Change parameter type of selected lines`
    This sub-menu provides yet another way of changing the parameter
    type of the selected lines of the grid. If you have more than one
    line selected, they will all get changed to the option you choose
    from the submenu.
:guilabel:`Grab best fit`
    This changes theinitial guess of the selected lines to the most
    recent best fit value(s).
:guilabel:`Build restraint`
    .. _fig-gdsrestraint:
    .. figure:: ../_images/gds-restraint.png
       :target: _images/gds-restraint.png
       :align: center

       This posts a dialog that helps you name and define a restraint based
       upon the value of the parameter in the line clicked upon. 

    This will use :demeter:`ifeffit`'s ``penalty`` function with the
    lower and upper bounds as its arguments and multiplied by the
    scaling factor. The example shown will make this restraint:

    ::

        restrain res_enot = 1000 * penalty(enot, -5, 5)

    and add it to the end of the grid. The penalty function will
    evaluate to 0 when enot stays between -5 and 5. As the value of
    enot strays outside that range, the restraint will evaluate to a
    value of 100 times the distance outside the range. This, then, is
    added in quadrature to |chi|\ :sup:`2` when the fit is
    minimized. You can read more about this, including how to choose
    the value of the scaling parameter, in the `discussion of
    restraints <extended/constraints.html>`__.

:guilabel:`Annotate`
    This prompts you for a text string to describe the parameter in the
    line clicked upon. The intent is to allow you document the role of
    the parameter in your fitting model. This annotation is displayed in
    the GDS window's status bar when that line is selected.
:guilabel:`Find parameter`
    This posts a small window with a text box reporting all GDS
    parameters and path parameters which have math expressions
    containing this parameter.
:guilabel:`Rename parameter globally`
    This allows you to rename a parameter and have its new name inserted
    every place in the fit where that parameter is used. All instances
    in other parameters on the GDS page and in the math expressions for
    parameters of all paths will be changed. Essentially, this is a
    global search and replace.
:guilabel:`Explain`
    Finally, the items in this submenu write a short text to the status
    bar explaining the various parameter types.


Creating parameters from math expressions on the path page
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Parameters can be created from the `path page <path/index.html>`__. When
you right click on a word in a math expression for the one of the `path
parameters <path/mathexp.html>`__, a menu pops up which allows you to
set the word you clicked upon as GDS parameter.

.. _fig-gdspath:
.. figure:: ../_images/gds_path.png
   :target: _images/gds_path.png
   :align: center

   Creating GDS parameters by right clicking on a math expression on the
   Path page.

If you have not yet defined the word you click on, then the GDS window
will appear on screen, and the parameter will be inserted into the GDS
table as the type of parameter selected from the menu.

If the word has already been defined, then its type will be changed to
the type you select from the menu.

If the word is something that is not allowed in :demeter:`ifeffit` as
a parameter name (things like ``dr1`` and ``cos`` are reserved words
and cannot be used as parameter names) then the menu will not be
posted. Likewise, the menu will not be posted if you right click on a
number.

