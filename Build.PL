#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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


use strict;
use warnings;
use Cwd;
use File::Spec;
use Module::Build;

my $class = Module::Build->subclass(
      class => "Module::Build::Custom",
      code => <<'SUBCLASS' );

  sub ACTION_update {
      my $self = shift;
      my $ret = $self->do_system(qw(svn update));
      die "failed to update Demeter from svn\n" if not $ret;
  };
  sub ACTION_full_update {
      my $self = shift;
      $self->depends_on("update");
      $self->depends_on("test");
      $self->depends_on("install");
  };
SUBCLASS

my $build = $class
  -> new(
	 module_name        => 'Demeter',
	 create_readme      => 0,
	 ##create_makefile_pl => 'traditional',
	 license            => 'gpl',
	 dist_author        => 'Bruce Ravel <bravel AT bnl DOT gov>',
	 requires           => {
				'autodie'                   => '0',
				'Module::Build'	            => '0',

				'Moose'			    => '1.05',
				'MooseX::Aliases'           => '0.08',
				'MooseX::AttributeHelpers'  => '0.23',
				'MooseX::StrictConstructor' => '0.08',
				'MooseX::Singleton'	    => '0.22',
				'MooseX::Types'		    => '0.21',

				'Archive::Zip'		   => '0',

				'Capture::Tiny'	           => '0.07',
				'Chemistry::Elements'	   => '0',
				'Config::IniFiles'	   => '2.45',
				'DateTime'                 => '0',
				'Digest::SHA'		   => '0',
				'Graph'                    => '0',
				'Heap'			   => '0',
                                'HTML::Entities'           => '0',
				'List::MoreUtils'	   => '0',
				'Math::Combinatorics'	   => '0',
				'Math::Derivative'	   => '0',
				'Math::Round'		   => '0',
				'Math::Spline'		   => '0',
				'Pod::POM'                 => '0',
				'Readonly'		   => '0',
				'Regexp::Common'	   => '0',
				'Regexp::Optimizer'	   => '0',
                                'Spreadsheet::WriteExcel'  => '0',
				'String::Random'           => '0',
				'Text::Template'	   => '0',
				'Tree::Simple'		   => '0',
				'Want'			   => '0',
				'YAML::Tiny'		   => '0',

				## deprecated....
				#'Compress::Raw::Zlib'	   => '0',
				#'Compress::Raw'	   => '0',
				#'File::Touch'		   => '0',
				#'Math::Cephes'		   => '0',
			       },
	 build_requires     => {
				## these are used to build the demeter programming guide
				'Template'            => '2.22',
				'PPI'                 => '0',
				'PPI::HTML'           => '0',
				'Image::Size'         => '0',
			       },
	 PL_files           => {
				'lib/Xray/Crystal/share/space_groups.db.PL' => 'lib/Xray/Crystal/share/space_groups.db',
				'lib/Demeter/doc/dpg/build_dpg.PL' => [],
			       },
	 recommends         => {
				## these add functionality when using demeter at the command line
				(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? () :
				('IO::Prompt'	      => '0',
				 'Term::Twiddle'      => '0',
				 'Term::Sk'           => '0',
				),

				## this is required for the gnuplot plotting backend
				(($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? () :
				('Graphics::GnuplotIF' => '0'),

				## GUI for Artemis and Hephaestus
				'Wx'                  => '0.86'

				## these are used for direct access to the pgplot terminal
				#'ExtUtils::F77'       => '0',
				#'PGPLOT'              => '0',
			       },
	 sign               => 0,
	);

## include all required non-perl files in the installation
$build->add_build_element('db');
$build->add_build_element('dem');
$build->add_build_element('demeter_conf');
$build->add_build_element('fit_serialization');
$build->add_build_element('htm');
$build->add_build_element('html');
$build->add_build_element('css');
$build->add_build_element('ini');
$build->add_build_element('png');
$build->add_build_element('prj');
$build->add_build_element('stan');
$build->add_build_element('tmpl');
$build->add_build_element('xpm');
## make sure pgplot will work seamlessly on windows
$build->add_build_element('dat');
$build->add_build_element('txt');

$build->create_build_script;

