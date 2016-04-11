

..
   This document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Frequently Asked Questions
==========================

.. toctree::
   :maxdepth: 2

Big Questions
-------------

#. .. admonition:: What's the latest version of :demeter:`demeter`?
      :class: faq

      The current version number is given on the left under the
      :quoted:`Helpful links` heading

#. .. admonition:: Where do I get the latest version of :demeter:`demeter`?
      :class: faq

      The latest version is always available at http://bruceravel.github.io/demeter/.


#. .. admonition:: How do I join the :demeter:`ifeffit` mailing list?
      :class: faq

      Check it out:
      http://cars9.uchicago.edu/mailman/listinfo/ifeffit/.
      Just fill in the form and click :quoted:`Subscribe`!


#. .. admonition:: Why did Bruce direct me to the mailing list rather than answering the question in the email I sent him?
      :class: faq

      One answer is that the mailing list is a very useful resource.
      Questions asked on the mailing list might garner answers from
      multiple experts with different perspectives.  Also questions
      asked on the mailing list might get an answer even when I am on
      travel or otherwise unavailable to answer questions.  Folks on
      the list tend to be friendly and very helpful.

      Also the mailing list is archived.  A useful answer might be
      discovered by a confused person in the future.  That's a very
      good thing.

      Another answer is that there are a **lot** of people using
      :demeter:`demeter` these days.  I simply do not have the time to
      provide individual support to the hundreds of people using my
      software.  The mailing list helps me manage my time while still
      helping people get over their hurdles.

      The most blunt answer is that supporting this software is not
      actually my job.  I mean that in the sense that it is not
      specifically mentioned in my job description |nd| y'know, the
      thing I actually get paid for.  Supporting my software is
      something I do because it is of value and because it is often
      rewarding.  But, look ... I give you functional software for
      free.  I wrote documentation that is often adequate and give
      that away for free.  I give away `lecture notes
      <https://speakerdeck.com/bruceravel>`_ and `training materials
      <http://bruceravel.github.io/XAS-Education/>`_ for free.  I
      answer questions on the mailing list.  That's a lot of stuff.
      The only thing I ask for in return is that questions be directed
      to the mailing list rather than to me personally.\ [#f1]_ That's
      not a big ask.

#. .. admonition:: How do I cite this software?
      :class: faq

      :demeter:`demeter`

         B. Ravel and M. Newville, *ATHENA, ARTEMIS, HEPHAESTUS: data
         analysis for X-ray absorption spectroscopy using IFEFFIT*,
         Journal of Synchrotron Radiation 12, 537–541 (2005)
         `doi:10.1107/S0909049505012719 <https://doi.org/10.1107/S0909049505012719>`_

      :demeter:`ifeffit`

	 M. Newville,
	 *IFEFFIT : interactive XAFS analysis and FEFF fitting*
	 J. Synchrotron Rad. (2001). 8, 322-324
	 `doi:10.1107/S0909049500016964 <https://doi.org/10.1107/S0909049500016964>`_

      :demeter:`larch`

	 M. Newville, *Larch: An Analysis Package for XAFS and Related
	 Spectroscopies*, Journal of Physics: Conference Series,
	 Volume 430, 012007
	 `(link) <http://stacks.iop.org/1742-6596/430/i=1/a=012007>`_

#. .. admonition:: How do I suggest a topic for this FAQ?
      :class: faq

      The easiest way to make a FAQ suggestion is to go to `Demeter's
      issues page at GitHub
      <https://github.com/bruceravel/demeter/issues>`_ and open a new
      issue with your suggestion.  If you'd like to suggest the answer
      as well |nd| superb!

      You can also edit the source for this FAQ page by editing the
      file ``documentation/SinglePage/faq.rst`` in the source code
      repository.  `Sphinx <http://www.sphinx-doc.org>`_ is used to
      make the web pages and the source uses `reStructured Text
      <http://www.sphinx-doc.org/en/stable/rest.html>`_.  Go ahead and
      edit the file, then make a pull request at the `Demeter's GitHub
      page <https://github.com/bruceravel/demeter>`_.

      Each entry looks like this:

      .. code-block:: rst

	 #. .. admonition:: What about my question?
               :class: faq

	       Here is a great answer!

      The hash (``#``) should be flush against the left margin to get
      the numbering correct.  The ``.. admonition:`` and ``:class:
      faq`` markup is used to typeset the question and answer in an
      attractive manner.  The indentation is important |nd| everything
      should be lined up underneath the :quoted:`a` in :quoted:`admonition`.


Questions about Athena
----------------------

#. .. admonition:: I imported a lot of data into :demeter:`athena` and now it is misbehaving.  What's up with that?
      :class: faq

      This is discussed at length on the mailing list.  `Here is one
      good example
      <https://www.mail-archive.com/ifeffit%40millenia.cars.aps.anl.gov/msg03692.html>`_.
      The bottom line is that :demeter:`ifeffit`, the library that is
      used by Demeter for math and XAFS related functionality, is
      written in Fortran.  It used static memory allocation, which
      means that it will eventually run out of memory if you import a
      lot of data.  When that happens, other weird things will happen.

      The solution is not to overload :demeter:`athena`.  Split your
      work up into groups of 30 or 40 spectra.  Quit :demeter:`athena`
      and restart to process the next group of 30 or 40 spectra.

      This is one of many areas where :demeter:`larch` is an
      improvement over :demeter:`ifeffit`.

#. .. admonition:: :demeter:`Athena` performed an :quoted:`autosave` and now it is unresponsive.  What's up with that?
      :class: faq

      This is discussed `on the mailing list
      here. <https://www.mail-archive.com/ifeffit%40millenia.cars.aps.anl.gov/msg05449.html>`_ 

      The bottom line is that there is a bug in some versions.  Two work-arounds are 

      #. Figure out where the autosave file is on disk and delete it.
	 It's called ``athena.autosave``.
      #. Find the ``demeter.ini`` file (it should be in
	 ``$HOME/.horae`` or ``%APPDATA%\demeter\``) and edit it with
	 a text editor.  Find the ``[athena]`` section, change
	 :quoted:`autosave` to :quoted:`false`.

#. .. admonition:: How do I import my data from SSRL?  DUBBLE?  Photon Factory?  etc...
      :class: faq

      Some beamlines send their users home with strange data files.
      :demeter:`athena` has a plugin mechanism for managing some of
      those strange data files.  Be sure to enable the plugin for your
      beamline.  `Here is an explanation for how that is
      done. <http://bruceravel.github.io/demeter/documents/Athena/other/plugin.html#athena-s-plugin-registry>`_

      If your problematic data is not from a beamline that
      :demeter:`athena` already knows about, then you **must** include
      an example of the data file when you post your question on the
      mailing list.


#. .. admonition:: Why can't :demeter:`athena` import data from my 36-element detector?
      :class: faq

      It can, but it might need help.  In fairness, it's not
      necessarily a reasonable thing to ask of a general purpose
      program like :demeter:`athena`.  `Here's an interesting
      discussion of this
      topic. <https://github.com/bruceravel/demeter/issues/28>`_

      The bottom line is that you might consider processing your data
      prior to importing it into :demeter:`athena` by summing the
      individual columns and removing any bad channels.


Questions about Artemis
-----------------------

#. .. admonition:: I ran :demeter:`feff`.  Why are paths missing and coordination numbers surprising?
      :class: faq

      :demeter:`artemis` offers a feature called fuzzy degeneracy
      where paths of similar length are grouped together.  It is explained
      in detail `in the document <http://bruceravel.github.io/demeter/documents/Artemis/extended/fuzzy.html>`_.

#. .. admonition:: How do I use :demeter:`feff9` in :demeter:`artemis`?
      :class: faq

      The answer is: *you don't*.  Using :demeter:`feff` seamlessly and
      in a way that is transparent for the user is difficult.
      :demeter:`artemis` is designed to use the version of
      :demeter:`feff6` that comes with the package.  Work is being
      done to incorporate `feff85exafs
      <https://github.com/xraypy/feff85exafs>`_ into
      :demeter:`artemis`.

      A better question is: Why do you think you need a different
      version of :demeter:`feff`?  `Read this
      <http://bruceravel.github.io/SCFtests/scf.html>`_ for Bruce's
      take on the scant effect of self-consistent potentials on EXAFS
      analysis. 


Questions about Hephaestus
--------------------------

Questions about Windows
-----------------------

Questions about Macintosh
-------------------------

#. .. admonition:: I can't get :demeter:`demeter` to install on my Mac.  What's up with that?
      :class: faq

      `This page might help <http://bruceravel.github.io/demeter/documents/SinglePage/macports.html>`_


Questions about Linux
---------------------

#. .. admonition:: Why does it take so long for :demeter:`demeter` to install from source?
      :class: faq

      The first time you install :demeter:`demeter` on your computer,
      you have to install *all* of the dependencies.  There are quite
      a lot.  It simply takes time.  When you upgrade on the same
      computer, the dependencies will already be in place, so the
      upgrade will be speedy.


.. rubric:: Footnotes

.. [#f1] Well, ok ... that's not quite true.  I also ask that you cite
	 the reference for :demeter:`athena` and :demeter:`artemis`
	 when you publish.
