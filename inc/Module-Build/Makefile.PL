# This Makefile.PL creates a pass-through Makefile that simply calls
# the equivalent Module::Build methods for each make target.  See the
# documentation for Module::Build::Compat for more information.

use 5.006001;


use lib qw(lib);

# bootstrap configure_requires prereqs
BEGIN { do 'inc/bootstrap.pl' or die defined($@) ? $@ : $! }

use Module::Build::Compat;

Module::Build::Compat->run_build_pl(args => \@ARGV);
Module::Build::Compat->write_makefile(build_class => 'Module::Build');
