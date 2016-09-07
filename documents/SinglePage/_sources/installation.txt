.. Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/

Installing Demeter from source code
===================================


The instructions for installing the :demeter:`demeter` source code on
a Linux machine are not trivial, but also not difficult. If you follow
these instructions patiently, everything will work. The main issue is
the large number of dependencies. The instructions on this page should
work on any flavor of Linux, any other Unix, and probably OSX as
well. Everything here except for installing :demeter:`ifeffit` and
:program:`PGPLOT` will work on a Windows machine with Strawberry
perl.

These instructions are for installing system-wide, which requires root
privileges.  All instructions are given assuming that you use a system
which uses `sudo <http://en.wikipedia.org/wiki/Sudo>`_.  If your
machine does not use :command:`sudo`, then replace :command:`sudo`
with :command:`su -s` in the instructions that follow.

In a section below instructions are given for installation without
root privileges.  All the instructions are the same, once you do an
additional preparatory step.

`Here is another take on installation instructions
<demeter_nonroot.html>`_, written in another person's words.

:demeter:`demeter` is written in perl. **You must install perl on your
computer**. On Ubuntu, the package name is simply "perl". (My
computers are all Ubuntu, hence all of my hints about packages that
need installing refer to the Ubuntu package names.  Package names on
other systems are likely to be similar.)  You must use at least perl
5.10, butpreferably something much newer.  Some :quoted:`enterprise`
versions of Linux (notably Red Hat based ones like RHEL, CentOS, and
Scientific Linux) may ship with an ancient version of perl.  Demeter
will not run under perl 5.6 or 5.8.  You **will** have to upgrade perl
before using :demeter:`demeter`.

:demeter:`demeter` benefits *tremendously* by having `Gnuplot
<http://gnuplot.info>`_ installed. All Linux distributions should have
a package for Gnuplot. On Ubuntu, the package is called
:quoted:`gnuplot`.  You also likely want to install one of the GUI
packages, :quoted:`gnuplot-x11` or :quoted:`gnuplot-qt`.  Or you can
grab the latest source code from http://gnuplot.info and install it
from scratch.

DEMETER's build system
----------------------

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


Build DEMETER and its dependencies
----------------------------------

**Step 1: Install Ifeffit and PGPLOT**

    You will need the :program:`gcc` and :program:`gfortran`
    compilers as well as a few development libraries installed on your
    computer

    #. Grab the latest Ifeffit source code from `its github
       site <https://github.com/newville/ifeffit>`_.

    #. cd into the source directory

    #. Run the :command:`PGPLOT_install` script. This streamlines the
       rather unwieldy chore of building :program:`PGPLOT`. This step
       will require root access to the computer.

       ::

	  sudo ./PGPLOT_install

    #. Do :command:`./configure`

    #. Do :command:`make`

    #. Do :command:`sudo make install`

    On my Ubuntu machine, the following development libraries are
    needed to get :demeter:`ifeffit` and :program:`PGPLOT`
    compiled. On other flavors of Linux, these packages might be
    called by different names, but hopefully this list will help you
    resolve which packages are needed.

    #. :file:`libx11-dev`

    #. :file:`libncurses5` and :file:`libncurses5-dev`

    #. :file:`libpng3` and :file:`libpng3-dev`

    #. :file:`libgif4`

    #. :file:`libwxgtk2.8-dev` (the version number, here 2.8, might be
       different in your distribution)

**Step 2: Download a copy of Demeter**

    The source code for Demeter is currently managed on github:
    https://github.com/bruceravel/demeter.

    To download a copy of the source code, do one of the following:

    #. Use git to clone a copy.  You will need to have `git
       <http://git-scm.com/>`_, which is a version control system used
       to manage the Demeter source code, installed on your
       computer. On Ubuntu machines, the package is called
       :quoted:`git-core`.  At the command line, do:

       ::

	  git clone https://github.com/bruceravel/demeter.git

       then follow along with developments by doing

       ::
	  
	  git pull

       to download future modifications to the code.

    #. Grab the most recent archive file containing the
       :demeter:`demeter` source code.  Go to
       https://github.com/bruceravel/demeter and click on one of the
       download buttons near the top of the page to get either the
       :file:`tar.gz` or :file:`.zip` archive file containing the entire
       source code.


    Cloning a copy with git is far more convenient as it allows you to
    keep up more easily as Demeter evolves.

**Step 3: Download and install the dependencies**

    After checking out a copy of :demeter:`demeter` from git (or
    unpacking the archive), :command:`cd` into the new subdirectory
    and do

    ::

       perl ./Build.PL

    If this is the first time you are installing :demeter:`demeter` on
    this computer, you will see a very large number of warnings about
    missing dependencies. If no warnings are issued, proceed to
    Step 4.

