use 5.006001;
use strict;

BEGIN {
  die "CPANPLUS::Dist::Build version 0.08 or later is required to install Module::Build\n"
    if $INC{'CPANPLUS/Dist/Build.pm'} && CPANPLUS::Dist::Build->VERSION lt '0.08';
}

# On some platforms (*ahem*, MacPerl 5.6.1) "use lib qw(lib);" doesn't
# find the local "lib" directory, so we use File::Spec to do it properly.
use File::Spec 0.82;
use lib File::Spec->catdir('lib');          # use our self to install
# XXX This doesn't carry over to sub processes
use lib File::Spec->catdir('t', 'bundled'); # use bundled modules
use lib File::Spec->catdir('t', 'lib');     # our utilities

# bootstrap configure_requires prereqs
BEGIN { do 'inc/bootstrap.pl' }

# We use Module::Build to test & install itself.
use Module::Build;

# 

my $build = Module::Build->new(
  module_name => 'Module::Build',
  license     => 'perl',
  configure_requires => {
    'CPAN::Meta'            => '2.142060',
    'Perl::OSType'          => 1,
    'Module::Metadata'      => '1.000002',
    'version'               => '0.87',
  },
  build_requires        => {
    'File::Temp'            => 0.15,    # tmpdir() + fixes
    'Test::More'            => 0.49,
    'Test::Harness'         => 3.16,    # PERL5LIB fixes
    'Parse::CPAN::Meta'     => '1.4401',
    'CPAN::Meta::YAML'      => 0.003,
  },
  # KEEP 'requires' as low as possible and target Build/test/install
  # Requirements for authors should be implemented as optional features
  requires    => {
    'perl'                  => '5.008000',
    'Data::Dumper'          => 0,
    'File::Basename'        => 0,
    'File::Compare'         => 0,
    'File::Copy'            => 0,
    'File::Find'            => 0,
    'File::Path'            => 0,
    'File::Spec'            => ($^O eq 'MSWin32' ? 3.30 : '0.82'), # rel2abs()
    'ExtUtils::CBuilder'    => 0.27, # major platform fixes
    'ExtUtils::Install'     => 0,
    'ExtUtils::Manifest'    => 0,
    'ExtUtils::Mkbootstrap' => 0,
    'ExtUtils::ParseXS'     => 2.21, # various bug fixes
    'Cwd'                   => 0,
    'Text::Abbrev'          => 0,
    'Text::ParseWords'      => 0,
    'Getopt::Long'          => 0,
    'Test::Harness'         => 0,
    'CPAN::Meta'            => '2.142060',
    'Perl::OSType'          => ( $^O eq 'bitrig' ? 1.004 : 1 ), # needs 1.0 API
    'version'               => 0.87,  # No longer requires M::B
    'Module::Metadata'      => 1.000002, # uses version.pm
    'Pod::Man'              => 2.17, # utf8 support
  },
  recommends => {
    'ExtUtils::Install'  => 0.30,
    'ExtUtils::Manifest' => 1.54, # public maniskip()
  },
  recursive_test_files => 1,
  sign          => 0, 
  create_readme => 1,
  create_license => 1,

  # overwrite the M::B that shipped in core
  installdirs   => ($] >= 5.009004 && $] < 5.011 ? 'core' : 'site'),

  # Some CPANPLUS::Dist::Build versions need to allow mismatches
  # On logic: thanks to Module::Install, CPAN.pm must set both keys, but
  # CPANPLUS sets only the one
  allow_mb_mismatch => (
    $ENV{PERL5_CPANPLUS_IS_RUNNING} && ! $ENV{PERL5_CPAN_IS_RUNNING} ? 1 : 0
  ),

  auto_features => {
    dist_authoring => {
      description => "Create new distributions",
      requires => {
        'Archive::Tar'       => 1.09,
      },
      recommends => {
        'Pod::Readme'        => 0.04,
        'Module::Signature'  => 0.21,
      },
    },
    license_creation => {
      description => "Create licenses automatically in distributions",
      requires => {
        'Software::License'  => 0.103009
      },
    },
    PPM_support => {
      description => "Generate PPM files for distributions",
    },
    inc_bundling_support => {
      description => "Bundle Module::Build in inc/",
      requires    => {
        'inc::latest'           => 0.500, # split out from Module::Build
        'ExtUtils::Install'     => 1.54, # also gets us ExtUtils::Installed 1.999_001
        'ExtUtils::Installed'   => 1.999, # technically 1.999_001 is what's available
      },
    },
    manpage_support => {
      description => "Create Unix man pages",
      requires    => {'Pod::Man' => 0 },
    },
    HTML_support => {
      description => "Create HTML documentation",
      requires    => {'Pod::Html' => 0},
    },
  },

  add_to_cleanup => ['t/Sample/pod2htm*'],
  script_files   => ['bin/config_data'],
  meta_merge     => {
    resources => {
      MailingList => 'mailto:module-build@perl.org',
      repository  => 'https://github.com/Perl-Toolchain-Gang/Module-Build',
      IRC         => 'irc://irc.perl.org/#toolchain',
    }
  },
);

$build->create_build_script;
if (-f "META.yml" && ! -f "MYMETA.yml") { # fallback if we don't have CPAN::Meta
  require File::Copy;
  File::Copy::copy("META.yml", "MYMETA.yml") or warn "Error: $!\n";
  if ( -f 'MYMETA.yml' ) {
    warn "Copied META.yml to MYMETA.yml for bootstrapping\n";
  }
  else {
    warn "Could not copy META.yml to MYMETA.yml.  That's odd!\n";
  }
}

# vim:ts=2:sw=2:et:sta
