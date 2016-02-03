..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Command disposal and command templates
======================================

:demeter:`demeter` uses a highly abstract system for communicating
with :demeter:`feff`, :demeter:`ifeffit`, and the plotting
backend. The `Text::Template
<https://metacpan.org/pod/Text::Template>`__ module is used along with
a large number of small, external template files. The idea behind
`Text::Template <https://metacpan.org/pod/Text::Template>`__ is quite
simple.  Perl code is interspersed with normal text.  A pass over the
text is made and the perl code is evaluated.  In this way, a bit of
text is made that is specifically relevant to a particular situation.
As an example, here is the template that :demeter:`demeter` uses to
construct the :demeter:`ifeffit` command used to normalize the
|mu| (E) data associated with a Data object.

::

    { # -*- ifm -*-
      # pre-edge template
      #   {$D->group} returns the ifeffit group name
      #   {$D->parameter} returns the value of that parameter
    }

    pre_edge("{$D->group}.energy+{$D->bkg_eshift}", 
             {$D->group}.xmu, 
             e0         = {$D->bkg_e0},
             pre1       = {$D->bkg_pre1}, 
             pre2       = {$D->bkg_pre2}, 
             norm_order = {$D->bkg_nnorm},
             norm1      = {$D->bkg_nor1}, 
             norm2      = {$D->bkg_nor2})

In this example, ``$D`` represents the Data object. Thus
:demeter:`ifeffit`'s ``pre-edge`` command is filled in with attribute
values appropriate to the current Data object.

The text generated from the processing of the template is then
disposed of via one or more avenues, one of which may include sending
the text to :demeter:`ifeffit` for processing.

This section explains all of the disposal and templating options
available to a :demeter:`demeter` program.


Command disposal
----------------

Once commands have been processed using the templating system, there are
seevral avenues for disposing of those commands. The most obvious avenue
is to send the commands to :demeter:`ifeffit` so that the actual data can be
processed. However, several other options are possible.

The ``dispose`` method is a method of the base class and inherited by
all objects. It is used all throughout :demeter:`demeter` to get things done and is
available for explicit use in :demeter:`demeter` programs. The syntax is quite
simple:

.. code-block:: perl

      $any_object -> dispose($text);
      $any_object -> dispose($text, 'plotting'); 

The first line is used for any data processing command. The second form,
with the second argument to the method, is used to identify command text
which is explicitly used to make plots. When using the PGPLOT plotting
back end, there is not actually a significant difference between
plotting and non-plotting commands since :demeter:`ifeffit` is used to send command
to PGPLOT. However, when using other plotting backends, it is essential
that plotting commands be apprpriately flagged. Plotting backends are
discussed in more detail in `the user interface chapter <../ui.html>`__.

The ``$text`` given as an argument to the ``dispose`` method typically
comes from the evaluation of a template, but can be any text generated
in any fashion. Thus, it is a completely generic way for a program to
communicate with :demeter:`demeter`'s backends.

The targets of the ``dispose`` method are set using the ``set_mode``
method, another method of the base class which is inherited by all
objects. The syntax of ``set_mode`` is consistent with other methods in
:demeter:`demeter`:

.. code-block:: perl

   $any_object -> set_mode(screen=>1, backend=>1);

Any command can be sent to multiple targets. The disposal targets which
can be set using ``set_mode`` are:

``ifeffit``
    When true, commands will be sent to :demeter:`ifeffit`. It is often useful to
    turn this disposal target off when debugging :demeter:`demeter` programs.
``screen``
    When true, commands will be sent to standard output (usually the
    screen). Turning this disposal target on is often useful when
    debugging :demeter:`demeter` programs.
``plotscreen``
    When true, plotting commands will be sent to standard output
    (usually the screen). Turning this disposal target on is ofetn
    useful when debugging :demeter:`demeter` programs.