**Step 3a: Configure cpan (optional)**

    You will use the `cpan <https://metacpan.org/module/cpan>`_
    program to download most of the dependencies from `the CPAN
    repository <http://metacpan.org>`_. You can make this process
    easier by configuring the cpan program. Start cpan:
    
    ::

       sudo cpan

    At the ``cpan>`` prompt, issue the following commands:

    ::

       o conf build_requires_install_policy yes
       o conf prerequisites_policy follow
       o conf commit

    Now, when one of :demeter:`demeter`'s dependencies itself has a
    dependency, this configuration will tell the cpan program to
    automatically follow them.

    Skipping this step is ok, but it means that you will need to answer
    :quoted:`yes` to **a lot** of questions in Step 3b.

**Step 3b: Install Demeter's dependencies (not optional!)**

    Now that cpan is correctly configured, do the following

    ::

       sudo ./Build installdeps

    Go get a cup of coffee. This takes a while.

    Although step 3a configures cpan in such a way that most of the
    interaction is handled automatically, a few packages will still
    ask you questions. Answering yes to all of these questions is a
    good idea as these optional dependencies enable some nice features
    in :demeter:`demeter`. (However, if you do not have
    :program:`Gnuplot` on your computer, answer :quoted:`no` to the
    question about ``Graphics::GnuplotIF``.  But, really, use
    :program:`Gnuplot`.  Your :demeter:`demeter` experience will be
    much better.)

    In my experience, most dependencies install smoothly on recent
    Linux installations.  They also all install smoothly under
    `Strawberry Perl <http://strawberryperl.com/>`_ on Windows.  If
    there are any failures, you will need to track down the problems
    and fix them in order to proceed.

**Step 3c: Dealing with failed dependencies**

    Demeter has a lot of dependencies on other Perl modules.  The
    :command:`./Build installdeps` step downloads each of the
    approximately 40 modules that Demeter needs.  Each of those
    modules has its own tree of dependencies.  All in all, a couple
    hundred packages get downloaded, built, and installed when do the
    :command:`./Build installdeps` step.

    Sometimes, a few of these fail.  This is not a disaster.  In most
    cases, the problem can be dispatched easily.  See `this post
    <http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2015-July/008086.html>`_
    to the :demeter:`ifeffit` Mailing List about some strategies for
    dealing with failed builds of dependencies.

    :quoted:`PDL::Stats` presents a special challange.  There is a
    `known bug
    <http://sourceforge.net/p/pdl/mailman/pdl-devel/?viewmonth=201505&viewday=12>`_
    in :quoted:`PDL::Stats` that is not yet fixed (at the time of this
    writing, Aug. 2015) in the upstream source.  If possible, use your
    system's pre-built package (the Debian package is called
    :quoted:`libpdl-stats-perl`).

    If you cannot use a package and you are unable to build
    L<PDL::Stats>, as `discussed in this mailing list thread
    <http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2015-August/008158.html>`_,
    do the following:

    #. Download PDL::Stats from https://metacpan.org/pod/PDL::Stats

    #. Unpack the tarball and cd into its directory

    #. Copy the file :file:`glm.patch` from Demeter's :file:`tools/`
       directory into the PDL:Stats top directory

    #. Apply the patch

       ::

	  patch -p0 < glm.patch

    #. Build and install PDL::Stats

       ::

	  perl Makefile.PL
	  make
	  make test
	  make install


**Step 4: Build and install Demeter**

Almost done! Just do each of the following:

::

   perl Build.PL
   ./Build
   ./Build test
   sudo ./Build install

You need to redo the :command:`perl Build.PL` step to verify that all
the dependencies are installed and available. If any failed to install
correctly, you will be told at that stage.

This will put all of :demeter:`demeter`, all the executable programs,
and all the documentation in in the proper place on your computer. You
are now good to go.

The :demeter:`demeter` package includes components
(e.g. :quoted:`Xray::Absorption` and :quoted:`STAR::Parser`) that once
had to be handled separately. :demeter:`demeter` is now one stop shopping!

If any errors are reported during the :command:`./Build test` step,
you should report them to Bruce. The best report includes a complete
capture of everything written to the screen. The easiest way to
capture screen text is to use `tee
<http://www.gnu.org/software/coreutils/manual/coreutils.html#tee-invocation>`_.
Here is an example:

::

   ./Build test | tee screen_messages.txt

Special cases
-------------

A Demeter program fails, complaining that Carp::Clan is missing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This may happen after an upgrade.  A recent version of one of
Demeter's dependencies `(MooseX::Types)
<https://metacpan.org/pod/MooseX::Types>`_ depends on `(Carp::Clan)
<https://metacpan.org/pod/Carp::Clan>`_ but may not be installed after
an OS upgrade.  If this happens, either use CPAN to install Carp::Clan:

::

    sudo cpanm Carp::Clan

or install the debian package `libcarp-clan-perl`.


