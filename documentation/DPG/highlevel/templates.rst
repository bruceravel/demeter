..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

.. highlight:: perl


Demeter's templating system
===========================



:demeter:`demeter` uses `Text::Template
<https://metacpan.org/pod/Text::Template>`_ to construct all text
destined for :demeter:`ifeffit` or :demeter:`larch` as well as for
:demeter:`atoms` and :demeter:`feff` input files and the plotting
backends.  The use of templating system add a bit of complexity to
:demeter:`demeter` in the sense that the actual content of
:demeter:`ifeffit` or :demeter:`larch` commands (or input files) is
generated quite far away from the location in the code where that text
is used.  However, the use of a templating system adds a lot to
:demeter:`demeter`.  Output can be highly customized or directed to a
different target altogether.  For example, it is already possible in
version 0.2 to generate content for a :file:`feffit.inp` file rather
than for an :demeter:`ifeffit` or :demeter:`larch` script.  In the
future, templates will make it easy for :demeter:`demeter` to target
multiple plotting backends, write out functional :demeter:`demeter`
scripts, use other :demeter:`feff` versions, and so on.

`Text::Template <https://metacpan.org/pod/Text::Template>`_ is
wonderful |nd| it hits a real sweet spot between simple and powerful.
A template in this system is plain text with snippets of perl code
interspersed.  Here is an example:


.. code-block:: perl

    { # -*- ifm -*-
      # Forward transform template
      #   {$D} returns the ifeffit group name
      #   {$D->get("parameter")} returns the value of that parameter
    }
    fftf({$D->group}.chi,
         k        = {$D}.k,
         kmin     = {$D->fft_kmin},
         kmax     = {$D->fft_kmax},
         dk       = {$D->fft_dk},
         kwindow  = {$D->fft_kwindow},
         kweight  = {$D->get_kweight},
         rmax_out = {$D->rmax_out})


This is the template for generating a forward Fourier transform
command using the ``iff_columns`` template set.  Anything contained in
curly brackets is interpreted as perl, everything else is plain text
that gets passed through the templating system unaltered.

The way that this template gets used is like so:


.. code-block:: perl

   $data -> set_mode(template_process => "iff_columns");
   $string = $data -> template("process", "fft");
   $data -> dispose($string);


The first line chooses the template set.  The second line fills in the
``fft`` template from the *process* template group|/TEMPLATE GROUPS
using the parameters of the Data objects contained in ``$data``.  The
``template`` method returns a string containing the appropriate
:demeter:`ifeffit` or :demeter:`larch` commands.  This string is
`disposed <dispose.html>`_ in the last line.

:demeter:`demeter` uses certain conventions to push particular data into a
template.  You can see two of those conventions in this example.
``$D``, when used inside of curly braces, refers to the Data object of
the referent.  ``$P`` refers to the current Plot object, which is
defined as the \ ``plot``\  mode parameter.

Within the curly braces, :demeter:`demeter` syntax is used and
:demeter:`demeter` methods are used to get data out of
:demeter:`demeter` objects.  Some templates contain more complicated
blocks of code, such as loops or control structures.  Most
curly-brackets perl blocks are simply object accesses, such as in the
example above.

Here is a complete list of the special scalars for accessing
:demeter:`demeter` objects in templates.


``$S``
 
 This refers to the object that invoked the ``template`` method.
 


``$D``
 
 This refers to the Data object associated with the object that invoked
 the ``template`` method.  For a Data object, ``$S`` and ``$D`` point at
 the same object.  For a Path, SSPath, or VPath object, however, ``$D``
 points at the Data object to which that Path object belongs.
 


``$P``
 
 This refers to the default Plot object.  This is the same object that
 gets returned by ``po`` method of the base class.
 


``$C``
 
 This refers to the Config object containing all the data from the
 configuration subsystem.  Note that you should use the ``default`` (or
 possibly ``demeter``) method to access system configuration parameters.
 
 The other use of ``$C`` is to access user-defined parameters.  The
 merge templates for example make extensive use of this to set, for
 example, the boundaries of the merge range and the space in which the
 merge takes place.  See Demeter::Config for details on setting
 user-defined Config parameters.  For user-defined parameters, you
 should use the ``get`` method.
 


