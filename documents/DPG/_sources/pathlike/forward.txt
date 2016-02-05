..
   Artemis document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Forward object
==============

The Forward object has not yet been implemented as of version 0.4. Its
purpose will be to facilitate the consideration of the effect of
scatering angle on double and triple scattering paths arising from a
collection of three nearly colinear atoms.

Because there is no way to recalculate any part of the :demeter:`feff`
calculation as part of :demeter:`ifeffit`'s fitting loop, there is no
convenient and straightforward way to parameterize the effect of
changing scattering angle. That is, it is possible to parwameterize a
fitting model in such a way that it considers the possibility that
inter-atomic distances change as the parameters of the fit are
refined. In such a case, it is possible that the only way to logically
resolve the distances to collinear or nearly-collinear paths is to
allow the path to buckle.

There are many solutions to this problem. The data analysis program
XFIT actually does recompute :demeter:`feff` during the course of the
fit. A number of approximate or interpolative solutions have also been
proposed. One involves pre-calculating double and triple scattering
paths of thesame length but over a span of scattering angles. These
precalculated paths are then used in an interpolative solution. The
mixing coefficients (i.e. ``x`` and ``1-x`` in a two-point
interpolation) are computed from other parameters of the fit. This is
explained in detail in `my graduate dissertation
<https://s3.amazonaws.com/BruceRavelCV/bruce_thesis.pdf>`__.

   .. bibliography:: ../dpg.bib
       :filter: author % "Ellis"
       :list: bullet

The interpolation methodology explained in my thesis is complicated and
error-prone to implement.  The FSPath will do all of the rote work
required to pre-calculate the paths and parameterize them for the
interpolation. The input attributes will llikely be the species of the
two scattering atoms, a math expression for calculating the length of
the collinear single scattering path to the further of the two
scattering atoms, and a math expression for computing the scattering
angle. The math expressions will, of course, depend on the details of
your fitting model.


.. todo:: Create Forward object