Installing Demeter without root privileges
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In step 1, replace the command

::

   ./configure

with

::

   ./configure --prefix=/path/to/installation/location

Here you need to specify a location in your own disk space in which to
install Ifeffit and all the rest.  I'd recommend something like
:file:`$HOME/local`.  You will also need to put
:file:`$HOME/local/bin/` in your execution path, which can be done by
adding this to your :file:`.bashrc` file:

::

   export PATH=$PATH:$HOME/local/bin/

Even if you are installing :demeter:`demeter` without root, it is
probably easier to get :demeter:`ifeffit` and :program:`PGPLOT`
installed system-wide. On a Debian-based system, even better would be
to install Carlo Segre's pre-built versions of :demeter:`ifeffit` and
:program:`PGPLOT` by following the instructions at
http://debian-xray.iit.edu/.

Prior to Step 3a, go to https://metacpan.org/module/local::lib and
download the latest version of the :quoted:`local::lib` module.
Unpack it and cd into the newly created directory.  (`See this mailing
list post
<http://millenia.cars.aps.anl.gov/pipermail/ifeffit/2014-June/007306.html>`_
for an explanation of why you want to use :quoted:`local::lib`.)

Do

::

   perl Makefile.PL --bootstrap

Then do

::

   make test && make install

If you use the bash shell, do

::

   echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >>~/.bashrc

If you use a shell that uses C shell syntax, follow the instructions
at https://metacpan.org/module/local::lib#The-bootstrapping-technique.

This last step adds a line to your login file. The easiest way for
this to take effect is to log out and log in again or to open a new
terminal window.

Once :quoted:`local::lib` is installed, follow all the instructions in
Steps 3a, 3b, and 4, except that you now do not need to install using
``sudo`` (that is, type the command as given, but without ``sudo``).
The whole point of installing :quoted:`local::lib` is to be able to
install all of this software in your own disk space without needing
root privileges.

Working behind a proxy server
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Each of the steps that involves going out onto the big, bad Internet
will require special configuration if you are working from behind a
proxy server.

For example, here at Brookhaven National Laboratory, the proxy URL and
port number is ``http://192.168.1.130:3128``.  In the examples that
follow, you will need to replace that with the correct proxy
configuration for your institution.


#. To have :program:`git` talk through the proxy, I had to do this:
   
   ::

      git config --global https.proxy http://192.168.1.130:3128

#. To use :program:`cpan:`, first, fire up C<cpan> as root

   ::

      sudo cpan

   At the ``cpan>`` prompt, issue the following commands:

   ::

      o conf http_proxy http://192.168.1.130:3128
      o conf ftp_proxy http://192.168.1.130:3128
      o conf commit

:program:`cpan` should now work properly through the proxy.


Installing and using source code on Windows
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can easily follow :demeter:`demeter`'s developments or hack on
:demeter:`demeter`'s source code on a Windows machine.


#. Install the most recent Windows installer package from
   http://bruceravel.github.io/demeter.

#. Next install L<git|http://git-scm.com/> on your computer.

#. Proceed with Steps 2 and 4 from the instructions above.  This will
   keep you up to date with the latest developments.


WxPerl GUIs on KDE
~~~~~~~~~~~~~~~~~~

WxPerl on linux uses GTK.  This means that the GUIs may not match your
desktop if you are a KDE user.  The solution to this "problem" is to
install the tool for configuring GTK applications under KDE.  On
Ubuntu, this package is called :quoted:`kde-config-gtk`.  You will
then want to install the :quoted:`gtk2-engines` package.  There are
several GTK2 themes with names like :quoted:`gtk2-engines-clearlooks`
that you can also install.  The key to making :demeter:`athena` and
:demeter:`artemis` look like the rest of your desktop is to
synchronize your choice of KDE and GTK2 themes.  I use KDE's
:quoted:`cleanlooks` theme with GTK2's :quoted:`clearlooks` theme.
:quoted:`Oxygen` is another possibility.

Upon upgrading to Ubuntu 12.04 on one of my computers, I observed
frequent crashes in :demeter:`artemis` related to drag and drop
(e.g. when importing paths from a :demeter:`feff` calculation).  This
turned out to be related to a problem with the :quoted:`oxygen-gtk`
GTK2 theme.  Changing the GTK2 theme to any other choice made the
problem go away.

Miscellany
----------

**Building the Ifeffit SWIG wrapper**

    See http://cars9.uchicago.edu/ifeffit/Demeter/SwigModuleBuild

**(The mess that is) Scientific Linux 5**

    See http://cars9.uchicago.edu/ifeffit/Demeter/ScientificLinux>

    Have the problems with perl and gnuplot described on that page been
    fixed in SL 6?

**Building Ifeffit on Windows with MinGW and Strawberry**

    I recorded my notes at https://github.com/bruceravel/demeter/blob/master/win/notes.org.

