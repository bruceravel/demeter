#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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
use Module::Build;

## deal with the fact that Text::Wrap does not live in a package
## called Text-Wrap.  This confuses ppm, so post-process the ppd file
## to point at the requirement that ppm will resolve.
my $class = Module::Build->subclass(
				    class => "My::Builder",
				    code => q{

sub ACTION_ppd {
   my $self = shift;
   $self->SUPER::ACTION_ppd;

   open O, '>__temp__';
   open I, 'Demeter.ppd';
   while (<I>) {
     $_ =~ s{Text-Wrap}{Text-Tabs+Wrap};
     print O $_;
   };
   close I;
   close O;
   rename '__temp__', 'Demeter.ppd';
};
},
				   );

my $build = $class
  -> new(
	 module_name        => 'Demeter',
	 create_readme      => 0,
	 ##create_makefile_pl => 'traditional',
	 license            => 'gpl',
	 dist_author        => 'Bruce Ravel <bravel AT bnl DOT gov>',
	 requires           => {
				'version'		   => '0',
				'autodie'                  => '0',
				'Module::Build'	           => '0',

				'Moose'			   => '0.63',
				'MooseX::AttributeHelpers' => '0.13',
				'MooseX::Clone'		   => '0.03',
				'MooseX::Singleton'	   => '0.13',
				'MooseX::Types'		   => '0.07',

				#'Compress::Raw::Zlib'	   => '0',
				#'Compress::Raw'	   => '0',
				'Archive::Zip'		   => '0',

				'Chemistry::Elements'	   => '0',
				'Config::IniFiles'	   => '2.45',
				'Digest::SHA'		   => '0',
				'Heap'			   => '0',
				'List::MoreUtils'	   => '0',
				'Math::Cephes'		   => '0',
				'Math::Derivative'	   => '0',
				'Math::Round'		   => '0',
				'Math::Spline'		   => '0',
				'Pod::POM'                 => '0',
				'Readonly'		   => '0',
				'Regexp::Common'	   => '0',
				'Regexp::Optimizer'	   => '0',
				'String::Random'           => '0',
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
				#'ExtUtils::F77'       => '0',
				#'PGPLOT'              => '0',
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

