#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The GNU
 General Public License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

# BEGIN {
#   eval 'use File::Copy::Recursive';
#   if ($@) {
#     eval "use DocBuilder::FCR;"
#   };
# };

use strict;
use warnings;
use Cwd;
use File::Spec;
use DemeterBuilder; # subclass of Module::Build defining some Demeter specific installation instructions

## --------------------------------------------------------------------------------
## use bundled Module::Build, if need be

## see https://metacpan.org/pod/Module::Build::Cookbook#Bundling-Module::Build
## and http://www.dagolden.com/index.php/2140/paying-respect-to-modulebuild/

my $Bundled_MB = 0.4211;  # or whatever version it was.

# Find out what version of Module::Build is installed or fail quietly.
# This should be cross-platform.
my $Installed_MB = `$^X -e "eval q{require Module::Build; print Module::Build->VERSION} or exit 1"`;

# some operating systems put a newline at the end of every print.
chomp $Installed_MB;

$Installed_MB = 0 if $?;

# Use our bundled copy of Module::Build if it's newer than the installed.
unshift @INC, "inc/Module-Build/lib/perl5" if $Bundled_MB > $Installed_MB;

require Module::Build;
## --------------------------------------------------------------------------------


my $build = DemeterBuilder
  -> new(
	 module_name        => 'Demeter',
	 create_readme      => 0,
	 ##create_makefile_pl => 'traditional',
	 license            => 'artistic',
	 dist_author        => 'Bruce Ravel <http://bruceravel.github.io/home>',
	 auto_configure_requires => 1,
	 needs_compiler     => 1,
	 requires           => {
				'Moose'			    => '2.09',
				'MooseX::Aliases'           => '0.10',
				#'MooseX::Clone'             => '0.05',
				#'MooseX::StrictConstructor' => '0.19',
				#'MooseX::Singleton'	    => '0.29',
				'MooseX::Types'		    => '0.31',
				'MooseX::Types::LaxNum'	    => '0',

				'Archive::Zip'		    => '1.31',

				'Capture::Tiny'	            => '0.07',
				'Chemistry::Elements'	    => '0',
				'Config::INI'	            => '0',
				'DateTime'                  => '0',
				'Digest::SHA'		    => '0',
				'Encoding::FixLatin'        => '0',
				'File::Copy::Recursive'     => '0',
				'File::CountLines'          => '0',
				'File::Touch'	            => '0',
				'File::Which'	            => '1.09',
				'Graph'                     => '0',
				'Heap'			    => '0',
                                'HTML::Entities'            => '0', # what is this used for?
				'JSON'                      => '0',
				'List::MoreUtils'	    => '0',
				'Math::Combinatorics'	    => '0',
				'Math::Derivative'	    => '0',
				'Math::Random'              => '0',
				'Math::Round'		    => '0',
				'Math::Spline'		    => '0',
				'Pod::POM'                  => '0',
				'Proc::ProcessTable'        => '0',
				'Const::Fast'		    => '0.01',
				'Regexp::Common'	    => '0',
				'Regexp::Assemble'	    => '0',
                                'Spreadsheet::WriteExcel'   => '0',
                                'Statistics::Descriptive'   => '0',
				'Text::Template'	    => '0',
				'Text::Unidecode'	    => '0',
				'Tree::Simple'		    => '0',
				'Want'			    => '0',
				'YAML::Tiny'		    => '0',

				'PDL'                       => '2.4.9',
				#'PDL::Slatec'               => '0',
				'PDL::Stats'                => '0.5.5',

				'XMLRPC::Lite'              => '0',

				(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ?
				('Win32::Shortcut' => '0', 'Win32::Unicode::File' => '0') : (),
				## deprecated....
				#'Compress::Raw::Zlib'	   => '0',
				#'Compress::Raw'	   => '0',
				#'Math::Cephes'		   => '0',
				#'MooseX::AttributeHelpers'  => '0.23', now using Moose::Meta::Attribute::Native like a good boy
			       },
	 build_requires     => {
				## these are used to build the old version of the documents
				#'Template'                => '2.22',
				#'PPI'                     => '0',
				#'PPI::HTML'               => '0', # perl syntax highlighting for HTML
				#'Syntax::Highlight::Perl' => '0', # perl syntax highlighting for latex
				#'Image::Size'             => '0',
				'File::Copy::Recursive'   => '0',
				## project docs
				'Pod::ProjectDocs'        => '0',
				'File::Slurper'           => '0',
				'Capture::Tiny'           => '0',

				## these are used to build the Ifeffit wrapper
                                'ExtUtils::CBuilder'      => '0',
			       },
	 PL_files           => {
				'lib/Xray/Crystal/share/space_groups.db.PL' => 'lib/Xray/Crystal/share/space_groups.db',

                                ## from Xray::Absorption
				'lib/Xray/data/chantler2st.PL'  => 'lib/Xray/Absorption/chantler.db',
				'lib/Xray/data/dat2st.PL'       => 'lib/Xray/Absorption/mcmaster.db',
				'lib/Xray/data/henke2st.PL'     => 'lib/Xray/Absorption/henke.db',
				'lib/Xray/data/shalt2st.PL'     => 'lib/Xray/Absorption/shaltout.db',
				'lib/Xray/data/cl2st.PL'        => 'lib/Xray/Absorption/cl.db',
				'lib/Xray/data/elam2st.PL'      => 'lib/Xray/Absorption/elam.db',
				'lib/Xray/data/hubbell_g2st.PL' => 'lib/Xray/Absorption/hubbell_g.db',

                                ## from Xray::Scattering
				'lib/Xray/data/cromann.PL'  => 'lib/Xray/Scattering/cromann.db',
				'lib/Xray/data/waaskirf.PL' => 'lib/Xray/Scattering/waaskirf.db',
			       },
	 recommends         => {
				## these add functionality when using demeter at the command line
				(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? 
				('Win32::Console::ANSI' => '0',) :
				('Term::Twiddle'      => '0',
				 'Term::Sk'           => '0.07',
				),
				#'Getopt::Long'       => '2.38', #  this is core

				## this is required for the gnuplot plotting backend
				#(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? () :
				'Graphics::GnuplotIF' => '0',

				## GUI for Athena, Artemis, and Hephaestus
				'Wx'                  => '0.86',

				## required by the data watcher
				'File::Monitor::Lite' => '0',

				## this suppresses a spurious warning on Windows with wxWidgets 3.0
				##(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? ('Encoding::FixLatin::XS' => 0) : (),

				## these are used for direct access to the pgplot terminal
				#'ExtUtils::F77'       => '0',
				#'PGPLOT'              => '0',
			       },
	 sign               => 1,
	 add_to_cleanup     => [
				'src/*.o',
				'src/*.so',
				'src/*.dylib',
				'src/*.dll',
				'lib/Xray/Absorption/*.db',
				'lib/Xray/Scattering/*.db',
				'lib/Xray/Crystal/share/*.db',
				'lib/Demeter/doc/dpg/bin/build',
				'lib/Demeter/doc/dpg/etc/ttree.cfg',
				'lib/Demeter/doc/dpg/html',
				'lib/Demeter/doc/dpg/templates/lib/config/map',
				'lib/Demeter/doc/dpg/templates/lib/config/version',
				't/feff',
			       ],
	 meta_merge     => {
			    resources => {
					  MailingList => 'mailto:ifeffit@millenia.cars.aps.anl.gov',
					  repository  => 'https://github.com/bruceravel/demeter',
					 }
			   },
	);

## include all required non-perl files in the installation
$build->add_build_element('db');
$build->add_build_element('cif');
$build->add_build_element('dem');
$build->add_build_element('demeter_conf');
$build->add_build_element('fit_serialization');
$build->add_build_element('htm');
$build->add_build_element('html');
$build->add_build_element('css');
$build->add_build_element('ini');
$build->add_build_element('hints');
$build->add_build_element('png');
$build->add_build_element('ico');
$build->add_build_element('jpg');
$build->add_build_element('prj');
$build->add_build_element('stan');
$build->add_build_element('tmpl');
$build->add_build_element('xpm');
## make sure pgplot will work seamlessly on windows
$build->add_build_element('dat');
$build->add_build_element('txt');

$build->create_build_script;

print <<END_MESSAGE

If all dependencies are met, build and install Demeter by doing:

  ./Build
  ./Build test
  ./Build install # (or sudo ./Build install)

If you are reinstalling Demeter after updating your operating
system (or updating perl), you may find that none of the programs
will run successfully.  You may need to do:

  ./Build touch_wrapper
  ./Build test
  ./Build install # (or sudo ./Build install)

END_MESSAGE
;

=head1 NAME

Build.PL - Demeter build script

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This is Demeter's build script using L<Module::Build>

=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter/

=cut
