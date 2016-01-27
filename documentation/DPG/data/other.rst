..
   Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Handling arbitrary data
=======================

At times you might find a need to import data from an arbtrary file
that :demeter:`demeter` knows nothing about or for which a filetype
plugin does not exist. In that case, :demeter:`demeter` offers its
most bare-bones approach to creating a Data object.

The ``put`` method is used to create a new Data object from two perl
arrays containg the energy and |mu| (E) data.

.. code-block:: perl

   $data = Demeter::Data -> put(\@energy, \@xmu);

The ``put`` method returns a normal Data object. The two arguments are
array references containing the data.

This method is useful when :demeter:`demeter` provides no other way of
importing data, in which case you will have to write a program to
disentangle the data and insert it into two arrays. Another use might
be when generating data, possibly artifical or theoretical data,
algorithmically.

You can supply attribute values in the same manner as the ``new`` or
``set`` methods.

.. code-block:: perl

   $data = Demeter::Data -> put(\@energy, \@xmu, @args); 

If you are creating a Data object to hold |chi| (k) data rather than
|mu| (E) data, you must use the additional arguments, as this method
sets the ``datatype`` attribute to “xmu”.

.. code-block:: perl

   $data = Demeter::Data -> put(\@energy, \@xmu, datatype=>'chi');
