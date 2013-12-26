package DemeterPerlBuild;

#<<<
use 5.008001;
use strict;
use warnings;
use Perl::Dist::WiX          1.200002;
use Perl::Dist::Strawberry   2.10     qw();
use URI::file                         qw();
use English                           qw( -no_match_vars );
use File::Spec::Functions             qw( catfile catdir );
use Archive::Zip;
local $Archive::Zip::UNICODE = 1;
use File::Path;
use Cwd                               qw( cwd );
use parent                            qw( Perl::Dist::Strawberry );
#>>>

# http://www.dagolden.com/index.php/369/version-numbers-should-be-boring/
our $VERSION = '0.630';
$VERSION =~ s/_//ms;


my $root = 'C:\strawberry';
#my %share = (demeter    => catdir( 'C:\strawberry', 'perl', 'site', 'lib', 'Demeter', 'share' ),
#	     athena     => catdir( 'C:\strawberry', 'perl', 'site', 'lib', 'Demeter', 'UI', 'Athena',     'share' ),
#	     artemis    => catdir( 'C:\strawberry', 'perl', 'site', 'lib', 'Demeter', 'UI', 'Artemis',    'share' ),
#	     hephaestus => catdir( 'C:\strawberry', 'perl', 'site', 'lib', 'Demeter', 'UI', 'Hephaestus', 'icons' ),
#	    );
my %share = (demeter    => catdir( 'C:\git', 'demeter', 'lib', 'Demeter', 'share' ),
	     perlbin    => 'C:\strawberry\perl\bin',
	     athena     => 'C:\strawberry\perl\vendor\lib\Demeter\UI\Athena\share',
	     artemis    => catdir( 'C:\git', 'demeter', 'lib', 'Demeter', 'UI', 'Artemis',    'share' ),
	     hephaestus => catdir( 'C:\git', 'demeter', 'lib', 'Demeter', 'UI', 'Hephaestus', 'icons' ),
	    );

my $tempdir = 'C:\Temp';
mkdir $tempdir if (not -d $tempdir);

######################################################################
# Configuration

sub new {
  ##my $dist_dir = File::ShareDir::dist_dir('Perl-Dist-Demeter');

  return shift->SUPER::new(

			   # Define the distribution information and where it goes.
			   app_id            => 'demeter',
			   app_name          => 'Strawberry Perl plus Demeter',
			   app_ver_name      => 'Strawberry Perl 5.12.2 plus Demeter 0.4',
			   app_publisher     => 'Demeter',
			   app_publisher_url => 'http://bruceravel.github.io/demeter/',
			   image_dir         => $root,
			   temp_dir          => $tempdir,

			   # Set e-mail to something Demeter-specific.
			   perl_config_cf_email => 'bravel@bnl.gov',

			   # The MSI stuff.
			   msi_product_icon => catfile( $share{demeter}, 'Demeter_icon.ico' ),
			   msi_help_url     => undef,
			   msi_banner_top   => catfile( $share{demeter}, 'DemeterBanner.bmp' ),
			   msi_banner_side  => catfile( $share{demeter}, 'DemeterDialog.bmp' ),

			   # Perl version
			   perl_version => '5122',

			   # Program version.
			   build_number => 1,

			   # Trace level.
			   trace => 1,

			   # Build both exe and zip versions.
			   msi => 1,
			   zip => 0,

			   # see http://strawberryperl.com/documentation/merge-module/April2010.html
			   # These are the locations to pull down the msm.
			   msm_to_use => 'http://strawberryperl.com/download/strawberry-msm/strawberry-perl-5.12.0.1.msm',
			   msm_zip    => 'http://strawberryperl.com/download/strawberry-perl-5.12.0.1.zip',
			   msm_code   => 'BC4B680E-4871-31E7-9883-3E2C74EA4F3C',
			   #fileid_perl          => 'F_exe_MzA1Mjk2NjIyOQ',
			   #fileid_relocation_pl => 'F_lp_NDIwNjE2MjkyNw',


			   # Tasks to complete to create Strawberry + Demeter.
			   tasklist => [
					'final_initialization',
					'initialize_using_msm',
					'install_non_perl_prerequisites',
					'install_demeter_prereq_modules',
					'install_demeter_modules',
					'install_win32_extras',
					'install_strawberry_extras',
					'install_demeter_extras',
					'remove_waste',
					'regenerate_fragments',
					'write',
				       ],

			   # Other parameters passed in override the ones
			   # here and in Strawberrry.
			   @_,
			  );

}				## end sub new



