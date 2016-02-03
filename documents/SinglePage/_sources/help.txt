
..
   This document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/



Asking questions, soliciting help
=================================

An excellent resource exists for anyone stumbling over the details of
XAS experimentation or analysis |nd| the `Ifeffit mailing list
<http://millenia.cars.aps.anl.gov/mailman/listinfo/ifeffit>`_.  This
low-noise, high-quality mailing list is populated by many of the
world's expert practitioners of XAS and it handles dozens of questions
every month.  It should be the first place you go when you have a
question about the software or about any other topic in XAS.

:demeter:`demeter`'s author, Bruce Ravel (that's me!), reads the
mailing list and frequently responds to questions.  You should send
questions to the mailing list and **not** to me directly.  My typical
response to an unsolicited email about the software is a polite
request to ask the same question on the mailing list.

Using the mailing list is in your best interest.  The list gives you
access to a large number of experts and to the entire
:demeter:`ifeffit` community. When you send you question directly to
me, you may find me on travel, in the middle of an experiment, or
simply not in the mood to read and write email. When you send mail to
the list, you are much more likely to get a useful answer from someone
|nd| and that someone is often me. In fact, you may spark a discussion
in which your question will be hashed out in much more detail than you
would see in a response from a single person.

Don't believe me?  `Here is a nice example
<http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2011-September/010201.html>`_
of a question asked which prompted answers from several different
people.  Follow the links that say :quoted:`next message` to read the
various answers to the question.  After an interesting and useful
discussion, the person with the original question `had this to say
<http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2011-September/010215.html>`_.

`Here is a searchable archive
<http://www.mail-archive.com/ifeffit@millenia.cars.aps.anl.gov/>`_ of
the :demeter:`ifeffit` mailing list.  You may find that someone else
has already asked your question.

How to ask for help
-------------------

If you are asking for help, I encourage you to ask specific questions
rather than vague ones. For example,

::

  I don't understand multiple k-weight fitting. What does it mean to
  use more than one k-weight in a fit and why should I want to do so?

is a **good** question and is likely to get a detailed answer. On the
other hand,

::

  I have lots of data from the synchrotron on TiO2 doped with
  dysprosium. Can someone send me an atoms input file and tell me how
  to get coordination numbers?

is a **vague, open-ended** question that is unlikely to garner much of
a response.  We see lots of these vague, open-ended questions and the
folks asking questions like that rarely get the answer they're looking
for.  Spend time thinking about how to ask the question with clarity,
with conciseness, and with precision |nd| that time spent *will* pay
off.

Remember that the people who answer questions on the mailing list are
volunteering their time and may not have much time to spend with you.

Most questions about the use of the software will benefit by including
example data or a project file that demonstrates your question.  It is
much easier to answer a questions if the problem can be reproduced on
one's own computer.

For more hints about how to ask good questions `How To Ask Questions
The Smart Way <http://www.catb.org/~esr/faqs/smart-questions.html>`_
by Eric Raymond and Rick Moen is very useful.  (Please note that
neither Raymond nor Moen are associated in any way with
:demeter:`demeter` or :demeter:`ifeffit` nor should they be contacted
with questions about :demeter:`demeter` or :demeter:`ifeffit`.)


Other XAFS Resources on the Web
-------------------------------

The community web site, http://xafs.org, provides a wealth of
information, educational materials, links to other sites of interest
to XAS practitioners, and other community tools. The `tutorials
<http://xafs.org/Tutorials>`_ page contains links to educational
materials written by a number of the luminaries of the XAS community.
The `workshops page <http://xafs.org/Workshops>`_ lists links to
several workshops and schools from recent years.  Many of those
workshops post PDF or PowerPoint files for the lectures given at the
workshop. Go ahead and poke around http://xafs.org |nd| many of your
questions will be answered.

In November 2011 the Diamond Light Source invited me to do `an XAS
training course
<http://www.diamond.ac.uk/Beamlines/Spectroscopy/Techniques/XAS.html>`_.
All of the lectures were recorded as was the computer desktop during
all lectures and demonstrations.  The Diamond technical staff did a
great job editing this metrial into several hours of streaming video.
These are excellent references for using and understanding the
software.  (`Here is a hint
<http://support.mozilla.org/en-US/questions/747274>`_ for following
the Microsoft Media Server (``mms:``) links on that page if you are
using Linux and Firefox.  Presumably, similar solutions exist for
other browsers.)

This is an good overview of XAS: 

.. bibliography:: singlefile.bib
   :filter: author % "Kelly"
   :list: bullet

Scott Calvin's book *XAFS for Everyone* is my favorite XAFS textbook.

.. bibliography:: singlefile.bib
   :filter: title % "Everyone"
   :list: bullet

Grant Bunker's book is also excellent, although geared a bit more
towards the physics or chemistry grad student.

.. bibliography:: singlefile.bib
   :filter: author % "Bunker"
   :list: bullet

Ifeffit and Demeter software
----------------------------

You can clone the :demeter:`demeter` source code at
http://github.com/bruceravel/demeter.  Links to an installer package
for Windows are also at http://bruceravel.github.io/demeter, as is
documentation for :demeter:`athena`, :demeter:`artemis`, and
:demeter:`hephaestus`.

Slide decks for the lectures the I give at XAS training courses can be
found at https://speakerdeck.com/bruceravel.  Those are all under a
`Creative Commons <http://creativecommons.org/licenses/by-sa/3.0/>`_
license, so feel free to download, share, and use ant of the materials
found there.

Feff
----

If your question pertains to :demeter:`feff` |nd| specifically in the
area of using :demeter:`feff` for XANES calculations |nd| remember
that I am but a minor contributor to :demeter:`feff` and may not
in a position to answer your question authoritatively.  The PI of the
:demeter:`feff` project and his team all read the `Ifeffit mailing
list <http://millenia.cars.aps.anl.gov/mailman/listinfo/ifeffit>`_ and
often answer questions posted there.

The :demeter:`feff` homepage is at http://feffproject.org/.  The
:demeter:`feff9` document: `in wiki format
<http://leonardo.phys.washington.edu/feff/wiki/static/f/e/f/FEFF_Documentation_b0ae.html>`_.
