.. Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Installing Demeter from packages: Windows, Mac, Linux
=====================================================

If you run into problems, use `The Ifeffit mailing list
<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>`_.  Be as
explicit as possible about the nature of the problem and remember that
saying :quoted:`This is my problem and this what I've tried so far to
fix it` is much more valuable than just :quoted:`This is my problem.`.


Windows
~~~~~~~

Most people installing Demeter on a Windows machine will want to use
the installer and updater packages.  The latest packages can be `found
here <http://bruceravel.github.io/demeter#windows>`_.

Download, double click, answer a few questions.  It's that simple.

There is **not** an automated updater for the software.  You must
download the updater and install it yourself.


Macintosh OSX
~~~~~~~~~~~~~

Frank Schima and Joe Fowler have performed yeoman's duty by making
Demeter and its tool chain available on `MacPorts
<http://www.macports.org/>`_.

The Macintosh package uses `MacPorts <http://www.macports.org/>`_ and
may lag a bit behind the :demeter:`demeter` source code.

#. **Carefully** follow the steps to install Macports at
   http://www.macports.org/install.php.

#. Open a new Terminal window and type the following:

   ::

     sudo port install xorg-server demeter 

    It will take a while depending on your computer and network speed.

#. If this is your first time installing ``xorg-server``, log out and
   log back in. This is needed to set the ``DISPLAY`` environment
   variable.
 
#. If you have recently upgraded to a new version of the Mac
   operating system, you must re-install all of MacPorts for the new
   OS. There is no shortcut.

When installation of MacPorts is done, launch :demeter:`athena` by
typing the following in Terminal:

::

   athena 

..Note:: Make sure you are in a directory you have write permission to
  (like your home directory) because hidden files are created at
  launch time.

To update a previously installed version of Demeter to the latest,
open a Terminal window and do

::

   sudo port selfupdate && sudo port upgrade demeter

If you are not using a system-wide MacPorts installation, running
commands as sudo is not necessary.


`Laila Al-Madhagi's hints for successfully installing on the Mac.
<mac.rst>`_


Windows under emulation on the Macintosh
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Windows installer can be used under emulation.

While there is not yet a native Mac OS installer for Demeter, it can
be run under Windows using the `Parallels virtual environment
<http://www.parallels.com/>`_. This has been tested using Windows XP
in Parallels 6 running under Snow Leopard, but should also work under
other configurations.  There are two
special notes for installation:

#. Copy the .exe installer file to the Windows virtual disk, and
   launch the installer from there.

#. When prompted, choose a location on the Windows virtual disk to
   install Strawberry Perl.

Other than that, the software should be able to run normally. For
example, you can write and read data files from your Mac OS X disk, if
you so choose.



Debian-based or other Linux distributions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There are no Linux packages yet available because no one has yet
volunteered to do this work.
