..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Mode object
===========

The Mode object is a singleton created automatically when an instance of
a :demeter:`demeter` program is started. The Mode object is the thing that keeps
track of the state of everything in a :demeter:`demeter` program. For example,
attributes of the mode are used to set the `disposal
channel <dispose.html#commanddisposal>`__ and the `template
set <dispose.html#templatesets>`__.

To make the Mode object readily accessible at all times in your
program, the ``mo`` method is a method of the base class and is
inherited by all :demeter:`demeter` objects.  Thus, given any object,
you can :quoted:`find` the Mode object like so:

.. code-block:: perl

   $the_mode_object = $any_object -> mo;

To choose disposal channels, use the ``set_mode`` method. For instance,
to direct output to both :demeter:`ifeffit` and to the screen (which is useful for
debugging purposes)

.. code-block:: perl

   $any_object -> set_mode(backend=>1, screen=>1); 

To then turn off screen output:

.. code-block:: perl
		
   $any_object -> set_mode(screen=>0); 

The Mode object does a lot more that. It keeps count of the number of
data sets used in a fitting model so that :demeter:`ifeffit`'s
``feffit`` command works properly for a multiple data set fit. It
keeps track of the number of fits that have been run in the current
instance of the :demeter:`demeter` program. And it keeps track of the
indexing of Path objects. It also keeps track of the directory in
which the :demeter:`demeter` program started and of the current
working directory as the program proceeds. For a full list of the
atttributes, see the documentation for the Demeter::Mode object.

Other attributes keep track of every object created during and instance
of :demeter:`demeter`:

.. code-block:: perl

  my @all_atoms  = @{ $any_object->mo->Atoms };
  my @all_data   = @{ $any_object->mo->Data };
  my @all_feff   = @{ $any_object->mo->Feff };
  my @all_fit    = @{ $any_object->mo->Fit };
  my @all_gds    = @{ $any_object->mo->GDS };
  my @all_path   = @{ $any_object->mo->Path };
  my @all_plot   = @{ $any_object->mo->Plot };
  ##  ... and so on ... one for each kind of object

The accessor returns an array reference. The ``@{ }`` syntax
dereferences the array. References in perl are explained in detail in
the `perlref document <http://perldoc.perl.org/perlref.html>`__.

The ``everything`` method returns references to every object created
during the instance of the :demeter:`demeter` program.

.. code-block:: perl

   my @all_of_them = $any_object->mo->everything; 

The ``fetch`` method can be used to find a particular object given the
value of its ``group`` attribute, which is a randmoly generated string
that gets made when the object is created. This is most useful when
deserializing a save file. This example finds a Data object:

.. code-block:: perl

   my $object = $any_object->mo->fetch("Data", $group_name);
