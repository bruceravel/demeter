.. Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Building Demeter and Ifeffit on Windows with MinGW and Strawberry Perl
======================================================================


This is my page of notes on how I built :demeter:`ifeffit` and
:demeter:`demeter` to work with `Strawberry Perl
<http://strawberryperl.com/>`_ and how I managed to build the
:demeter:`demeter` with Strawberry Perl installer package.  It may not
be completely coherent -- if you want to replicate what I have done,
let me know and I'll clean this page right up.

First steps
-----------

#. Install the latest version of ;program:`Strawberry Perl` from
   http://strawberryperl.com/

#. You may want to install the GutHub Desktop application from
   https://desktop.github.com/

#. Clone a copy of :demeter:`demeter` from
   https://github.com/bruceravel/demeter

#. cd into the installation folder for :demeter:`demeter` and do
   ``perl Build.pl``.  If you just installed (or updated) Strawberry
   perl on your computer, you will be missing the mountain of
   dependencies that :demeter:`demeter` uses, so ...

#. At the command line, do ``perl Build installdeps`` and wait.  This
   will take quite a while.  Happily, once all the dependencies are
   installed, they are installed.  When you upgrade Demeter, this step
   will only be required to update any new dependencies.

The first time through, it took about 3 hours to compile up all the
dependencies on my fairly old Windows machine.  Three packages failed
to install: ``Wx``, ``File::Monitor::Lite``,
``Syntax::Highlight::Perl``.

``Wx``

  This failed because one of the test hung for some reason.  Clicking
  the red X button allowed the tests to continue, but caused one to
  fail.  It was safe to do ``cpanm -f Wx`` to force the installation
  despite the test failure.  Unfortunately, this is a slow
  compilation.  Sigh....

``File::Monitor::Lite``

  Here, the failures have to do with a test failing to deal correctly
  with slashes and backslashes.  Again doing ``cpanm -f
  File::Monitor::Lite`` is safe.

``Syntax::Highlight::Perl``

  I'm not sure what caused this to fail, but it seems benign.  Doing
  ``cpanm -f Syntax::Highlight::Perl`` worked without any failures in
  the testing phase.  The earlier failure seems to have something to
  do with a problem unpacking the packaged downloaded by
  :program:`cpanm`.

Preparing to compile Ifeffit
----------------------------

`Here is a useful page
<http://www.star.le.ac.uk/~cgp/pgplot_Fortran95_WinXP.html>`_ on using
:program:`pgplot` and :program:`MinGW`.

First, need to establish a build environment from which
Strawberry+Demeter can be bootstrapped.

#. Installed PDCurses and Readline from `GnuWin32
   <http://gnuwin32.sourceforge.net/packages.html>`_ into
   :file:`C:\\GnuWin32`

#. Installed a full `MinGW
   <http://sourceforge.net/projects/mingw-w64/>`_ package because
   Strawberry does not come with the Fortran compiler.  I put this
   into in :file:`C:\\MinGW`.

#. Installed the pre-built :program:`pgplot` and :program:`GrWin`
   libraries available at
   http://spdg1.sci.shizuoka.ac.jp/grwinlib/english/ into
   :file:`C:\\MinGW\\lib\\pgplot`

#. Set the ``PGPLOT_DIR`` variable to ``/c/mingw/lib/pgplot``, which
   is the location to which :program:`pgplot` was installed in
   step 4.

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

      readline_LIB =   $(TERMCAP_LIB)

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


#. Now :command:`make` and :command:`make install` 

What goes into Demeter.prereqs
------------------------------

- The :program:`MinGW` fortran compiler and its :file:`.a` and
  :file:`.dll` libraries.  The libraries must be placed into a folder
  tree named consistently with the version of :program:`MinGW` used in
  Strawberry.

- The entire contents of the :program:`GnuWin32`, :program:`readline`
  and :program:`ncurses` packages.  These come arranged in folders
  that fit obviously under :file:`c:\\strawberry\\c`

- All of :program:`PGPLOT`, which goes into :file:`lib\\pgplot`.

