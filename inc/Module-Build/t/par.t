#!/usr/bin/perl -w

use strict;
use lib 't/lib';
use MBTest;
blib_load('Module::Build');
blib_load('Module::Build::ConfigData');

my $tmp;

{
  my ($have_c_compiler, $tmp_exec) = check_compiler();
  if ( ! $have_c_compiler ) {
    plan skip_all => 'No compiler found';
  } elsif ( ! eval {require PAR::Dist; PAR::Dist->VERSION(0.17)} ) {
    plan skip_all => "PAR::Dist 0.17 or up not installed to check .par's.";
  } elsif ( ! eval {require Archive::Zip} ) {
    plan skip_all => "Archive::Zip required.";
  } else {
    plan tests => 3;
  }
  require Cwd;
  $tmp = MBTest->tmpdir( $tmp_exec ? () : (DIR => Cwd::cwd) );
}



use DistGen;
my $dist = DistGen->new( dir => $tmp, xs => 1 );
$dist->add_file( 'hello', <<'---' );
#!perl -w
print "Hello, World!\n";
__END__

=pod

=head1 NAME

hello

=head1 DESCRIPTION

Says "Hello"

=cut
---
$dist->change_build_pl
({
  module_name => $dist->name,
  version => '0.01',
  license     => 'perl',
  scripts     => [ 'hello' ],
});
$dist->regen;

$dist->chdir_in;

use File::Spec::Functions qw(catdir);

my @installstyle = qw(lib perl5);
my $mb = Module::Build->new_from_context(
  verbose => 0,
  quiet   => 1,

  installdirs => 'site',
);

my $filename = $mb->dispatch('pardist');

ok( -f $filename, '.par distributions exists' );
my $distname = $dist->name;
ok( $filename =~ /^\Q$distname\E/, 'Distribution name seems correct' );

#--------------------------------------------------------------------------#
# must work around broken Archive::Zip (1.28) which breaks PAR::Dist
#--------------------------------------------------------------------------#

SKIP: {
  my $zip = Archive::Zip->new;
  my $tmp2 = MBTest->tmpdir;
  local %SIG;
  $SIG{__WARN__} = sub { print STDERR $_[0] unless $_[0] =~ /\bstat\b/ };
  skip "broken Archive::Zip", 1
    unless eval { $zip->read($filename) == Archive::Zip::AZ_OK() }
    && eval { $zip->extractTree('', "$tmp2/") == Archive::Zip::AZ_OK() }
    && -r File::Spec->catfile( $tmp2, 'blib', 'META.yml' );

  my $meta;
  eval { $meta = PAR::Dist::get_meta($filename) };

  ok(
    (not $@ and defined $meta and not $meta eq ''),
    'Distribution contains META.yml'
  );
}

