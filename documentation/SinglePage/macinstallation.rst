.. Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Installing Demeter on the Mac
=============================


The Macintosh package uses `MacPorts <https://www.macports.org/>`_ and
is currently at version 0.9.22.

.. admonition:: Note

   Bruce does not own a Mac and cannot support Mac installation
   problems.  You should use the `mailing list
   <http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>`_.


Short instructions
------------------

#. **Carefully** follow the steps to install Macports at
   https://www.macports.org/install.php.

#. Open a new Terminal window and type the following:

   .. code-block:: bash

      sudo port install xorg-server demeter 

   It will take a while depending on your computer and network speed.

#. If this is your first time installing ``xorg-server``, log out and
   log back in. This is needed to set the ``DISPLAY`` environment
   variable.

#. If you have recently upgraded to a new version of the Mac operating
   system, you must re-install all of MacPorts for the new OS.  There
   is no shortcut.

When installation of MacPorts is done, launch :demeter:`athena` by
typing the following in Terminal:

.. code-block:: bash

   athena 


Note: Make sure you are in a directory you have write permission to
(like your home directory) because hidden files are created at launch
time.

To update a previously installed version of :demeter:`demeter` to the
latest, open a Terminal window and do

.. code-block:: bash

   sudo port selfupdate && sudo port upgrade demeter

If you are not using a system-wide MacPorts installation, running
commands as sudo is not necessary.

 
Troubleshooting problems on the Mac
-----------------------------------

**General problems**

  Having trouble installing on your Mac computer? `This might help
  <http://bruceravel.github.io/demeter/documents/SinglePage/macports.html>`_
  or you `might find help searching through the mailing list archives
  <http://www.mail-archive.com/ifeffit@millenia.cars.aps.anl.gov/>`_.


**Plot window not appearing**

  If installation has proceeded properly, but the plot window is not
  appearing, `this might fix the problem
  <http://www.mail-archive.com/ifeffit@millenia.cars.aps.anl.gov/msg05440.html>`_,
  however it is unlikely that deglitching or the pluck buttons will
  work with the aqua terminal.

**Failed to install libcxx**

  According to `Wayne
  <http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2016-November/008860.html>`_
  `Lukens
  <http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2016-November/008890.html>`_,
  macports sometimes does not install all of the dependencies for
  :demeter:`demeter`.  You can solve this issue by loading the
  dependencies separately.  Do

  .. code-block:: bash

     sudo ports install libcxx

  After that, try installing :demeter:`demeter` again.

  Also, `Jean-Francois Gaillard
  <http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2016-November/008863.html>`_
  offers this hint: "One thing that greatly improve the installation
  of dependencies was to increase the number of files that can be open
  at once. New versions of Mac OS X limit this nb to 256, if you
  increase it to - let’s say to 1024 - in your session it should
  help. To find out the max nb of files that you can open at once type
  in a terminal 

  .. code-block:: bash

     ulimit –a

  and to increase the number type

  .. code-block:: bash

     ulimit –n1024



Please report problems with the MacPorts package to the `Ifeffit
mailing list <http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>`_.

.. admonition:: Note

   Bruce does not own a Mac and cannot support Mac installation
   problems.  You should use the `mailing list
   <http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>`_.