``repscreen``
    When true, the reprocessed commands (discussed below) will be sent
    to standard output (usually the screen).
``file``
    When set to a string value, that string will be interpretted as a
    file name to be opened for writing and the commands will then be
    written to that file. To append text to a file, the ``file`` mode
    string should begin with the ``>`` character.
``plotfile``
    When set to a string value, that string will be interpretted as a
    file name to be opened for writing and the plotting commands will
    then be written to that file. To append text to a file, the ``file``
    mode string should begin with the ``>`` character.
``repfile``
    When set to a string value, that string will be interpretted as a
    file name to be opened for writing and the reprocessed commands
    (discussed below) will then be written to that file. To append text
    to a file, the ``file`` mode string should begin with the ``>``
    character.
``buffer``
    When set to an array reference, commands will be pushed onto that
    array. When set to a scalar reference, commands will be concatinated
    to the end of the strings held by the scalar.
``plotbuffer``
    When set to an array reference, plotting commands will be pushed
    onto that array. When set to a scalar reference, plotting commands
    will be concatinated to the end of the strings held by the scalar.
``callback``
    When set to a code reference, the text of the command will be sent
    to that code reference as the sole argument. This is useful for user
    interfaces that want to post-process the commands. For example, this
    disposal mode is used by :demeter:`artemis` to display colorized text in its
    command buffer.
``plotcallback``
    When set to a code reference, the text of the plotting command will
    be sent to that code reference as the sole argument. This is useful
    for user interfaces that want to post-process the commands. For
    example, this disposal mode is used by :demeter:`artemis` to display colorized
    text in its plotting buffer.
``feedback``
    When set to a code reference, the text of :demeter:`ifeffit`'s response to
    commands will be sent to that code reference as the sole argument.
    This is useful for user interfaces that want to post-process the
    commands. For example, this disposal mode is used by :demeter:`artemis` to
    display colorized text in its command buffer.



Reprocessed commands
--------------------

:demeter:`demeter` tries to use :demeter:`ifeffit` as efficiently as possibly. On one hand,
:demeter:`ifeffit` the one of the things that makes :demeter:`demeter` go and so is
indispensible. On the other hand, the business of communicating between
perl code and the :demeter:`ifeffit` library is (`with one
exception <../feff/pathfinder.html>`__) always the slowest thing that
:demeter:`demeter` does. One of the optimizations implemented by :demeter:`demeter` is the
reprocessing of commands targeted for disposal to :demeter:`ifeffit`.

Command strings in :demeter:`ifeffit` can be quite long -- up to 2048
characters as it is normally compiled. A command that is split over
multiple lines, as the example at the beginning of this section is,
will be processed much faster if :demeter:`demeter` pre-processes the
command to remove unnecessary line breaks. Basically this means that
everything between parentheses will be sent to :demeter:`ifeffit` as a
single string. This is accomplished within the ``dispose`` method via
the application of a few regular expressions. The reprocessed string
is then sent to :demeter:`ifeffit`.

As a small example of how reprocessing works, this human-friendly
command:

::

    pre_edge("data0.energy+0",
             data0.xmu,
             e0         = -9999999,
             pre1       = -150,
             pre2       = -30,
             norm_order = 3,
             norm1      = 150,
             norm2      = 1800)                                                                                            

will be reprocessed into this one-line command before being shuffled off
to :demeter:`ifeffit`.

::

    pre_edge("data0.energy+0", data0.xmu, e0=-9999999, pre1=-150, pre2=-30, norm_order=3, norm1=150, norm2=1800)

which, when summed over dozens or hundreds of :demeter:`ifeffit` commands, results
in a substantial performance improvement.

The ``repscreen`` and ``repfile`` disposal targets are provided to
debug the behavior of this optimization. Reprocessing is quite well
tested.  However, if you suspect that reprocessing is damaging the
commands sent to :demeter:`ifeffit`, use one of those disposal
channels to see the text that is actually being sent.



