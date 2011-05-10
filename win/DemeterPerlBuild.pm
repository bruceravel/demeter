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
	     athena     => catdir( 'C:\git', 'demeter', 'lib', 'Demeter', 'UI', 'Athena',     'share' ),
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
			   app_publisher_url => 'http://bruceravel.github.com/demeter/',
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




sub install_demeter_prereq_modules {
	my $self = shift;

	# Manually install our non-Wx dependencies first to isolate
	# them from the Wx problems
	$self->install_modules( qw{
				    Archive::Zip
				    Capture::Tiny
				    Chemistry::Elements
				    Config::IniFiles

				    Try::Tiny
				    Test::Fatal
				    Sub::Uplevel
				    Class::Load
				    Class::Singleton
				    Params::Validate
				    List::MoreUtils
				    Test::Exception
				    DateTime::TimeZone
				    DateTime::Locale
				    Math::Round

				    DateTime
				    Digest::SHA
				    Graph
				    Heap

				    HTML::Tagset

				    HTML::Entities
				    List::MoreUtils
				    Math::Combinatorics
				    Math::Derivative
				    Math::Spline

				    Algorithm::C3
				    Params::Util
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
				    Task::Weaken
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
				    MooseX::Singleton

				    Carp::Clan

				    MooseX::Types

				    File::Slurp

				    Pod::POM
				    Readonly
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
				    YAML
				    YAML::Syck
				    YAML::Perl
				    YAML::XS
				    YAML::Tiny

				    Algorithm::Diff
				    Spiffy
				    Text::Diff
				    Test::Base
				    Test::Differences
				    ExtUtils::ParseXS
				    ExtUtils::XSpp

				    AppConfig
				    Template

				    Test::Tester
				    Hook::LexWrap
				    File::Remove
				    IO::String
				    Test::Object
				    Test::NoWarnings
				    Clone
				    Test::SubCalls
				    Class::Inspector
				    PPI

				    Image::Size
				    CSS::Tiny
				    PPI::HTML
				} );

	return 1;
} ## end sub install_demeter_prereq_modules


sub install_non_perl_prerequisites {
  my $self = shift;
  # install non-perl prereqs from the big zip file
  my $prereq_dir = 'prereq';
  rmtree $prereq_dir;
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
  return 1;
};


## regarding the Alien-wxWidgets par file:
# BUT: The par becomes dependent on your major version of Perl and your
# $Config::Config{archname}. If you're building on 5.12, or building for
# 64-bit Windows, you have to rebuild the par file, because that one is
# for 5.10.1, and 32-bit. (the name is
# _DIST_-_VERSION_-_ARCHNAME_-_PERLVERSION_.par)
#
# That's easy enough.
#
# Extract Alien::wxWidgets, do the appropriate 'perl Makefile.PL && dmake
# && dmake test' or 'perl Build.PL & Build && Build test', whichever one
# it is, and then run 'perl -MPAR::Dist -eblib_to_par'.

sub install_demeter_modules {
  my $self = shift;

  ## install gnuplot and Graphics::GunplotIF

  ## no critic(RestrictLongStrings)
  # Install the Alien::wxWidgets module from a precompiled .par
  ## The class underneath install_par (Perl::Dist::WiX::Asset::PAR)
  ## reuires that the dist_info attribute be set, apparently to the
  ## thing as the url attribute.  go figure...
  my $par_url = 'http://cars9.uchicago.edu/~ravel/misc/athena+artemis/Alien-wxWidgets-0.52-MSWin32-x86-multi-thread-5.12.2.par';
  ##  'http://strawberryperl.com/download/padre/Alien-wxWidgets-0.50-MSWin32-x86-multi-thread-5.10.1.par';
  my $filelist = $self->install_par(
				    name => 'Alien_wxWidgets',
				    dist_info => $par_url,
				    url  => $par_url,
				   );

  # Install the Wx module over the top of alien module
  ## Wx 0.99 failed to install, so try 0.98 installed from a file
  $self->install_module( name => 'Wx' );



  # Install modules that add more Wx functionality
  #$self->install_module(
  #			name  => 'Wx::Perl::ProcessStream',
  #			force => 1 # since it fails on vista
  #		       );

  # And finally, install Demeter itself
  ## do a "perl Build dist" first?
  $self->install_distribution_from_file(
					file => 'C:\git\demeter\Demeter-v0.4.7.tar.gz',
					url => q{},
					force => 0,
					automated_testing => 1,
				       );

  return 1;
}				## end sub install_demeter_modules

sub install_demeter_extras {
  my $self = shift;

  # Get the Id for directory object that stores the filename passed in.
  my $dir_id = $self->get_directory_tree()
    ->search_dir(
		 path_to_find => catdir( $self->image_dir(), 'perl', 'site', 'bin' ),
		 exact        => 1,
		 descend      => 1,
		)->get_id();

  my $icon_id =
    $self->_icons()
      ->add_icon( catfile( $share{athena}, 'athena_icon.ico' ), 'dathena' );

  # Add the start menu icon.
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
