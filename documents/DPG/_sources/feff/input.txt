..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Input data for Feff
===================


Starting from a conventional feff.inp file
------------------------------------------

:demeter:`feff` is, let's face it, a bit long in the tooth. It
requires that its instructions be contained is a rather rigidly
structured textual input file. The keywords of the file are called
:quoted:`cards` in the :demeter:`feff` documentation |nd| a word whose
etymology probably escapes :demeter:`feff`'s younger users.

:demeter:`demeter` goes through some serious gymnastics in an attempt
to hide :demeter:`feff`'s clunky interface. The need for an input file
is unavoidable and :demeter:`demeter` does, in fact, read in and write
out :file:`feff.inp` files repeatedly.  It does so, however, in a
stealthy way that should require the attention of the programmer using
:demeter:`demeter` only at the very beginning of the process.

Creating a Feff object and populating it with the contents of a
:file:`feff.inp` file is done in a way that should be quite familiar
at this point:

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $feff = Demeter::Feff -> new(file => "feff/feff.inp");
    $feff->set(workspace=>"feff/", screen=>0);

Because :demeter:`feff` is heavily dependent on disk-based IO to do
its work, you must specify a ``workspace``. This is a directory on
disk where the various files that :demeter:`feff` needs to do its
business can be written. In the example that will be running through
this section, that workspace is a subdirectory called :file:`feff/`.

The ``screen`` attribute is a boolean which will suppress the messages
the FEFF would normally write to standard output when set to 0.

When the ``file`` attribute is set, that input file will be parsed and
its contents stored as attributes of the Feff object. At this point, the
new Feff object is fully instrumented and ready to start being used for
interesting work.



Starting from an Atoms object
-----------------------------

If you are running :demeter:`feff` on a crystalline material for which
you have an :file:`atoms.inp` or CIF file, then :demeter:`demeter`
also allows you to skip the step fo explicitly writing the
:file:`feff.inp` file. Insetad of setting the ``file`` attribute of
the Feff object, you can set the ``atoms`` attribute to an Atoms
object.  The :file:`feff.inp` still gets generated, but it is done
behind the scenes using a temporary file that is quickly discarded.

.. code-block:: perl

    #!/usr/bin/perl
    use Demeter;

    my $atoms = Demeter::Atoms -> new(file => 'atoms.inp');
    my $feff = Demeter::Feff -> new(atoms => $atoms);
    $feff->set(workspace=>"feff/", screen=>0);

When the ``atoms`` attribute is set, the :file:`feff.inp` file is created,
parsed, then deleted. Its contents are stored as attributes of the Feff
object. At this point, the new Feff object is fully instrumented and
ready to start being used for interesting work.

This approach is convenient in any situation for which you do not need
to modify :demeter:`feff` input data in any way from the form that the
:demeter:`atoms` calculation generates. In that situation, this
approach to :demeter:`feff` is identical in every way to starting from
a :file:`feff.inp` file.


Starting from a molecular structure file
----------------------------------------

.. todo:: Integration with `OpenBabel <http://openbabel.org/>`__ so
	  that other cluster file formats can be used directly as
	  input to :demeter:`feff`.

