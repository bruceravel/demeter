..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

High level actions of the object model
======================================

All :demeter:`demeter` objects inherit from the base Demeter
class. This class defines a variety of methods that are then inherited
by all other objects. At the end of this chapter, you will understand
how :demeter:`demeter` command and template system works to generate
command for :demeter:`ifeffit` and for plotting. This chapter also
covers the three special object types, Demeter::Mode, Demeter::Plot,
and Demeter::Config, which together provide fine grained control over
virtually all aspects of what :demeter:`demeter` programs can
accomplish.

Both the Mode and Config objects are singletons, which means that any
instance of a :demeter:`demeter` program can have one and only
instance of Mode or Config object. The Plot object is not a singleton,
but it is unusual to need or want a second instance of a Plot object.

Each of these special objects has an associated method of the base class
used for accessing the object. They are demonstrated here:

.. code-block:: perl

      my $mode_object   = $object -> mo;
      my $plot_object   = $object -> po;
      my $config_object = $object -> co; 

In this example, ``$object`` can be any :demeter:`demeter`
object. Every object type inherits these three methods, each of which
returns its object.  That is, ``mo`` returns the Mode object, ``co``
returns the Config object, and ``po`` returns the currently active
Plot object.

Thus you can access the attributes and methods of these three special
objects at any time using any :demeter:`demeter` object that is handy
at that point in your program.

---------------------

**Contents**

.. toctree::
   :maxdepth: 2

   dispose.rst
   mode.rst
   plot.rst
   config.rst
   methods.rst
