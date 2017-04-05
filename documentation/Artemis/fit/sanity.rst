..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. role:: guess
.. role:: def

Sanity checking your fitting model
==================================

:demeter:`artemis` is complex and it is quite easy to make mistakes.
Many common mistakes are obvious and discoverable by automated
analysis of the fitting model.  Before running a fit,
:demeter:`artemis` applies each of the following test to your fitting
model.  If any of them are triggered, the fit is halted and a
(hopefully) useful error message is posted in the Log window.  Think
of this like :demeter:`artemis`' spell checker!

Any problems that are found must be corrected before
:demeter:`artemis` will allow the fit to proceed.

Some of these tests can be disabled using the :menuselection:`Fit -->
Disable sanity checks` menu in the Main window.


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

As a side note, item 15 is particularly interesting.
:demeter:`demeter` does a simple lexical analysis on the ensemble of
math expressions defined on the GDS window, then uses `a formal graph
theory tool <https://metacpan.org/pod/Graph>`__ to develop a graph
depiction of the parameters. Loops (like the first example) and cycles
(like the second) a trivially evident when the parameters are viewed
as a formal graph. That was a really fun part of :demeter:`demeter` to
write.