``$F``
 
 This refers to the current Fit object.  Normally, the ``fit`` or
 ``sum`` method of the Demeter::Fit class will set the default for
 you.
 


``$DS``
 
 This refers to the data object chosen as the data standard, as
 `explained here <dispose.html>`_.
 Data processing methods such as ``align`` will set the data standard so
 that ``$DS`` evaluates correctly in templates.
 


``$T``
 
 This refers to the active Feff object and is mostly used to generate
 :file:`feff.inp` files.
 


``$A``
 
 This refers to the Atoms object from which a :file:`feff.inp` is
 being generated.
 


There is one final mechanism for moving data into a template.  This
method is quite similar to user-defined Config attributes, but may be
more convenient.  You can supply an additional argument to the
``template`` method which is an anonymous hash.  An example would be
the ``save_xmu`` template from the *process* tamplate group.  It is
called like so in ``save_xmu`` in ``Demeter::Data::Mu``:


.. code-block:: perl

    my $string = $self->template("process", "save_xmu",
                                 {filename => $filename,
 				 titles   => "dem_data_*"});


The corresponding template looks like this:


.. code-block:: perl

   write_data(file="{$filename}", ${$titles}, ${$D->group}_title_*,
              {$D->group}.energy, {$D->group}.xmu, {$D->group}.bkg, {$D->group}.pre_edge,
              {$D->group}.post_edge, {$D->group}.der, {$D->group}.sec)


Here the filename and titles glob are passed in the anonymous hash and
accessed in the template via their hash keys inside of curly brackets.



Template Groups
---------------


:demeter:`demeter` has a lot of templates and they are grouped according to
general function as a way fo imposing some order on their large
numbers.  The (currently) five template groups are:


*analysis*
 
 These templates are used for analysis chores that do not involve
 Feff. Things such as linear combination fitting and difference
 spectra go into this template group.
 


*atoms*
 
 These templates are used by the Atoms object to structure its output
 files.  Although in the future I hope to use OpenBabel to direct lists
 of atomic coordinates to differnt output targets, you could put a
 template in this group to make, say, an alchemy file.
 


*feff*
 
 These templates are used to structure *feff.inp* files made using
 Feff objects as part of :demeter:`demeter`'s rewrite of
 :demeter:`feff` fucntionality.
 


*plot*
 
 These templates are used to generate plotting commands from Data or
 Path objects.
 


*process*
 
 All the rest of the templates go into this group.  Everything involved
 in reading, writing, or processing data goes in this template group.
 




Template Sets
-------------


Within the different template groups, you may find multiple template
sets.


*feff*
 
 The *feff* template group has sets for :quoted:`feff6`,
 :quoted:`feff7`, and :quoted:`feff8`.  The feff template set is
 chosen by setting the ``template_feff`` mode
 


*plot*
 
 The plotting template sets are :quoted:`pgplot`, :quoted:`gnuplot`,
 and :quoted:`demeter`.  The first two generate commands for the
 currently available plotting backends.  The last is intended for use
 with the :demeter:`demeter` fitting and processing template set.  In
 the future new sets may be written for different plotting backends
 (for example, Grace would be a target that would work very well
 within :demeter:`demeter`).  The plot template set is chosen by
 setting the ``template_plot`` mode.
 


*fit* and *process*
 
 Template sets exist for :demeter:`ifeffit`, :demeter:`larch`,
 :demeter:`feffit`, and :demeter:`demeter`.  There are two version of
 the :demeter:`ifeffit` template set called :quoted:`ifeffit` and
 :quoted:`iff_columns`.  The first set uses a fairly terse style while
 the second one tries to align :demeter:`ifeffit` command arguments
 into columns aligned at the equals sign wherever possible.  The
 second one may be a bit more human readable.  The fit and process
 template sets are chosen by setting the ``template_fit`` and
 ``template_process`` modes.
 


:demeter:`atoms` does not use template sets and currently there are
only :demeter:`ifeffit` and :demeter:`larch` sets for the *analysis*
group.


Diagnostics
-----------

``Unknown Demeter template file: group $group; type $file; $tmpl``
 
 You specified a combination of template group and template file that
 does not exist.
 
----

.. todo:: New template sets:

	  * More plotting backends?  Matplotlib?  thers?


