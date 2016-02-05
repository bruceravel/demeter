..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Introduction
============

:demeter:`feff` and :demeter:`ifeffit` are amazing tools, but they can
be somewhat hard to use. :demeter:`feff` requires the use of clunky
text files with confusing syntax as its input. :demeter:`ifeffit` has
a wordy, finicky syntax. Both benefit by being wrapped up inside of
something easier to use. Hopefully, :demeter:`artemis` is that something.



Typesetting
-----------

Typesetting conventions are used to convey certain kinds of
information in this manual.

#. The names of programs look like this: :demeter:`artemis`, :demeter:`feff`

#. The names of files look like this: :file:`atoms.inp`

#. Configuration parameters (i.e. preferences) for :demeter:`artemis`
   and :demeter:`demeter` look like this:
   :configparam:`Artemis,plot_after_fit`

#. Verbatim text, such as represent specific input to or output from
   :demeter:`artemis` or text typed into a computer, looks like this:

   ::

       This is verbatim text!

.. caution:: Words of caution intended to point out some specific
   pitfall of the use or :demeter:`artemis` are found in boxes that
   look like this.

.. todo:: Aspects of this document, or possibly of :demeter:`artemis`
   itself, which are incomplete are indicated with boxes like this.

------------

.. todo:: Move the next two sections into a technology document in the
   SinglePage section.

The technology behind Artemis
-----------------------------


**perl**

   :demeter:`demeter` uses `perl <http://perl.org>`__. This is, I
   suppose, an unsexy choice these days. All the cool kids are, after
   all, using python or ruby. I like perl. I can think in perl. And I
   can code quickly and fluently in perl. What's more, perl has `CPAN
   <http://www.cpan.org/>`__, the worlds largest repository of
   language extensions. CPAN means that I have far fewer wheels to
   recreate (and probably get wrong). Virtually any language extension
   I need in pursuit of making :demeter:`demeter` awesome probably
   already exists.


**wxWidgets and wxPerl**

   :demeter:`artemis` uses `wxWidgets <http://wxwidgets.org/>`__ and
   its perl wrapper `wxPerl <http://wxperl.sourceforge.net/>`__ as its
   graphical toolkit.  This cross-platform tool gives
   :demeter:`artemis` a truly native look and feel because it uses the
   platform's native API rather than emulating the GUI.  Using wx's
   rich set of graphical tools, :demeter:`artemis` strives to provide
   a powerful yet user-friendly environment in which to perform EXAFS
   data analysis.

**Moose**

   :demeter:`demeter` uses `Moose <https://metacpan.org/pod/Moose>`__.
   This is, on the balance, a very good thing, indeed. Moose brings
   many powerful capabilities to the programming table. When I was
   about halfway through writing :demeter:`demeter`, I paused for a
   bit less than a month to rewrite everything I had thus far created
   to use Moose. This left me with about 2/3 as many lines of code and
   a codebase that was more robust and more featureful. Neat-o!

   For the nerdly, Moose is an implementation of a `meta-object
   protocol <http://en.wikipedia.com/wiki/Metaobject>`__. This interesting
   and powerful tool allows for the semantics of the object system to be
   modified at either compile or run time. The problem of adding features
   and functionality to the object system is therefore pushed downstream
   from the developers of the language to the users of the language. In
   good CPAN fashion, a healthy and robust ecosystem has evolved around
   Moose producing a whole host of useful extensions.

   Moose offers lots of great features, including an extremely
   powerful attribute system, a type attribute system, method
   modifiers, an ability to mix object and aspect orientation, and a
   wonderfully deep set of automated tests. I am confident that simply
   by using Moose, my code is better code and, because Moose testing
   is so deep, I am confident that any bugs in :demeter:`demeter` are
   my fault and not the fault of the people whose work I depend on.

   For all the wonderfulness of Moose, it does have one big wart that
   I need to be up-front about. Moose is slow at start-up. Since
   :demeter:`demeter` is big and Moose starts slowly, any program
   using :demeter:`demeter` will take about 2 extra second to
   start. For a long-running program like a complicated fitting script
   or a GUI, an additional couple of seconds at start-up is no big
   deal. For quick-n-dirty or one-off application, that may a bit
   annoying. The Moose folk claim to be working on start-up issues. I
   am keeping my fingers crossed. Until then, I live with the slow
   start-up, confident that the rest of :demeter:`demeter` is worth
   the wait.


Templates, backends, and other tools
------------------------------------

All of :demeter:`artemis`' interactions with :demeter:`feff`,
:demeter:`ifeffit`, and its plotting tools use `a templating library
<https://metacpan.org/module/Text::Template>`__. Along with a clean
separation between function within the :demeter:`demeter` code base
and syntax of the various tools used by :demeter:`demeter`, the use of
templated interactions provides a clear upgrade path for all parts of
:demeter:`artemis`.

:demeter:`feff`

    Although :demeter:`demeter` ships with a freely redistributable
    version of :demeter:`feff6`, it is possible to upgrade to use
    later versions of :demeter:`feff` by providing an appropriate set
    of templates. At this time, :demeter:`feff8` is partially
    supported, with better support coming soon.

:demeter:`ifeffit` and :demeter:`larch`

    Matt Newville, the author of :demeter:`ifeffit`, is hard at work
    on :demeter:`ifeffit`'s successor, called :demeter:`larch`. The
    path to supporting :demeter:`larch` will be relatively shallow,
    requiring only authorship of a new set of templates.

plotting

    :demeter:`demeter` currently supports two plotting backends:
    :program:`PGPLOT`, which is the native plotting tool in
    :demeter:`ifeffit`, and :program:`Gnuplot`. New plotting backends
    can be supported, again simply by creation of new set of
    templates.

For some numerically intensive parts of the code, :demeter:`artemis`
relies on `the Perl Data Language <http://pdl.perl.org/>`__, a
natively vector-oriented numerical language.

:demeter:`artemis` makes use a host of other tools from CPAN, the
online perl library, including tools for date and time manipulation;
heap and tree data structures; tools for formal graph theory; tools
for manipulating zip, INI, and yaml files; and many others. These
tools from CPAN are extensively tested and highly reliable.


Folders and log files
---------------------

On occasion, it is helpful to know something about how
:demeter:`artemis` writes information to disk during its operations.

**working folder**

    Many of :demeter:`artemis`' chores involve writing temporary
    files. Project files are unpacked in temporary
    folders. :program:`Gnuplot` writes temporary files as part of its
    plot creation. These files are stored in the :quoted:`stash
    folder`. On linux (and other unixes) this is
    :file:`~/.horae/stash/`.  On Windows this is
    :file:`%APPDATA%\\demeter\\stash`.

**log files**

    When :demeter:`artemis` runs into problems, it attempts to write
    enough information to the screen that the problem can be
    addressed. This screen information is what Bruce needs to
    troubleshoot bugs. On a linux (or other unix) machine, simply run
    :demeter:`artemis` from the command line and the informative
    screen messages will be written to the screen. On a Windows
    machine, it is uncommon to run the software from the command line,
    so :demeter:`artemis` has been instrumented to write a run-time
    log file. This log file is called dartemis.log and can be found in
    the :file:`%APPDATA%\\demeter` folder.

``%APPDATA%`` is :file:`C:\\Users\\<username>\\AppDataRoaming\\` on
Windows 7.

It is :file:`C:\\Documents and Settings\\<username>\\Application Data`
on Windows XP and Vista.

In either case, ``<username>`` is your log-in name.