- All of the :file:`binary` folder from :program:`Gnuplot`, which goes
  into :file:`bin`.

- And, of course, :demeter:`ifeffit` gets installed here.

Once everything is in place, zip up :file:`Demeter.prereqs` in a zip
file called :file:`Demeter.prereqs.zip` and move that zip file to
:file:`C:\\git\\demeter\\win`.

Note that the :demeter:`ifeffit` wraper must be built against a
properly built version of :demeter:`ifeffit`.  This probably means
ether building :demeter:`demeter` from source as part of the
Strawberry build or

#. Build :demeter:`ifeffit`
#. Build Strawberry
#. Build :demeter:`demeter` using the Strawberry that just got built
#. Build a :demeter:`demeter` par file
#. Rebuild Strawberry


curses and readline
-------------------

From the GnuWin32 :file:`bin` folder, copy :file:`curses2.dll`,
:file:`history5.dll`, and :file:`readline5.dll` to
:file:`C:/Strawberry/c/bin`.

From the GnuWin32 :file:`lib` folder, copy all the files with
:file:`curses`, :file:`readline`, and :file:`readline` in the name to
:file:`C:/Strawberry/c/lib`.



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

Using Gnuplot
-------------

Grab the latest version of gnuplot from http://gnuplot.info/.  You
will be directed to SourceForge.  Use the latest installer and have
the installer put all the files in C:\Strawberry\c\bin\gnuplot

There
are zip files with Windows builds to be found there.  In recent
versions, there is a :file:`gnuplot.exe` version that emulates pipes
without opening a command window.  Point the
:configparam:`gnuplot,program` configuration variable at that and you
should be able to use the gnuplot plotting backend.  (Set
:configparam:`plot,plotwith` to `gnuplot`.)

..
   Strawberry Perl + Demeter
   =========================

   The relocation of Perl does not seem to happen correctly when
   installing not in :file:`C:\\strawberry`.  See
   http://www.perlmonks.org/?node_id=883855

   Do this:

   #. Install Strawberry from the msi package.  Click through the error that happens when relocation fails.

   #. Remove the line {{{
   perl\lib\auto\Locale-Maketext\.packlist:backslash
   }}} from `c:/source/strawberry/strawberry-merge-module.reloc.txt`.  This seems to be the reason that relocating fails during installation.

   #. Run the relocation script in `C:\source\strawberry` by hand

   #. Proceed with the instructions at http://strawberryperl.com/documentation/building.html although you will need to grap the latest `Alien::WiX` from Curtis Jewell's mercurial repository at http://hg.curtisjewell.name/Alien-WiX/ and install that instead.  Also install `WiX` from that same repository.

   To get things working with Perl 5.12.2 (the current version of Strawberry at this time), grab and install these:

   - http://hg.curtisjewell.name/Perl-Dist-WiX-BuildPerl-5122
   - http://hg.curtisjewell.name/Perl-Dist-Strawberry-BuildPerl-5122

   PDWix uses LWP::!UserAgent.  So you have to put the `http_proxy` in the environment.  In the MinGW shell, doing {{{
   export http_proxy=http://192.168.1.130:3128
   }}} before building did the trick.


   Errors in simple script to build dependency tree:
    * `Sub::Exporter` must come before `Dist::CheckConflicts`
    * `Test::Moose` is part of Moose and need not be specified as a dependency
    * `Getopt::Long` is a core module and need not be in the list

   ----

   = Modifying the BAT files =

   At line 7 of each `.bat`file generated by Module::Build to run the perl scripts, you will find this invocation of perl:

   {{{
   perl -x -S %0 %*
   }}}

   This will call perl and feed it the perl code that follows the BAT code at the top of the file.

   Each `.bat` file should be modified to capture STDOUT and STDERR to a file for the sake of bug reporting.  This can be done like so:

   {{{
   perl -x -S %0 %*  > "%APPDATA%\demeter\dathena.log" 2>&1
   }}}

   Each of Athena, Artemis, Hephaestus, and Atoms should get its own log file.

   See [[http://www.robvanderwoude.com/redirection.php|this explanation]] of DOS batchfile redirection.