sub output_base_filename {
	return 'strawberry-plus-demeter-0.4';
}



#####################################################################
# Customisations for Perl assets

sub install_perl_589 {
	my $self = shift;
	PDWiX->throw('Perl 5.8.9 is not available in Demeter Standalone');
	return;
}



sub install_perl_5100 {
	my $self = shift;
	PDWiX->throw('Perl 5.10.0 is not available in Demeter Standalone');
	return;
}



sub install_perl_5101 {
	my $self = shift;
	PDWiX->throw('Perl 5.10.1 is not available in Demeter Standalone');
	return;
}


sub install_perl_5120 {
	my $self = shift;
	PDWiX->throw('Perl 5.12.0 is not available in Demeter Standalone');
	return;
}

#sub install_perl_5121 {
#	my $self = shift;
#	PDWiX->throw('Perl 5.12.1 is not available in Demeter Standalone');
#	return;
#}



# Params::Util after Algorithm::C3
# Sub::Uplevel after Test::Fatal
# IO::String after File::Remove
# Digest::SHA after DateTime
# YAML::Tiny after YAML::XS
# YAML after Error
# File::Remove after Hook::LexWrap
# Test::Tester before Hook::LexWrap
# Archive::Zip at top
# Task::Weaken after MRO::Compat
# File::Slurp after MooseX::Types
# Test::Exception after List::MoreUtils
# HTML::Entities before List::MoreUtils
# Algorithm::Diff before Spiffy
# Text::Diff after Spiffy
# Test::NoWarnings after Test::Object
# HTML::Tagset after Heap




sub install_demeter_prereq_modules {
	my $self = shift;

	# Manually install our non-Wx dependencies first to isolate
	# them from the Wx problems
	$self->install_modules( qw{
				    Capture::Tiny
				    Chemistry::Elements
				    Config::IniFiles

				    Try::Tiny
				    Test::Fatal
				    Class::Load
				    Class::Singleton
				    Params::Validate
				    List::MoreUtils
				    DateTime::TimeZone
				    DateTime::Locale
				    Math::Round

				    DateTime
				    Graph
				    Heap

				    Math::Combinatorics
				    Math::Derivative
				    Math::Spline

				    Algorithm::C3
				    Sub::Install
				    Data::OptList
				    Class::C3
				    Sub::Exporter
				    Dist::CheckConflicts
				    Scope::Guard
				    Test::Requires
				    Package::DeprecationManager
				    Package::Stash::XS
				    MRO::Compat
				    Eval::Closure
				    Package::Stash
				    Sub::Name
				    Devel::GlobalDestruction

				    Moose
				    MooseX::Aliases
				    MooseX::AttributeHelpers

				    Variable::Magic
				    Sub::Identify
				    B::Hooks::EndOfScope
				    namespace::clean
				    namespace::autoclean

				    MooseX::StrictConstructor

				    Carp::Clan

				    MooseX::Types

				    Pod::POM
				    Const::Fast
				    Regexp::Common
				    Regexp::Assemble

				    OLE::Storage_Lite
				    Parse::RecDescent

				    Spreadsheet::WriteExcel
				    Statistics::Descriptive
				    String::Random
				    Text::Template
				    Tree::Simple
				    Want

				    Error
				    YAML::Syck
				    YAML::Perl
				    YAML::XS

				    Spiffy
				    Test::Base
				    Test::Differences
				    ExtUtils::ParseXS
				    ExtUtils::XSpp

				    AppConfig
				    Template

				    Hook::LexWrap
				    Test::Object
				    Clone
				    Test::SubCalls
				    Class::Inspector
				    PPI

				    Image::Size
				    CSS::Tiny
				    PPI::HTML

				    Win32::Pipe
				    Win32::Console::ANSI
				} );

	return 1;
} ## end sub install_demeter_prereq_modules


## Demeter has a large number of non-perl dependencies (Gnuplot,
## PGPLOT, readline, ncurses, Ifeffit).  My strategy for getting them
## into the package is to place them all in a staging area and zip up
## the contents of the staging area.  In this task, the zip file is
## opened and the files are extracted and installed one by one using
## install_file.
sub install_non_perl_prerequisites {
  my $self = shift;
  # install non-perl prereqs from the big zip file
  my $prereq_dir = 'prereq';
  rmtree $prereq_dir if (-d  $prereq_dir);
  mkdir $prereq_dir;
  my $zip = Archive::Zip->new('Demeter.prereqs.zip');
  foreach my $m ($zip->members) {
    next if $m->isDirectory;
    (my $this = $m->fileName) =~ s{[^/]*/}{};
    my $from = catfile(cwd, $prereq_dir, $this);
    my $destination = catfile('c', $this);
    $zip->extractMember($m, $from);
    #print "$/$/$from --->$destination$/$/$/";
    $self->install_file(file => $from,
			url => q{},
			install_to => $destination);
  };
  rmtree $prereq_dir;
  return 1;
};


