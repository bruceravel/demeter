..
   Demeter document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Introduction
============

:demeter:`feff` and :demeter:`ifeffit` are amazing tools.  Together
and over the years, they have enabled the analysis and interpretation
of many thousands of EXAFS experiments spanning an impressively broad
range of scientific disciplines.

Unfortunately, each of these tools is quite difficult to use to its
full capabilities.  The lack of readily accessible, flexible,
highly-capable high-level tools\ [#f1]_ has, to some extent, limited
the use of :demeter:`feff` and :demeter:`ifeffit` to relatively simple
problem.  Most examples of their use in the literature are restricted
to fairly simple parameterization of a model structure that is
calculated using :demeter:`feff` in the most straight-forward manner.

Certainly examples exist of highly sophisticated used of
:demeter:`feff` and :demeter:`ifeffit`. For instance, we see the
clever use of multiple :demeter:`feff` calculations on crystalline
materials as analogs for metallo-organic environments by S. Kelly, et
al.  As another example, we find a very complete accounting of the
effects of anti-site disorder in a crystal by S. Calvin, et al.  Both
of these examples, however, are the work of particularly dedicated and
talented experts in the application of :demeter:`feff` and
:demeter:`ifeffit` and both represent many months of painstaking
effort to develop idiosyncratic analytical methodology.

.. bibliography:: dpg.bib
   :filter: author % "Kelly" or author % 'Calvin'
   :list: bullet


There **has** to be a better way.

:demeter:`demeter` is my attempt to provide a set of tools to enable
the sort of high-level approach to EXAFS data analysis that has always
been the province of the dedicated few. It is also the result of more
than a decade of writing software specifically intended to enable the
use of :demeter:`feff` and :demeter:`ifeffit`.

Many people reading this wil be familiar with my programs
:demeter:`athena` and :demeter:`artemis`.  They have been in wide use
for many years throughout the XAS community and around the world.  As
graphical interfaces to XAS data management and the use of
:demeter:`feff` and :demeter:`ifeffit`, each has proven successful to
a certain degree.  The original versions of the programs suffered from
a major flaw (and any number of minor ones!).  *There was no easy way
to write a small, personal program that replicated the exact behavior
of the GUI programs.*

As convenient as :demeter:`athena` is for processing modest amounts of
data at the beamline or upon returning home from a beam run, it is not
really the right tool for managing huge volumes of data.  These days,
at a beamline with quick-XAS capabilities, it is quite common to
generate many hundreds, even many thousands, of XAS scans.  The
interactivity that makes :demeter:`athena` so appealing when handling
small amounts of data becomes a tedious, repetitive nightmare when
processing large amounts of data.  Unfortunately, there used to be no
way of separating the data processing capabilities of
:demeter:`athena` from the graphical interface.  This is not an
inherent flaw of any of the tools used to create :demeter:`athena` |nd|
it is entirely due to my own inexperience when I began writing
:demeter:`athena`.

This problem is where :demeter:`demeter` started.  :demeter:`demeter`
is :quoted:`middleware` |nd| it is a system of software tools that
sits above :demeter:`feff` and :demeter:`ifeffit` and below the
program that the user actually interacts with.  :demeter:`demeter` is
not, by itself, a computer program.  Rather it is the tool from which
computer programs for XAS data processing and analysis are built.

The package containing the :demeter:`demeter` libraries actually does
include various kinds of interface tools.  For example,
:demeter:`artemis` is written using :demeter:`demeter`.  However, this
version of :demeter:`artemis` does not add any functionality related
to XAS data management not already present in the :demeter:`demeter`
libraries.  It is merely a graphical shell layered on top of
:demeter:`demeter`'s capabilities.  As a result, it is possible |nd|
indeed, often quite easy |nd| to write a small program which performs a
fit to EXAFS data in exactly the same manner as :demeter:`artemis`.

Armed with this middleware layer, it is much easier to consider
implementing tools for automating large quantities of data or writing
tools for special, one-off data processing chores.  And
:demeter:`demeter` offers tools for easily passing data between
:demeter:`athena` and :demeter:`artemis` and your own
:demeter:`demeter`-using programs.

Tools for automation and for easy access to the capabilities available
in the GUI programs would be benefit enough to merit the creation of a
software library. :demeter:`demeter`, however, offers quite a bit more
than that.  It has capabilities already written or under development
for very sophisticated uses of :demeter:`feff`. Inspired by the
articles cited above and by other interesting uses of XAS theory,
:demeter:`demeter` offers easy access to a variety of ways of
manipulating the output of :demeter:`feff` that had previously
required a deep understanding of :demeter:`feff`'s inner workings.

So there you have it. :demeter:`demeter` is a software tool for making
easy XAS chores very easy and for making difficult XAS chores
tractable. This document is full of code samples which demonstrate the
:demeter:`demeter` way of solving XAS data management and analysis
problems. In many cases, you should be able to cut-and-paste examples
into your own programs, modifying them slightly to suite your
particular problem. Hopefully, :demeter:`demeter` has enough
flexibility that you can begin working on problems that have not even
crossed my mind.


The technology behind Demeter
-----------------------------

:demeter:`demeter` uses `perl <https://perl.org>`__. This is, I
suppose, an unsexy choice these days.  All the cool kids, after all,
use python.  I like perl.  I can think in perl. And I can code quickly
and fluently in perl.  What's more, perl has `CPAN
<http://www.cpan.org/>`__, the worlds largest repository of language
extensions.  CPAN means that I have far fewer wheels to recreate (and
probably get wrong).  Virtually any language extension I need in
pursuit of making :demeter:`demeter` awesome probably already exists.

:demeter:`demeter` uses `Moose <https://metacpan.org/pod/Moose>`__.
This is, on the balance, a very good thing, indeed. Moose brings many
powerful capabilities to the programming table. When I was about
halfway through writing :demeter:`demeter`, I paused for a bit less
than a month to rewrite everything I had thus far created to use
Moose. This left me with about 2/3 as many lines of code and a code
base that was more robust and more featureful. Neat-o!

For the nerdly, Moose is an implementation of a `meta-object
protocol <https://en.wikipedia.com/wiki/Metaobject>`__. This interesting
and powerful tool allows for the semantics of the object system to be
modified at either compile or run time. The problem of adding features
and functionality to the object system is therefore pushed downstream
from the developers of the language to the users of the language. In
good CPAN fashion, a healthy and robust ecosystem has evolved around
Moose producing a whole host of useful extensions.

Moose offers lots of great features, including an extremely powerful
attribute system, a type attribute system, method modifiers, an ability
to mix object and aspect orientation, and a wonderfully deep set of
automated tests. I am confident that simply by using Moose, my code is
better code and, because Moose testing is so deep, I am confident that
any bugs in :demeter:`demeter` are my fault and not the fault of the people whose
work I depend on.

For all the wonderfulness of Moose, it does have one big wart that I
need to be up-front about. Moose is slow at start-up. Since :demeter:`demeter` is
big and Moose starts slowly, any program using :demeter:`demeter` will take about 2
extra second to start. For a long-running program like a complicated
fitting script or a GUI, an additional couple of seconds at start-up is
no big deal. For quick-n-dirty or one-off application, that may a bit
annoying. The Moose folk claim to be working on start-up issues. I am
keeping my fingers crossed. Until then, I live with the slow start-up,
confident that the rest of :demeter:`demeter` is worth the wait.


Some vocabulary
---------------

Throughout this document, I use the language of object systems to
describe :demeter:`demeter`. I don't expect than everyone using
:demeter:`demeter` should know much about object oriented
programming. indeed, my hope is that the examples in this document can
be followed and adapted by anyone with a basic grounding in the use of
perl. To help introduce that person to the prospect of coding with
:demeter:`demeter`, I'll define a few terms. (More specifically, I'll
relate my understanding of those terms. I have no formal training in
computer science and am probably wrong a lot about this
stuff. :demeter:`demeter` seems to work nonetheless.) For a bit more
Moose-specific information, see `the concepts page from the Moose
manual
<https://metacpan.org/pod/distribution/Moose/lib/Moose/Manual/Concepts.pod>`__.

