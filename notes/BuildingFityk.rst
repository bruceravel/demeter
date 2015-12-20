Building Fityk and the Fityk SWIG wrapper
=========================================

Sadly, the debian package currently available does not install the
libraries, which are needed by the SWIG wrapper. So one has to download
and build fitxyk from source. This is not *too* hard as long as you can
use your package manager to install a bunch of build dependencies.

#. Get Fityk and Xylib from their repositories

   ::

      svn co https://fityk.svn.sourceforge.net/svnroot/fityk/trunk/ fityk
      svn co https://xylib.svn.sourceforge.net/svnroot/xylib/trunk/ xylib

#. I used the ubuntu package manager to install various things needed
   to build Fityk.
   * autoconf
   * libtool
   * g++
   * libbz-dev
   * libboost-math-dev
   * libreadline6-dev

#. In the :file:`xylib` directory

   ::

      ./autogen.sh
      make
      sudo make install

#. In the :file:`fityk` directory: 

   ::
      
      ./autogen.sh
      ./configure --disable-xyconvert --without-doc
      make
      sudo make install

   I was never able to get the sphinx tool used to generate the
   document to run correctly.  The simplest solution was to disable
   building the document.  And I never figured out the deal with
   :file:`xyconvert`, so I skipped that also.  (Any hints on how to
   deal with those two issues are quite welcome!)

#. Now the fityk :file:`.so` library is in the :file:`/usr/local/lib`
   directory.  I had to do :command:`sudo ldconfig` to get the newly
   installed libraries recognized by the linker.

#. To build the SWIG wrapper from its source in the `fityk/swig/`
   directory, do:

   ::
   
      swig -perl -c++ -I../src fityk.i

   This produces the :file:`Fityk.pm` and :file:`fityk_wrap.cxx` files
   which are needed to make the perl wrapper.  Copy these two files to
   the location where the perl wrapper is built.  Also, copy
   :file:`../src/fityk.h` to the perl wrapper location.  The
   :file:`fityk.h` needs to be up to date with respect to the Fityk
   shared object.

#. cd to the location of the Fityk perl package and do

   ::

      perl Makefile.PL
      make
      make test
      sudo make install
