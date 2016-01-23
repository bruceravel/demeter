
Computng potentials
===================

The part of :demeter:`feff` that computes potentials is one of its
essential parts and is used by :demeter:`demeter`. Continuing with the
example from the previous section, we can use an instrumented Feff
object to compute potentials.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $feff = Demeter::Feff -> new(file => "feff/feff.inp");
    $feff -> set(workspace => "feff/", screen => 0,);
    $feff -> potph

When the ``potph`` method is called, :demeter:`demeter` writes a
:file:`feff.inp` file using the data from the original input file but
with the ``CONTROL`` keyword set such that only the *potph* part of
:demeter:`feff` gets run. At the end of this, :demeter:`feff`'s
:file:`phase.bin` file will be written into the ``workspace`` directory.

That's it. This part of :demeter:`feff` is used as-is by
:demeter:`demeter`.  In the course of fitting, you might find that you
need to move an atom by such a large amount that you will want to
recompute the potentials. For smaller moves, :demeter:`demeter` (and
:demeter:`ifeffit`) assume that the primary effect of the move on the
EXAFS is from changing the value of R in the EXAFS equation. Thus we
assume that the changes in the scattering amplitude and phase shift
due to the small change in the potential surface caused by a
readjustment of the interatomic distance are small compared to effect
of R in the EXAFS equation.

At this time, there is not an obvious mechanism in :demeter:`demeter`
to close this loop in the situation where the potentials need to be
recalculated. That is, there are no tools for rewriting the atoms list
in :file:`feff.inp` based on changes in inter-atomic distance
uncovered in a fit.

.. todo:: Track geometric parameters from :demeter:`atoms` to every
	  site in the :demeter:`feff` input file. Then provide tools
	  for parameterizing interatomic distances based on the
	  geometry.