**Object**
    Think of an object as a box containing data. This box comes with a
    set of instructions for how to manipulate the stuff in the box. The
    data are called the attributes of the object and tend to be things
    like numbers, strings, booleans, or other data structures. The set
    of instructions are called methods and are very similar to
    subroutines in a non-object-oriented perl script with the caveat
    that there is an important syntax relation between an object and any
    of its methods.
**Attribute**
    An attribute is a piece of information about the object that is
    either set by the user or computed as a result of some interaction
    with the object. You can always query an object about an attribute
    value. Some attributes are read-write, which means that they can be
    set in your program. Others are read-only, which means they have a
    value that is set when the object is created and cannot be further
    modified in your program. See `the attributes page from the Moose
    manual <https://metacpan.org/pod/distribution/Moose/lib/Moose/Manual/Attributes.pod>`__
    for more details.
**Accessor**
    An accessor is a kind of method whose specific job is to query an
    object for an attribute value or to set the attribute to a new
    value. :demeter:`demeter` uses a feature of Moose whereby an attribute is given
    a name and this name is used as the name of the accessor method.
    When the accessor is called without an argument, it gets the value
    of the attribute. When it is called with a value, it attempts to set
    the attribute to that value. :demeter:`demeter` defines two additional accessor
    functions, ``set`` and ``get`` which are used to access multiple
    attributes with a single method call.
**Type constraints**
    Moose offers a flexible type constraint system, which means that an
    attribute can be restricted to have a value that meets a defined
    criterion. For example, the value for the ``kmin`` parameter of the
    Fourier transform can be defined to be a non-negative number.
    Attempting to set it to a negative value triggers an error. In this
    way, sanity checking of parameters is built deeply into :demeter:`demeter`. See
    `the types page from the Moose
    manual <https://metacpan.org/pod/distribution/Moose/lib/Moose/Manual/Types.pod>`__
    for more details.
**Method**
    A method is a thing that can be done to an object. For example,
    there is an object type in :demeter:`demeter` that is used to contain an XAS
    spectrum. That object has a method called ``plot`` whose purpose is
    to prepare and display a plot of the data. Another object type is
    used to define an EXAFS fitting model. That object has a method
    called ``fit`` which is used to actually perform the fit and store
    the resulting statistical parameters. Many other methods serve
    rather more mundane chores. In every case, though, the method is
    something that is done to or with a particular object. Each object
    has a set of methods that can be called. This set of methods defines
    the complete behavior of the object.
**Trigger**
    A trigger is something that happens what an accessor is used to set
    an attribute value. It is an action that takes place as a result of
    changing an attribute value. For example, when the value of
    R\ :sub:`bkg` is changed for an object associated with XAS data, the
    trigger is used to set a flag that assures that the background
    removal is performed anew the next time it is necessary to do a
    Fourier transform of those data. Triggers are used to control much
    of the high-level functionality in :demeter:`demeter`.

I will, on occassion in this document, point the reader to web sites
where more of the programming details can be found.


.. rubric:: Footnotes

.. [#f1] This isn't really true now that :demeter:`larch` exists.
   When I started writing :demeter:`demeter` |nd| and first write this
   document, it was most certainly true.