Command templates
-----------------

:demeter:`demeter` ships with **a lot** of templates. Each template
encapsulates a small bit of functionality and :demeter:`demeter` does
many things. The templates are organized into “:quoted:`template
sets`, which are written for specific backend targets, and “template
groups” which, are groups of templates which serve related
functions. All template sets must have a complete representation of
template groups to be fully functional.

The templates are found in :file:`lib/templates/` directory underneath
the installation location of the :demeter:`demeter` package. One of
the reasons for explaining the templating system in this level of
detail is to underscore that it is quite possible to add new template
sets. By following the model of the existing template sets, new output
types can be created for :demeter:`demeter`. Indeed, when finally
makes its appearence, it should be relatively simple to extend
:demeter:`demeter` to use it simply by creating an apprporiate
template set.

Choosing between template sets is one of the topics of `the next
section <mode.html>`__.



Template sets
~~~~~~~~~~~~~

Template sets describe backend targets for disposed commands. There are
four different categories of template sets:

#. Data processing commands

#. Plotting commands

#. :demeter:`feff` input templates

#. :demeter:`atoms` input templates

:demeter:`demeter` currently ships with five different sets in the data processing
category.

#. ``ifeffit``, templates which write the syntax of :demeter:`ifeffit`
   in a compact form

#. ``larch``, templates which write the syntax of :demeter:`larch`

#. ``iff_columns``, templates which write the syntax of
   :demeter:`ifeffit` is a more human-readable form

#. ``feffit``, templates which write the syntax of input files for the
   old :demeter:`feffit` program.  *incomplete*

#. ``demeter``, templates which write out perl syntax using
   :demeter:`demeter`.  *incomplete*

The ``demeter`` category might seem a bit strange. Its purpose is,
indeed, to allow :demeter:`demeter` programs to write
:demeter:`demeter` programs. The intent is to allow a GUI to export a
file containing a :demeter:`demeter` program that can be used to make
a fit using the same fitting model that was created using the GUI.

The possibility of having these different output targets is the main
reason for using a templating system. Having command creation
containined in these small template files separate from the code may
seem like an unnecessary layer of abstraction and misdirection, but it
offers :demeter:`demeter` a lot of flexibility and power. This is even
more evident for the plotting backends.

:demeter:`demeter` currently ships with three different sets in the
plotting category. More information about plotting backends can be
found in `the user interface chapter <../ui.html>`__.

#. ``pgplot``, templates which write the syntax of :demeter:`ifeffit` plotting
   commands, which talk directly to :program:`PGPLOT`.

#. ``gnuplot``, templates which write :program:`Gnuplot` plotting
   scripts. Using :program:`Gnuplot` involves writing lots of temporary
   files which contain the data to be plotted. It also requires that
   :program:`Gnuplot` be installed on your computer, which is something
   that you have to do separate from the installation of
   :demeter:`demeter`.

#. ``singlefile``, this set of templates is used to export the data to
   be plotted to a single column file. The main use of this is in a GUI
   to exprt a file that can be used to replicate an interesting plot --
   with offsets, energy shifts, and scaling factors -- in an external
   plotting program.

In the future, I would like to add more plotting backends to
:demeter:`demeter`.  Certainly, any of the plot creation tools from
CPAN (such as `GD <http://search.cpan.org/~lds/GD/>`__ or `Chart
<http://search.cpan.org/~chartgrp/Chart/>`__) would be possible, as
would something like `Grace
<http://plasma-gate.weizmann.ac.il/Grace/>`__, which uses a text file
as its input.

