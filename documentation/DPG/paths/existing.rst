
Running Feff outside of Demeter
===============================



Using a single feffNNNN.dat file
--------------------------------

You can import feffNNNN.dat files from a :demeter:`feff` calculation run outside of
:demeter:`demeter`. Explicitly specify the ``folder`` and ``file``.

.. code-block:: perl

  $path -> new(data     => $data,
               folder   => './',
               file     => 'feff0001.dat',
               s02      => 'amp',
               e0       => 'enot',
               delr     => 'alpha*reff',
               sigma2   => 'debye(temp, theta) + sigmm',
              );

Importing an external Feff calculation
--------------------------------------

.. todo:: Document Demeter::Feff::External