## From Curtis Jewell, regarding the Alien-wxWidgets par file:
# BUT: The par becomes dependent on your major version of Perl and your
# $Config::Config{archname}. If you're building on 5.12, or building for
# 64-bit Windows, you have to rebuild the par file, because that one is
# for 5.10.1, and 32-bit. (the name is
# _DIST_-_VERSION_-_ARCHNAME_-_PERLVERSION_.par)
#
# That's easy enough.
#
# Extract Alien::wxWidgets, do the appropriate 'perl Makefile.PL && dmake
# && dmake test' or 'perl Build.PL && Build && Build test', whichever one
# it is, and then run 'perl -MPAR::Dist -eblib_to_par' or 'Build pardist'.
sub install_demeter_modules {
  my $self = shift;

  ## install Graphics::GunplotIF, this par file contains a version of
  ## the CPAN G::G modified to work on Windows
  print "Installing Graphics-Gnuplot\n";
  my $par_url = 'http://10.0.61.254/~bruce/strawberry/Graphics-GnuplotIF-1.6-MSWin32-x86-multi-thread-5.12.2.par';
  my $filelist = $self->install_par(
				    name => 'Graphics-GnuplotIF',
				    dist_info => $par_url,
				    url  => $par_url,
				   );
  print "Installing Graphics-Gnuplot ... Done!\n";


  ## no critic(RestrictLongStrings)
  ## Install the Alien::wxWidgets module from a precompiled .par since compilation takes so darn long
  ##
  ## The class underneath install_par (Perl::Dist::WiX::Asset::PAR)
  ## reuires that the dist_info attribute be set, apparently to the
  ## thing as the url attribute.  go figure...
  print "Installing Wx ... \n";
  $par_url = 'http://10.0.61.254/~bruce/strawberry/Alien-wxWidgets-0.52-MSWin32-x86-multi-thread-5.12.2.par';
  $filelist = $self->install_par(
				 name => 'Alien_wxWidgets',
				 dist_info => $par_url,
				 url  => $par_url,
				);

  # Install the Wx module over the top of alien module
  $self->install_module( name => 'Wx' );
  print "Installing Wx ... Done!\n";

  # Install modules that add more Wx functionality
  #$self->install_module(
  #			name  => 'Wx::Perl::ProcessStream',
  #			force => 1 # since it fails on vista
  #		       );

  # And finally, install Demeter itself
  ## do a "perl Build dist" first?
  print "Installing Demeter ...\n";
  $par_url = 'http://10.0.61.254/~bruce/strawberry/Demeter-v0.4.7-MSWin32-x86-multi-thread-5.12.0.par';
  $filelist = $self->install_par(
				 name => 'Demeter',
				 dist_info => $par_url,
				 url  => $par_url,
				);
  # $self->install_distribution_from_file(
  # 					file => 'C:\git\demeter\Demeter-v0.4.7.tar.gz',
  # 					url => q{},
  # 					force => 0,
  # 					automated_testing => 1,
  # 				       );
  print "Installing Demeter ... Done!\n";

  return 1;
}				## end sub install_demeter_modules

sub install_demeter_extras {
  my $self = shift;

  # Get the Id for directory object that stores the filename passed in.
  print "Getting dir_id$/";
  my $dir_id = $self->get_directory_tree()
    ->search_dir(
		 path_to_find => catdir( $self->image_dir(), 'perl', 'bin' ),
		 exact        => 1,
		 descend      => 1,
		)->get_id();

  print "Getting icon_id$/";
  my $icon_id =
    $self->_icons()
      ->add_icon( catfile( $share{athena},  'athena_icon.ico' ),
		  catfile( $share{perlbin}, 'dathena.bat' ));

  # Add the start menu icon.
  print "Adding start menu icon$/";
  $self->get_fragment_object('StartMenuIcons')
    ->add_shortcut(
		   name        => 'Athena',
		   description => 'Athena: XAS Data Prcessing',
		   target      => "[D_$dir_id]dathena",
		   id          => 'Athena',
		   working_dir => $dir_id,
		   icon_id     => $icon_id,
		  );

  return 1;
}				## end sub install_demeter_extras

1;

__END__
