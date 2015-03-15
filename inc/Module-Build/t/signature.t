#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use MBTest;

if ( have_module( 'Module::Signature' )
  && $INC{'Module/Signature.pm'} =~ m{t/lib/Module/Signature\.pm} 
) {
  plan tests => 12;
} else {
  plan skip_all => "Mock Module::Signature not loadable";
}

blib_load('Module::Build');

#########################

my $tmp = MBTest->tmpdir;

use DistGen;
my $dist = DistGen->new( dir => $tmp );
$dist->change_build_pl
({
  module_name => $dist->name,
  license     => 'perl',
  sign        => 1,
  auto_configure_requires => 0,
  quiet => 1,
});
$dist->regen;

$dist->chdir_in;

#########################

my $mb = Module::Build->new_from_context;

{
  eval {$mb->dispatch('distdir')};
  my $err = $@;
  is $err, '';
  chdir( $mb->dist_dir ) or die "Can't chdir to '@{[$mb->dist_dir]}': $!";
  ok -e 'SIGNATURE';

  $dist->chdir_in;
}

{
  # Fake out Module::Signature and Module::Build - the first one to
  # run should be distmeta.
  my @run_order;
  {
    local $^W; # Skip 'redefined' warnings
    local *Module::Signature::sign;
    *Module::Signature::sign = sub { push @run_order, 'sign' };
    local *Module::Build::Base::ACTION_distmeta;
    *Module::Build::Base::ACTION_distmeta = sub { push @run_order, 'distmeta' };
    eval { $mb->dispatch('distdir') };
  }
  is $@, '';
  is $run_order[0], 'distmeta';
  is $run_order[1], 'sign';
}

eval { $mb->dispatch('realclean') };
is $@, '';

{
  eval {$mb->dispatch('distdir', sign => 0 )};
  is $@, '';
  chdir( $mb->dist_dir ) or die "Can't chdir to '@{[$mb->dist_dir]}': $!";
  ok !-e 'SIGNATURE', './Build distdir --sign 0 does not sign';
}

eval { $mb->dispatch('realclean') };
is $@, '';

$dist->chdir_in;

{
    local @ARGV = '--sign=1';
    $dist->change_build_pl({
        module_name => $dist->name,
        license     => 'perl',
        auto_configure_requires => 0,
        quiet => 1,
    });
    $dist->regen;

    my $mb = Module::Build->new_from_context;
    is $mb->{properties}{sign}, 1;

    eval {$mb->dispatch('distdir')};
    my $err = $@;
    is $err, '';
    chdir( $mb->dist_dir ) or die "Can't chdir to '@{[$mb->dist_dir]}': $!";
    ok -e 'SIGNATURE', 'Build.PL --sign=1 signs';
}

