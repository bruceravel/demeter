..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Artemis: EXAFS Data Analysis using Feff with Larch or Ifeffit
=============================================================

::

   I sing of Artemis, whose shafts are of gold, who cheers on the hounds, the pure maiden, shooter
   of stags, who delights in archery, own sister to Apollo with the golden sword. Over the shadowy
   hills and windy peaks she draws her golden bow, rejoicing in the chase, and sends out grievous
   shafts. The tops of the high mountains tremble and the tangled wood echoes awesomely with the
   outcry of beasts: earthquakes and the sea also where fishes shoal. But the goddess with a bold
   heart turns every way destroying the race of wild beasts: and when she is satisfied and has
   cheered her heart, this huntress who delights in arrows slackens her supple bow and goes to the
   great house of her dear brother Phoebus Apollo, to the rich land of Delphi, there to order the
   lovely dance of the Muses and Graces.

                                                  Homeric Hymns XXVII
                                                  Translated by H. G. Evelyn-White


.. endpar::

.. image:: ../_images/Artemis_sm.jpg
   :width: 80%

The `Temple of Artemis
<http://en.wikipedia.org/wiki/Temple_of_Artemis_(Jerash)>`_ at Jerash,
Jordan.  Photo courtesy of Matthew Marcus.

:demeter:`artemis` is the goddess of the hunt, which is an apt
metaphor for the chore of data analysis. The name also suggests a
fallacious pun which works in English and in the Romance languages and
which suggests that EXAFS data analysis is more an art than a science.

----------------------

This document explains the operation of :demeter:`artemis`, a program
for analysis of EXAFS data using :demeter:`feff` and
:demeter:`ifeffit`.  It is built using `Demeter
<http://bruceravel.github.io/demeter/>`__.

:demeter:`demeter` is:

-  a set of `perl <http://www.perl.org/>`__ modules and related files

- a programming tool but not an application |nd| it is the thing from
  which applications are built

- `free software <http://www.gnu.org/philosophy/free-sw.html>`__,
  freely available from a `git server
  <https://github.com/bruceravel/demeter>`__

- actively developed and maintained

- in use by `its author <http://bruceravel.github.io/demeter>`__ for
  real data analysis problems

- a front end to `Feff <http://feff.phys.washington.edu/>`__ and
  `Ifeffit <http://cars9.uchicago.edu/ifeffit/About>`__ (or
  `Larch <http://xraypy.github.com/xraylarch/index.html>`__!)

- the code base for :demeter:`athena` and :demeter:`artemis`

- named for `the Greek goddess of the harvest
  <http://en.wikipedia.org/wiki/Demeter>`__

:demeter:`artemis` is:

- a graphical front-end for :demeter:`feff` and :demeter:`ifeffit` (or
  :demeter:`larch`) built using :demeter:`demeter`

- a tool which makes easy analysis problems easy and hard analysis
  problem possible

- in use by hundreds of scientists world-wide


---------------------

**Contents**

.. toctree::
   :maxdepth: 2
   :numbered:

   intro.rst
   startup/index.rst

.. 
    intro.rst
    startup/index.rst
    data.rst
    feff/index.rst
    path/index.rst
    gds.rst
    fit/index.rst
    plot/index.rst
    logjournal.rst
    history.rst
    monitor.rst
    prefs.rst
    examples/index.rst
    atoms/index.rst
    extended/index.rst
