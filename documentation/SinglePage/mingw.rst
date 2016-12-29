.. Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Building Demeter and Ifeffit on Windows with MinGW and Strawberry Perl
======================================================================


This is my page of notes on how I built :demeter:`ifeffit` and
:demeter:`demeter` to work with `Strawberry Perl
<http://strawberryperl.com/>`_ and how I managed to build the
:demeter:`demeter` with Strawberry Perl installer package.  These are
mostly notes to myself, so this may not be completely coherent |nd|
`raise an issue <https://github.com/bruceravel/demeter/issues>`_ is
anything is unclear.

First steps
-----------

#. Install the latest version of :program:`Strawberry Perl` from
   http://strawberryperl.com/. The rest of this page presumes that you
   have installed perl into :file:`C:\\Strawberry`.

   At the time of the most recent update of this document, the current
   version of Strawberry perl is 5.24.0.1.

#. You may want to install the GutHub Desktop application from
   https://desktop.github.com/

#. Clone a copy of :demeter:`demeter` from
   https://github.com/bruceravel/demeter

#. :command:`cd` into the installation folder for :demeter:`demeter`
   and do :command:`perl Build.pl`.  If you just installed (or
   updated) :program:`Strawberry Perl` on your computer, you will be
   missing the mountain of dependencies that :demeter:`demeter` uses,
   so ...

#. At the command line, do :command:`perl Build installdeps` and wait.
   This will take quite a while |nd| even hours on a slow computer.
   Happily, once all the dependencies are installed, they are
   installed.  When you upgrade :demeter:`demeter`, this step will
   only be required to update any new dependencies.

The first time through, it took over 2 hours to compile up all the
dependencies on my fairly old Windows machine.  Three packages failed
to install: ``Wx``, ``Win32::Unicode::File``, and ``File::Monitor::Lite``.

``Wx``

  This failed because one of the tests hung for some reason.  Clicking
  the red X button allowed the tests to continue, but caused one to
  fail.  It was safe to do :command:`cpanm -f -n Wx` to force the
  installation despite the test failure.  Of course, I had to pay
  attention and dismiss the window from the hung test....

``Win32::Unicode::File``

  This failed a test having to do with printing `a Unicode character
  <http://www.fileformat.info/info/unicode/char/2665/index.htm>`_ to
  standard output.  I suspect this has something to do with the
  terminal I was using on my Windows machine.  In any case, it is
  benign in the context of how this module is used in Demeter.  Doing
  :command:`cpanm -f -n Win32::Unicode::File` is safe.

``File::Monitor::Lite``

  Here, the failures have to do with a test failing to deal correctly
  with slashes and backslashes.  Again doing :command:`cpanm -f -n
  File::Monitor::Lite` is safe.

.. 
    ``Syntax::Highlight::Perl``

    I'm not sure what caused this to fail, but it seems benign.  Doing
    :command:`cpanm -f Syntax::Highlight::Perl` worked without any
    failures in the testing phase.  The earlier failure seems to have
    something to do with a problem unpacking the package downloaded by
    :program:`cpanm`.

Any other problems |nd| just do :command:`cpan -f <module>` and see
what happens.  The worst case scenario is that you have to `submit a
bug report <https://github.com/bruceravel/demeter/issues>`_, thus
making :demeter:`demeter` better.  Horrors!

Using Gnuplot
-------------

Grab the latest version of gnuplot from http://gnuplot.info/.  You
will be directed to SourceForge.  Use the latest installer and have
the installer put all the files in
:file:`C:\Strawberry\c\bin\gnuplot`.  When prompted for the default
terminal type, you can select any, but my preferred choice is wxt.


Preparing to compile Ifeffit
----------------------------

`Here is a useful page
<http://www.star.le.ac.uk/~cgp/pgplot_Fortran95_WinXP.html>`_ on using
:program:`pgplot` and :program:`MinGW`.

First, need to establish a build environment from which
Strawberry+Demeter can be bootstrapped.

#. Would like to have installed PDCurses and Readline from `GnuWin32
   <http://gnuwin32.sourceforge.net/packages.html>`_ into
   :file:`C:\\GnuWin32` (or somewhere), but I could not get these to
   work with my 64-bit build.  See below.

#. It is no longer necessary to fetch a copy of gfortran from MinGW.
   Strawberry now comes with it.

#. Installed the pre-built :program:`pgplot` and :program:`GrWin`
   libraries available at
   http://spdg1.sci.shizuoka.ac.jp/grwinlib/english/ into
   :file:`C:\\MinGW\\lib\\pgplot` (or grab them from an old Demeter
   installer).

#. Set the ``PGPLOT_DIR`` variable to ``/c/mingw/lib/pgplot``, which
   is the location to which :program:`pgplot` was installed in
   step 3.

