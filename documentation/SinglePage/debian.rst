.. Athena document is copyright 2016 Bruce Ravel and released under
   The Creative Commons Attribution-ShareAlike License
   http://creativecommons.org/licenses/by-sa/3.0/


Notes towards making Debian packages for Demeter
================================================


Links:
 * https://debian-administration.org/article/78/Building_Debian_packages_of_Perl_modules
 * https://jeremiahfoster.com/debian/debs-from-cpan.html


The following lists are requirements for building and running
:demeter:`demeter`.  These notes were assembled on an Ubuntu machine.
YMMV with respect to Debian or another Debian-based system.


Once all this stuff is in place, building :demeter:`demeter` should be
as simple as the standard perl incantation:

.. code-block:: bash

   perl Build.PL
   ./Build
   ./Build install


Required packages
-----------------

This list is culled from the :file:`Build.PL` file and from an
analysis of modules loaded by a script using `App::FatPacker::Trace
<https://metacpan.org/pod/App::FatPacker::Trace>`_

Perl resources
~~~~~~~~~~~~~~

All of these packages already exist in Ubuntu.  These are
:demeter:`demeter`'s dependencies.

#. perl
#. perl-base 
#. perl-modules
#. libperl5.22
#. libarchive-zip-perl
#. libautodie-perl
#. libb-hooks-endofscope-perl
#. libcapture-tiny-perl
#. libchemistry-elements-perl
#. libclass-accessor-perl
#. libcommon-sense-perl
#. libconfig-ini-perl
#. libconst-fast-perl
#. libdata-alias-perl
#. libdata-dump-perl
#. libdata-optlist-perl
#. libdatetime-perl
#. libdevel-globaldestruction-perl
#. libdigest-sha-perl
#. libexporter-tiny-perl
#. libfile-copy-recursive-perl
#. libfile-countlines-perl
#. libfile-find-rule-perl
#. libfile-touch-perl
#. libfile-which-perl
#. libgraph-perl
#. libgraphics-gnuplotif-perl
#. libheap-perl
#. libjson-perl
#. libjson-xs-perl
#. liblist-moreutils-perl
#. libmath-combinatorics-perl
#. libmath-derivative-perl
#. libmath-random-perl
#. libmath-round-perl
#. libmath-spline-perl
#. libmixin-linewise-perl
#. libmodule-implementation-perl
#. libmodule-runtime-perl
#. libmoo-perl
#. libmoose-perl
#. libmoosex-aliases-perl
#. libmoosex-types-perl
#. libmro-compat-perl
#. libnamespace-autoclean-perl
#. libnamespace-clean-perl
#. libnumber-compare-perl
#. libpackage-stash-perl
#. libpackage-stash-xs-perl
#. libparams-util-perl
#. libparams-validate-perl
#. libpdl-stats-perl
#. libperlio-utf8-strict-perl
#. libpod-pom-perl
#. libregexp-assemble-perl
#. libregexp-common-perl
#. libscalar-list-utils-perl
#. libspreadsheet-writeexcel-perl
#. libstatistics-descriptive-perl
#. libsub-exporter-perl
#. libsub-exporter-progressive-perl
#. libsub-identify-perl
#. libsub-install-perl
#. libsub-name-perl
#. libterm-readline-gnu-perl
#. libterm-sk-perl
#. libterm-twiddle-perl
#. libtext-glob-perl
#. libtext-template-perl
#. libtext-unidecode-perl
#. libtree-simple-perl
#. libtry-tiny-perl
#. libtype-tiny-perl
#. libtypes-serialiser-perl
#. libvariable-magic-perl
#. libwant-perl
#. libwx-perl
#. libxmlrpc-lite-perl
#. libyaml-tiny-perl
#. pdl

Non perl resources
~~~~~~~~~~~~~~~~~~

Some more dependency package names:

#. gnuplot5
#. gnuplot5-qt  (or gnuplot5-x11  or gnuplot5-wxt)
#. gnuplot5-data

.. todo:: things needed to compile up ifeffit or use the ifeffit that
   got made years ago, also pgplot (there is a pgplot5 ubuntu package)

Build requires
--------------

The following packages are required to *build* :demeter:`demeter`, but
are not required to be installed on a computer *running*
:demeter:`demeter`.


#. libfile-copy-recursive-perl
#. libfile-slurper-perl
#. libcapture-tiny-perl
#. libextutils-cbuilder-perl

Building the document with sphinx.  Note that sphinx **must** be
version 1.3.  If the packaged version is 1.2, then the
:demeter:`demeter` document will not get made correctly.

#. sphinx-doc
#. sphinx-common
#. pybtex

other sphinx resources can be installed using :program:`pip`,
available in the :quoted:`python-pip` package:

#. sphinxcontrib-bibtex

`More document building details here
<http://bruceravel.github.io/demeter/documents/Athena/forward.html#building-this-document-from-source>`_

Note that the documentation will be built and installed to
:file:`<install_dir>/Demeter/share/documentation/Athena/` where
:file:`<install_dir>` is whatever is returned when you run this:

.. code-block:: bash

   perl -e 'use File::Basename; use Demeter; print dirname($INC{"Demeter.pm"}), $/'


There are four documentation folders: :file:`Athena`, :file:`Artemis`,
:file:`DPG`, and :file:`SingleFile`.




Missing in Ubuntu
-----------------

These are modules used by :demeter:`demeter` that are not packaged
for Ubuntu.  These packages would have to be made and provided.

#. `MooseX::Types::LaxNum
   <https://metacpan.org/pod/MooseX::Types::LaxNum>`_ (essential,
   cannot be worked around, cannot be replaced)
#. `Encoding::FixLatin <https://metacpan.org/pod/Encoding::FixLatin>`_
   (required, but could work around)
#. `HTML::Entities <https://metacpan.org/pod/HTML::Entities>`_ (what
   uses this? may not be necessary)
#. `Pod::ProjectDocs <https://metacpan.org/pod/Pod::ProjectDocs>`_
   (only required for building)
#. `File::Monitor::Lite
   <https://metacpan.org/pod/File::Monitor::Lite>`_ (only needed by a
   feature of :demeter:`athena` that is currently disabled)
