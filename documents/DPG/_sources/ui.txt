
User interfaces
===============

Most of :demeter:`demeter` makes no particular assumptions about how
you will be interacting with it. There is no special exception
handling beyond what comes normally with perl. In the case of, for
instance, failed sanity checks on a fitting model, error messages are
sent to perl's normal ``warn`` and ``die`` channels on STDERR. The
only sense in which there is an :quoted:`application interface` is due
to the fact that :demeter:`demeter` uses Moose, so one interacts with
:demeter:`demeter` in essentially the way one would interact with a
class system written in Moose. Any special functionality for a
particular style of user interface is something that needs to be
explicitly enabled in your :demeter:`demeter`-using program.



Command line interface
----------------------

:demeter:`demeter` has a lot of neat features that get enabled when you explicitly
set the ``ui`` attibute of the Mode object to be ``screen``. The best
way to do this is at the very beginning of your program, when you import
:demeter:`demeter`.

.. code-block:: perl

   #!/usr/bin/perl
   use Demeter qw(:ui=screen);

Setting the ``ui`` :quoted:`pragma` in this way makes
:demeter:`demeter` assume at compile time that you program will be
using a command line UI.  Doing so at this stage will enable the full
compliment of rich CLI features.

You can also switch to screen mode during the course of your program,
like so:

.. code-block:: perl

   $any_object -> mo -> ui('screen');

However, setting screen mode this way cannot enable all the features.

The features that get turned on by screen mode include:

**Progress** 
    A spinner or counter feature will be displayed during time
    consuming operations. The time consuming operations include
    fitting, deserializing a fit, running the pathfinder, and building
    a histogram. In screen mode, your objects will have a ``thingy``
    attribute which is set to an anonymous array containing the frames
    of the spinner. You can change the spinner by changing that
    attribute. `Term::Twiddle
    <https://metacpan.org/pod/Term::Twiddle>`_ is used to make the
    spinner.

**Colored feedack**
    Feedback from the executions of :demeter:`feff` and
    :demeter:`ifeffit` will be highlighted using `Term::ANSIColor
    <https://metacpan.org/pod/Term::ANSIColor>`_. This is mostly used
    to draw attention to warning and error messages as well as certain
    kinds of status messages.

**Colored exception handling**
    Errors and problems that result in a call to ``warn`` or ``die``
    will get a bit of collor coding (yellow and red text respectively.
    These will also return complete stack traces to help debugging
    efforts.

**Fit interview**
    You have access to the fit interview, which provides a bit of
    keyboard driven interaction for plotting, examining parameter
    values, reading and log files. You can think of this as a poor man's
    :demeter:`artemis`. Just do

    .. code-block:: perl

       $fit_object -> interview; 

    after a fit.

**Pause**
    You have a simple way of pausing the flow of your script and
    displaying a prompt.

    .. code-block:: perl

       $any_object -> pause; 

    This will pause the flow of your program and print
    ``Hit return to continue>`` in underlined text. You can specify the
    text by doing:

    .. code-block:: perl

       $any_object -> pause("Try to jump up and down three times before the fit finishes...");

    This is particularly useful when using the gnuplot plotting backend.
    Gnuplot's normal behavior is to close at the end of the script.
    Using the pause allows you time to examine a plot before ending your
    program.


Graphical interface
-------------------

Describing GUIs is well beyond the scope of this document.
:demeter:`demeter` can be used with just about any interface toolkit.
GUIs for :demeter:`artemis`, :demeter:`atoms`, and
:demeter:`hephaestus` using wxWindows come with the :demeter:`demeter`
package and there is substantial functionality for Wx that has been
baked into those parts of :demeter:`demeter`.  But there is nothing
that explicitly ties anything described in this document to Wx.



Web interface
-------------

.. todo:: Expose some fraction (possibly all...) of :demeter:`demeter` via XML-RPC.



Plotting backends
-----------------

-  pgplot

-  gnuplot

-  singlefile, not really a display backend, more of an export tool for
   using some other program to make beautiful, publication-quality plots

