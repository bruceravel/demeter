..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: guess
.. role:: set

Setting math expressions
========================

Once some paths have been :mark:`drag,..` dragged from the
:demeter:`feff` window onto the Data window containing the gold foil
data, it is time to begin defining math expressions for the path
parameters. In the following figure, the path corresponding to the
first coordination shell has been selected from the path list. A path
is selected by :mark:`leftclick,..` left clicking on its label in the
path list. Doing so, displays that path on the right side of the Data
window.

At the top of the Path page are two checkboxes. One is used to include
and exclude a path from the fitting model. In this way, you can control
which paths are used in a fit without having to remove them from the
path list. The other check box is used to indicate if the current path
should be transfered to the plotting list in the Plot window at the end
of a fit.

.. todo:: Implement and explain the two items in the :guilabel:`other
   path options` pane.

The text box contains a brief description of the geometry of the
scattering path. For a path with degeneracy greater than 1, the
scattering geometry of one of the degenerate paths is shown. The simple
explanation of the shape of the path and its heuristic importance are
also given in the text box.

.. todo:: Implement a way to display a text box which shows all the
   paths contributing to the degeneracy + report on fuzziness of the
   degeneracy.

Beneath the scattering geometry is a table of labels and text boxes
for the path parameters.  Math expressions are entered into these text
boxes.

.. _fig-pathfirst:
.. figure:: ../../_images/path-first.png
   :target: ../_images/path-first.png
   :align: center

   Math expressions have been set for the first shell path.

In the preceding image, a simple fitting model appropriate for a
cubic, monoatomic material like our gold foil has been entered for the
first shell path.  This includes simple expressions for S\ :sup:`2`\
:sub:`0` and E\ :sub:`0` consisting of variables that will be floated
in the fit. A `model of isotropic expansion <../extended/delr.html>`__
is provided for |Delta| R.  The |sigma|\ :sup:`2` path parameter is
expressed using `the correlated Debye model <../extended/ss.html>`__.
The other path parameter text boxes have been left blank and will not
be modified in the fit.

.. bibliography:: ../artemis.bib
   :filter: author % 'Sevillano'
   :list: bullet

This, of course, establishes the parameterization only for the first
path.  The same editing of path parameter math expressions must happen
for all the other paths used in the fit.

The most obvious way to do this editing chore is to
:mark:`leftclick,..` click on each successive path in the path list,
then :mark:`leftclick,..` click into each text box, then type in the
math expressions.  That, however, is both tedious and error-prone.

.. _fig-pathmenu:
.. figure:: ../../_images/path-menu.png
   :target: ../_images/path-menu.png
   :align: center

   The path parameter context menu.

For math expressions that are the same for every path |nd| E\ :sub:`0`
is a common example |nd| :demeter:`artemis` provides some automation
tools. Each of the path parameter labels on the Path page is sensitive
to either :mark:`leftclick,..` left or :mark:`rightclick,..` right
click.  Either kind of click posts a menu like the one of the
right. The top option is used to erase the contents of the associated
text both, but only on this path.

The next four options are used to push the math expression for the
associated path parameter onto other paths. These four options allow
some control over the paths that are targeted to receive the pushed path
parameter values.

The last two options are used to grab the math expression from one of
the surrounding paths.

The menu that pops up for the |sigma|\ :sup:`2` parameter has two
additional options.  One inserts a math expression for using the
correlated Debye function for |sigma|\ :sup:`2`, the other inserts the
math expression for an Einstein model.  `Both the Debye and Einstein
functions <../extended/ss.html>`__ depend on the measurement
temperature and a characteristic temperature.  Typically, the
measurement temperature is a :set:`set` variable and the
characteristic temperature is a :guess:`guess`. When either function
is inserted into the text box, parameters are automatically created
`on the GDS page <../gds.html>`__.

The Path menu on the Data page offers a way of pushing all the path
parameters from the displayed path to other paths. The same options for
targeting other paths are presented.

.. _fig-pathpush:
.. figure:: ../../_images/path-push.png
   :target: ../_images/path-push.png
   :align: center

   Push all path parameters to other paths.
