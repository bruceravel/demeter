.. -*- rst -*-

=====================================================
David Hughes' guide to Demeter Installation on Ubuntu
=====================================================

These instructions cover a non-root manual build of `Bruce Ravel's Demeter
package <https://github.com/bruceravel/demeter>`_ under Ubuntu 12.04. The
instructions are deliberately written with a non-technical audience in mind and
hence might read as somewhat patronizing for the technical reader. The main
12.04 repositories include fairly recent versions of most of the
pre-requisites, allowing us to simplify the installation process somewhat.


First time build
================

Firstly, start a Terminal. In the sections below I'll represent the terminal
prompt with ``$`` -- don't type this when entering commands, it's simply to
give you an indication of what your command line should look like. To save
you typing, you can fairly easily copy and paste examples (excluding the
prompt) by selecting text with your mouse and then middle clicking (the
mouse-wheel on most modern mice) in the terminal where you wish to paste the
selected text.

Preparing your machine
----------------------

The first step is to install all the build and runtime dependencies that are
available in the standard Ubuntu repositories, along with Perl's excellent
local::lib system which will allow us to play around with the development
version of Demeter without affecting the system Perl install::

    $ sudo apt-get install build-essential git gfortran gnuplot ifeffit liblocal-lib-perl libx11-dev libncurses5-dev libpng3 libpng3-dev libgif4 libwxgtk2.8-dev

Next, make sure you're in your home directory and use local::lib to set up
a local copy of Perl to play around with in ~/perl5 (note that these steps
will alter your ~/.bashrc file to ensure that whenever you start a shell in
future, it will be using the local copy of Perl in ~/perl5)::

    $ cd
    $ echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >> ~/.bashrc
    $ source ~/.bashrc

Now we configure the Perl environment for building Demeter's dependencies. Start
the CPAN tool::

    $ cpan

Then, at the CPAN prompt (which looks like ``cpan[1]>``) enter the following
commands::

    cpan[1]> o conf build_requires_install_policy yes
    cpan[2]> o conf prerequisites_policy follow
    cpan[3]> o conf commit

These simply tell the Perl build environment that we don't want to be endlessly
prompted during the build of all the Demeter pre-requisites. Press Ctrl+D to
quit CPAN and return to the normal terminal prompt. Next, we'll take a clone of
Demeter's git repository::

    $ git clone git://github.com/bruceravel/demeter.git

Demeter's build environment
---------------------------

:demeter:`demeter` uses a tool called `Module::Build
<https://metacpan.org/pod/Module::Build>`_ for its build system.  For
many years, Module::Build was simply a part of the standard Perl
installation.  As of Perl 5.22, Module::Build is `no longer part of
the Perl standard distribution
<http://www.dagolden.com/index.php/2140/paying-respect-to-modulebuild/>`_.
This is a small inconvenience for people who are installing
:demeter:`demeter` for the first time.  It means that you must take a
step to prepare the build environment before actually beginning to
build :demeter:`demeter`.

If you do not have Module::Build on your system, you will see and
error much like this:

