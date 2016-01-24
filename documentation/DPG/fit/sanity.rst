..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: guess
.. role:: def

Sanity checks
=============

A lot happens under the hood when the ``fit`` method is called by a Fit
object. One of the first things that happens is an extensive series of
sanity checks on the objects that make up the fitting model.

Here is the complete list of tests that are made on a fitting model:

#. Check that any files associated with the data or the
   :demeter:`feff` calculations exist.

#. Check that all :guess:`guess` parameters are used in at least one
   :def:`def` parameter or path parameter.

#. Check that no :def:`def` parameter or path parameter uses an
   undefined parameter.

#. Check that none of these typos appear in any math expressions:
   ``++``, ``--``, ``//``, or ``***``

#. Check that all function names used in math expression (i.e. a word
   followed by parentheses) are valid functions in :demeter:`ifeffit`
   or :demeter:`larch` (as appropriate).  :demeter:`artemis` does not
   make any check that the arguments of the function are sensible,
   however.

#. Check that all GDS parameters have unique names.

#. Check that parentheses match in all math expressions, i.e. that every
   open parenthesis has a matching close parenthesis.

#. Check that Fourier transform and fit parameters are sensible (for
   example R\ :sub:`min` < R\ :sub:`max`) for all data sets.

#. Check that the number of :guess:`guess` parameters is less than N\
   :sub:`idp`.

#. Verify that R\ :sub:`min`\ |ge| R\ :sub:`bkg` for data imported from an
   :demeter:`athena` project file.

#. Verify that R\ :sub:`eff` for each path is not well beyond
   R\ :sub:`max`. The margin beyond R\ :sub:`max` that a value of
   R\ :sub:`eff` is acceptable is set by R\ :sub:`max`\, plus the
   value of :configparam:`Warnings,reff_margin`.

#. Check that various compiled-in limits (e.g. maximum number of paths
   or maximum number of set parameters) in :demeter:`ifeffit` are not
   exceeded.  This check is ignored when using :demeter:`larch`.

#. Check that parameters do not have the same names as
   :demeter:`ifeffit` program variables. For example, things like
   ``pi`` or ``dr1`` are not allowed since :demeter:`ifeffit` uses
   those strings for other purposes. Although not strictly necessary,
   this check is enforced by default when using :demeter:`larch`.

#. Check that there are no unresolved merge parameters. *This feature
   is not yet implemented.*

#. Check that GDS math expressions do not have loops or cycles in their
   definitions. For example, either of the following would trigger this
   error.

   ::

       guess x = x  # a nod to Laurie Anderson fans....

   ::

       guess a = b
       def   b = c
       def   c = a

#. Check for obvious cases of a data set used more than once.

#. Check that each data set used in the fit has at least one path
   assigned to it.

#. Check that each Path object has a way of computing its
   contribution, i.e. has an associated ScatteringPath object or is a
   valid pathlike object.

If any of these sanity checks fail for your fitting model, the fit
will not continue and a (hopefully) useful error message will be
issued via :demeter:`demeter`'s error reporting system. For a script
run at the command line, this error message is typically (and by
default) issued to STDERR. For a Wx application, the warning text will
normally be displayed in a dialog box or elsewhere. Disposal of the
error text is left as a chore for the end-user application.