:demeter:`demeter` currently ships with two different sets in the
:demeter:`feff` input template category, one for :demeter:`feff6` and
one for :demeter:`feff8`. (Actually the :demeter:`feff8` set has not
yet been written at the time this document is being written.  In fact,
:demeter:`demeter`'s :demeter:`feff8` interface has not yet been
started.

There is only one set in the :demeter:`atoms` input template
category. It seems unlikely that other sets will actually be required.



Template groups
~~~~~~~~~~~~~~~

Template groups define related chores. These chores are

#. ``process``: all data processing chores that do not involve fitting
   |chi| (k) data or doing any other sort of data analysis.

#. ``fit``: all chores associated with fitting |chi| (k) data.

#. ``analysis``: all analysis chores other than those associated with
   fitting |chi| (k) data. This might include things like linear
   combination fitting. principle component analysis, or
   log-ratio/phase-difference analysis.

#. ``plot``: all chores associated with plotting data

#. ``report``: generation of textual reports

#. ``plugin``: data processing chores performed by filetype or other
   plugins

The first four groups must be provided completely by any template set.
Although if a template is missing from a template set,
:demeter:`demeter` will fall back to using the template for that chore
found in the ``ifeffit`` set.



The template method
~~~~~~~~~~~~~~~~~~~

When the ``template`` method is called, a number of variables are set
for use in the template. These variables are set appropriately for the
contect in which the ``template`` method is called. You can see one
example of this in the example at the beginning of this section. The
``$D`` variable represents the Data object relevant to the context in
which that template is evaluated. Some more examples will be seen below.

Here is the complete list of these special variables.

``$S``
    This is the “self” object, i.e. the object that called the
    ``template`` method.
``$D``
    The is the Data object of the calling object. When a Data object is
    the caller, ``$S`` and ``$D`` are the same thing. For a Path object
    as ``$S``, ``$D`` is its associated Data object.
``$P``
    This is the Plot object.
``$C``
    This is the Config object.
``$F``
    This is the currently active Fit object.
``$DS``
    This is the currently active Data standard.
``$T``
    This is the currently active Feff (i.e. theory) object.
``$PT``
    This is the currently active Path object.

The syntax of the ``template`` method is relatively simple. The method
takes two arguments, the first identifying the template group, the
second identifying the chore that the template performs. Identifying the
specific template also requires the template set, which is an attribute
of the `Mode group <mode.html>`__.

.. code-block:: perl

    my $string = $self->template("process", "fft");
    $self->dispose($string);

In this example, the command to make a forward Fourier transform using
the current template set is generated by evaluating the appropriate
template. The text of this command is then passed to the ``dispose``
method.

Some templates require data that is not normally available from any
attribute of any object. There are two ways of addressing that
situation. One is to store an arbitrarily named attribute in the Config
object. This is done like so:

.. code-block:: perl


    $config->set(conv_type  => $args{type},
                 conv_width => $args{width},
                 conv_which => $args{which},
                );
    my $string = $self->template("process", "convolve");
    $self->dispose($string);

Here three scalars related to data covolution are set in the Config
object. Here is how those scalars are used:

::

    {
      $x = ($C->get("conv_which") eq 'xmu') ? 'energy' : 'k';
      $type = 'gconvolve';
      ($type = 'lconvolve') if (lc($C->get("conv_type")) =~ m{\Al});
      q{}
    }
    ##|
    ##| convolution {$D->group}
    set {$D->group}.{$C->get("conv_which")} = {$type}({$D->group}.{$x}, {$D->group}.{$C->get("conv_which")}, {$C->get("conv_width")})
    ##|

Note that this example uses the ``$C`` special template variable to
access the Config object and the Config object's ``get`` method to
oibjtain the values of these arbitrarily named scalars.

The other approach to passing arbitrary data to a template is to provide
a hash reference as the third argument of the ``template`` method.

.. code-block:: perl

    $command = $self->template("plot", "marker", { x => $xx, 'y'=> $y });

These user-defined parameters are then accessed by name in the template.
This example also shows the use of the ``$P`` special variable to make
reference to the Plot object.

::

    plot_marker({$x}, {$y}, marker={$P->markertype}, color={$P->markercolor})

