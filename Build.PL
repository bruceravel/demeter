#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


use strict;
use warnings;
use Module::Build;

my $build = Module::Build
  -> new(
	 create_readme      => 0,
	 ##create_makefile_pl => 'traditional',
	 license            => 'gpl',
	 module_name        => 'Demeter',
	 dist_author        => 'Bruce Ravel <bravel AT bnl DOT gov>',
	 requires           => {
				'version'		   => '0',
				#'Module::Build'	   => '0',

				'Moose'			   => '0.57',
				'MooseX::AttributeHelpers' => '0',
				'MooseX::Clone'		   => '0',
				'MooseX::Singleton'	   => '0',
				'MooseX::Types'		   => '0',

				#'Compress::Raw::Zlib'	   => '0',
				#'Compress::Raw'	   => '0',
				'Archive::Zip'		   => '0',

				'Chemistry::Elements'	   => '0',
				#'Config::IniFiles'	   => '0',
				'Digest::SHA'		   => '0',
				'Heap'			   => '0',
				'List::MoreUtils'	   => '0',
				'Math::Cephes'		   => '0',
				'Math::Derivative'	   => '0',
				'Math::Round'		   => '0',
				'Math::Spline'		   => '0',
				'Readonly'		   => '0',
				'Regexp::Common'	   => '0',
				'Regexp::Optimizer'	   => '0',
				'Text::Template'	   => '0',
				'Text::Wrap'		   => '0',
				'Tree::Simple'		   => '0',
				'Want'			   => '0',
				'YAML'			   => '0',
			       },
	 PL_files           => {
				'lib/Xray/Crystal/share/space_groups.db.PL' => 'lib/Xray/Crystal/share/space_groups.db'
			       },
	 recommends         => {
				'IO::Prompt'	      => '0',
				'Term::ANSIColor'     => '0',
				'Term::ReadLine'      => '0',
				'Term::Twiddle'	      => '0',
				'Graphics::GnuplotIF' => '0',
				'Wx'                  => '0.86'
			       },
	 sign               => 0,
	);

## include all required non-perl files in the installation
$build->add_build_element('db');
$build->add_build_element('dem');
$build->add_build_element('demeter_conf');
$build->add_build_element('fit_serialization');
$build->add_build_element('htm');
$build->add_build_element('ini');
$build->add_build_element('png');
$build->add_build_element('prj');
$build->add_build_element('stan');
$build->add_build_element('tmpl');
$build->add_build_element('xpm');

$build->create_build_script;