::

    $ perl Build.PL
    Base class package "Module::Build" is empty.
       (Perhaps you need to 'use' the module which defines that package first,
       or make that module available in @INC (@INC contains: /etc/perl /usr/local/lib/x86_64-linux-gnu/perl/5.22.1 /usr/local/share/perl/5.22.1 /usr/lib/x86_64-linux-gnu/perl5/5.22 /usr/share/perl5 /usr/lib/x86_64-linux-gnu/perl/5.22 /usr/share/perl/5.22 /usr/local/lib/site_perl /usr/lib/x86_64-linux-gnu/perl-base .).
    at DemeterBuilder.pm line 6.
    BEGIN failed--compilation aborted at DemeterBuilder.pm line 6.
    Compilation failed in require at Build.PL line 29.
    BEGIN failed--compilation aborted at Build.PL line 29.

You have (at least) three options, any of which should work just fine:

#. Use your system's package manager to install Module::Build.  On
   Debian and Ubuntu systems, the package is called
   ``libmodule-build-perl``.

#. Use one of the standard tools to install Module::Build from
   source.  For example, the command ``cpanm -S Module::Build`` will
   download, test, and install it, prompting you for a sudo password
   for the installation step.  Alternately, you can run the ``cpan``
   program, then do ``install Module::Build`` at the cpan prompt.

#. Follow the instructions `given here
   <https://metacpan.org/pod/Module::Build::Cookbook#Bundling-Module::Build>`_
   to build and install the copy of Module::Build that comes packaged
   with :demeter:`demeter`.

Once one of those is done, you should have no problem proceeding with
the installation.

Demeter's many dependencies
---------------------------

Now we attempt to build Demeter's dependencies. Firstly, change into the cloned
directory and generate the script to install the dependencies::

    $ cd demeter
    $ perl ./Build.PL

This will probably produce a screen or two of output which on my system looked
like this::

    WARNING: the following files are missing in your kit:
        lib/Demeter/UI/Hephaestus/data/hephaestus.htm
    Please inform the author.

    Checking prerequisites...
      requires:
        !  Archive::Zip is not installed
        !  Chemistry::Elements is not installed
        !  Config::INI is not installed
        !  Const::Fast is not installed
        !  DateTime is not installed
        !  Encoding::FixLatin is not installed
        !  File::CountLines is not installed
        !  Graph is not installed
        !  Heap is not installed
        !  Math::Combinatorics is not installed
        !  Math::Derivative is not installed
        !  Math::Round is not installed
        !  Math::Spline is not installed
        !  Moose is not installed
        !  MooseX::Aliases is not installed
        !  MooseX::Singleton is not installed
        !  MooseX::StrictConstructor is not installed
        !  MooseX::Types is not installed
        !  PDL is not installed
        !  PDL::Stats is not installed
        !  Pod::POM is not installed
        !  Spreadsheet::WriteExcel is not installed
        !  Statistics::Descriptive is not installed
        !  String::Random is not installed
        !  Tree::Simple is not installed
        !  Want is not installed
      build_requires:
        !  File::Touch is not installed
        !  Image::Size is not installed
        !  PPI is not installed
        !  PPI::HTML is not installed
        !  Pod::ProjectDocs is not installed
        !  Template is not installed
      recommends:
        *  File::Monitor::Lite is not installed
        *  Graphics::GnuplotIF is not installed
        *  Term::Sk is not installed
        *  Term::Twiddle is not installed
        *  Wx is not installed

    ERRORS/WARNINGS FOUND IN PREREQUISITES.  You may wish to install the versions
    of the modules indicated above before proceeding with this installation

    Run 'Build installdeps' to install missing prerequisites.

    Created MYMETA.yml and MYMETA.json
    Creating new 'Build' script for 'Demeter' version 'v0.9.13'

The list of the all the ``not installed`` items is the list of dependencies we
need to install. We use the generated Build script to handle installing all
these for us::

    $ ./Build installdeps

Be aware that this process will produce a *very* large amount of terminal
output. This is normal and nothing to be alarmed about (most of the output is
simply the build process giving exhaustive detail of what it's running or
testing or installing at that moment). However, at times the process will
prompt you to ask whether you want to install something. Simply hit Enter to
accept the default (which is always "yes") in such instances. The prompts will
look like the following::

    Install Wx? [y ]
    y
    Install Graphics::GnuplotIF? [y ]
    y
    Install File::Monitor::Lite? [y ]
    y
    Install Term::Twiddle? [y ]
    y
    Install Term::Sk? [y ]
    y

These questions may pop up at the start, or after 10 minutes and several
thousand lines of output in the terminal, or both! Basically, just have
patience and occasionally check your terminal to see if it needs your
confirmation.

During the Wx build you may find small windows appearing randomly on your
desktop. This is part of the test process for the build and perfectly normal.
Try and avoid doing anything with the windows - they should disappear on their
own. Also, if possible, try and avoid using your desktop while this is going
on. The windows may grab keyboard focus, causing you to inadvertently interfere
with the test process if you're typing at the time.

Eventually, the dependencies build should complete. To make sure that all the
dependencies have been installed correctly, re-run the generator script::

    $ perl ./Build.PL

Dealing with failed dependencies
--------------------------------

This time you should get output which doesn't include any ``not installed``
items. However, in my particular case for some reason Wx failed to install the
first go round so I got this::

    WARNING: the following files are missing in your kit:
        lib/Demeter/UI/Hephaestus/data/hephaestus.htm
    Please inform the author.

    Checking prerequisites...
      recommends:
        *  Wx is not installed

    ERRORS/WARNINGS FOUND IN PREREQUISITES.  You may wish to install the versions
    of the modules indicated above before proceeding with this installation

    Run 'Build installdeps' to install missing prerequisites.

    Created MYMETA.yml and MYMETA.json
    Creating new 'Build' script for 'Demeter' version 'v0.9.13'

Simply re-running the installdeps process fixed this for me (skip this step if
you don't see any ``not installed`` items above)::

    $ ./Build installdeps

Depending on the state of your machine or the distribution you are
using, you might still fail to successfully build :program:`wxperl` or
some other package, `as discussed here
<https://github.com/bruceravel/demeter/issues/36>`_.  If you use a
distribution with a robust package manager and an extensive library of
packages, it should be fine to satisfy the dependency using the
system's package manager.  For example, on a debian-based
distribution, you could meet the requirement for :program:`wxperl` by
doing

.. code-block:: bash

   ~> sudo apt-get install libwx-perl


Eventually you should get the following when running Build.PL::

    $ perl ./Build.PL
    WARNING: the following files are missing in your kit:
        lib/Demeter/UI/Hephaestus/data/hephaestus.htm
    Please inform the author.

    Created MYMETA.yml and MYMETA.json
    Creating new 'Build' script for 'Demeter' version 'v0.9.13'

The type of warning about files missing in the kit is not serious.  It
usually just means that Bruce forgot to update the `MANIFEST file
<https://github.com/bruceravel/demeter/blob/master/MANIFEST>`_.


Ready to build Demeter!
-----------------------

At this point you're finally ready to build and install Demeter itself which
is done as follows::

    $ ./Build
    $ ./Build test
    $ ./Build install

Don't worry if a few errors crop up during the "Build test" phase; you are
building a development copy of the software and inevitably these are somewhat
less stable than "proper" releases. However, if you do happen to notice
something new has failed since the last time you tested Demeter, you may want to
inform the author. You can generate a copy of the test output simply by
copying and pasting (as described at the beginning) or with the following
command line which will place the output in ``test_errors.txt`` in your home
directory::

    $ ./Build test | tee ~/test_errors.txt

Please ensure when informing the author of any test issues that you include a copy
of the test output, and preferably other details such as the date on which you last
updated your clone of the Demeter repository (which may help identify the change that
caused the failure) and the version of the OS you're running.

Once "Build install" has completed you should be able to run applications within
the Demeter package as follows::

    $ dathena
    $ dartemis
    $ dhephaestus
    $ denergy

... and so on


Updating your installation
==========================

At some point you may learn that some new feature or existing bug has been
fixed, and wish to update your installation from the latest development copy.
To do so (you will be relieved to hear!) is considerably simpler than the
initial install.

Firstly, start up a terminal and update your copy of the Demeter repository::

    $ cd demeter
    $ git pull

Next, ensure that your pre-requisites are still fine (it's possible that new
features may pull in additional pre-requisites)::

    $ perl Build.PL

If your output includes any ``not installed`` lines you will need to run the
``installdeps`` command line below, but otherwise skip this step::

    $ ./Build installdeps

Now rebuild, re-test, and re-install Demeter::

    $ ./Build
    $ ./Build test
    $ ./Build install


Removing your installation
==========================

Should you ever wish to start from scratch you can completely remove your
Demeter installation (and the local Perl copy) by starting a terminal and
entering the following commands (be aware these will not prompt to make sure
you really want to delete your installation - they will simply delete it -
hook, line, and sinker)::

    $ rm -fr ~/demeter/
    $ rm -fr ~/perl5/


Using Gnuplot with Demeter
==========================

At build time, Demeter tries to figure out which :program:`gnuplot`
terminal to use by default.  It will query a :program:`gnuplot`
session to see if either the wxt or qt terminal types is available.
If not, it will fall back to the X11 terminal.

That said, the X11 terminal is rather ugly.  Because `Debian/Ubuntu
apparently dropped support for wxt
<https://groups.google.com/forum/#!topic/comp.graphics.apps.gnuplot/kfYtd2pwrW0>`_
you might want to recompile :program:`gnuplot` from source.  User
Patrick Browne offers this recipe:

.. code-block:: bash

   ~> sudo apt-get install libwxgtk2.8-dev libgtk2.0-dev
   ~> wget "http://downloads.sourceforge.net/project/gnuplot/gnuplot/5.0.4/gnuplot-5.0.4.tar.gz"
   ~> tar xzf gnuplot-5.0.4.tar.gz  ## or whatever version number is current
   ~> cd gnuplot-5.0.4
   ~> env TERMLIBS="-lX11" ./configure
   ~> make
   ~> sudo make install

After that, use the wxt terminal by setting it in either
:demeter:`athena` or :demeter:`artemis`.

In :demeter:`athena`: select :guilabel:`Preferences` from the main menu,
then click open :guilabel:`gnuplot` and click on :guilabel:`terminal`.
Replace "x11" by "wxt", click "Apply and Save".

In :demeter:`artemis`: :menuselection:`File --> Edit preferences`,
then click open :guilabel:`gnuplot` and click on :guilabel:`terminal`.
Replace "x11" by "wxt", click "Apply and Save".