#. In principle, ``PGPLOT_DEV`` should be set to ``/GW``, but that
   does not seem to get picked up by :demeter:`ifeffit`.  I have to
   do :command:`$plot_device=/gw` before plotting.

Compiling Ifeffit to be placed in C:/strawberry
-----------------------------------------------

#. Replace :file:`iconf_pgplot`, :file:`iconf_term`, and
   :file:`iconf_iff` with the versions from :file:`win/` in the
   :demeter:`demeter` distribution

#. Modify line 85 of the main :file:`Makefile.in` to read

   ::

      SUBDIRS = src

   (i.e. remove ``readline`` so it does not get compiled.)

#. Modify line 90 in :file:`src/cmdline/Makefile.in` to read

   ::

      readline_LIB = $(TERMCAP_LIB)

#. Do

   ::

      ./configure --prefix='/c/strawberry/c/lib'

   (Note: this should be done in the MinGW window and **not** in the
   Windows command prompt.)

#. Edit :file:`src/lib/sys.h`, changing the ``sysdir`` and ``pgdev`` lines
   like so:

   .. code-block:: fortran

      c{sys.h  -*-fortran-*- 
      c system and build specific stuff goes here
      c to be included in iff_config.f
             sysdir = 'C:\strawberry\c\share\ifeffit'
             pgdev  = '/gw'
             inifile= 'startup.iff  .ifeffit'
             build = '1.2.11d'//
            $   ' Copyright (c) 2008 Matt Newville, Univ of Chicago'
      c}


#. Now :command:`make` and :command:`make install` .

   You may instead need to do :command:`make -k` and
   :command:`make -k install` if you run into trouble building the
   command line :program:`ifeffit`.



curses and readline
-------------------

The readline library compiled for 64 bit Windows and usable with the
mingw toolchain is `available here
<https://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/ray_linn/64bit-libraries/readline/>`_.
Open the 7zip file and copy the various files in the :file:`bin`,
:file:`include`, :file:`lib`, and :file:`share` folders into
:file:`C:\\Strawberry\\c` (or wherever your :demeter:`demeter` root is
located).

I could not find a pre-compiled curses library, nor could I figure out
how to compile `PDCurses <https://github.com/wmcbrine/PDCurses>`_ on
my Windows/mingw machine.  As a result, I was unable to compile the
command line version of :program:`ifeffit`, although the library
compiled up just fine.  Thus the installer package does not currently
have a copy of the command line :program:`ifeffit`.

Without a curses library, you will certainly need to do :command:`make
-k` and :command:`make -k install` to skip over the problem building
the command line :program:`ifeffit`.


Compiling the SWIG wrapper
--------------------------

I found that the wrapper generated by :program:`SWIG` 1.3.1 works well
but that the wrappers from 1.3.4 or 2.0.2 do not.  I have not
investigated the cause yet and have the 1.3.1 wrapper committed to the
git repository.

Here is the `file defining the compilation and linking rules
<https://github.com/bruceravel/demeter/blob/master/DemeterBuilder.pm>`_
for the :demeter:`ifeffit` SWIG wrapper.

- the linking order **is** important.
- the locations of :program:`MinGW`, :program:`GnuWin`, and
  :program:`strawberry` are currently hardwired

In any case, it should compile up just fine when you do the ``perl
Build`` step.  If you have build :demeter:`demeter` for an earlier
version of perl, you should do ``perl Build touch_wrapper`` to make
sure the SWIG wrapper is rebuilt.

If rebuilding after updating Strawberry, don't forget to do
:command:`perl ./Build touch_wrapper`, which forces a rebuild of the
wrapper.

.. note:: The block around lines 36-42 in :file:`DemeterBuilder.pm`
   attempts to set the root of the :demeter:`demeter` installation
   correctly.  (It is :file:`C:\\Strawberry\\c` on my build machine.)
   Make sure it resolves to the correct location on your machine.

Building documentation
----------------------

The documentation requires `Sphinx <http://sphinx-doc.org/>`_, which I did
not bother to install on my computer.  I just built the document on a
linux machine and zipped it up in a directory structure that looks like this:

.. blockdiag::

   blockdiag {

     node_width = 200;
     default_fontsize = 14;

     documentation -> Artemis, Athena, DPG, SinglePage;
   }

where each of :file:`Artemis`, :file:`Athena`, :file:`DPG`, and
:file:`SinglePage` contains the contents of their respective
:file:`_build/html` folders.

This tree is then dropped in place in
:file:`C:\\Strawberry\\perl\\site\\lib\\Demeter\\share`.




With Sphinx, I imagine it would build and install normally.

