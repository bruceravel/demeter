package Xray::BondValence;

use strict;
use warnings;
use version;

require Exporter;
use vars qw($VERSION);

our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw(bvparams);

$VERSION = version->new("0.1.0");


use Chemistry::Elements qw(get_Z get_symbol);
use File::Spec;

our %references = (
		   a  => 'Brown and Altermatt, (1985), Acta Cryst. B41, 244-247 (empirical)',
		   b  => 'Brese and O\'Keeffe, (1991), Acta Cryst. B47, 192-197 (extrapolated)',
		   c  => 'Adams, 2001, Acta Cryst. B57, 278-287 (includes second neighbours)',
		   d  => 'Hu et al. (1995) Inorg. Chim. Acta, 232, 161-165. ',
		   e  => 'I.D.Brown Private communication',
		   f  => 'Brown et al. (1984) Inorg. Chem. 23, 4506-4508',
		   g  => 'Palenik (1997) Inorg. Chem. 36 4888-4890',
		   h  => 'Kanowitz and Palenik (1998) Inorg. Chem. 37 2086-2088',
		   i  => 'Wood and Palenik (1998) Inorg. Chem. 37 4149-4151',
		   j  => 'Liu and Thorp (1993) Inorg. Chem. 32 4102-4105',
		   k  => 'Palenik (1997) Inorg. Chem. 36 3394-3397',
		   l  => 'Shields, Raithby, Allen and Motherwell (1999) Acta Cryst.B56, 455-465' ,
		   m  => 'Chen, Zhou and Hu (2002) Chinese Sci. Bul. 47, 978-980.',
		   n  => 'Kihlbourg (1963) Ark. Kemi 21 471; Schroeder 1975 Acta Cryst. B31, 2294',
		   o  => 'Allmann (1975) Monatshefte Chem. 106, 779',
		   p  => 'Zachariesen (1978) J.Less Common Metals 62, 1',
		   q  => 'Krivovichev and Brown (2001) Z. Krist. 216, 245',
		   r  => 'Burns, Ewing and Hawthorne (1997) Can. Miner. 35,1551-1570',
		   s  => 'Garcia-Rodriguez, et al. (2000) Acta Cryst. B56, 565-569',
		   t  => 'Mahapatra et al. (1996) J. Amer.Chem. Soc. 118, 11555',
		   u  => 'Wood and Palenik (1999) Inorg. Chem. 38, 1031-1034',
		   v  => 'Wood and Palenik (1999) Inorg. Chem. 38, 3926-3930',
		   w  => 'Wood, Abboud, Palenik and Palenik (2000) Inorg. Chem. 39, 2065-2068',
		   x  => 'Tytko, Mehnike and Kurad (1999) Structure and Bonding 93, 1-66',
		   y  => 'Gundemann, et al.(1999) J. Phys. Chem. A 103, 4752-4754',
		   z  => 'Zocchi (2000) Solid State Sci. 2 383-387',
		   aa => 'Jensen, Palenik and Tiekiak (2001) Polyhedron 20, 2137',
		   ab => 'Roulhac and Palenik (2002) Inorg. Chem. 42, 118-121',
		   ac => 'Holsa et al.(2002) J.Solid State Chem 165, 48-55',
		   ae => 'Trzesowska, Kruszynski & Bartezak (2004) Acta Cryst. B60, 174-178',
		   af => 'Locock & Burns (2004) Z.Krist. 219, 267-271',
		   ag => 'Hu & Zhou (2004) Z. Krist. 219 614-620',
		   ah => 'Trzesowska, Kruszynski & Bartczak (2005) Acta Cryst. B61 429-434',
		   ai => 'Palenik (2003) Inorg. Chem. 42, 2725-2728',
		  );

our $parameters = {};


sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};

our $data_dir = File::Spec->catfile(identify_self(), 'data');

sub read_database {
  my %all;
  open(my $D, File::Spec->catfile($data_dir, 'bvparm2006.cif'));
  my $flag = 0;
  my ($key, $comment);
  while (<$D>) {
    next if m{\A(?:\#|;|\s*\z)}; # comments (# or ;) and blank lines
    if (m{_valence_param_details}) {
      $flag = 1;
      next;
    };
    next if not $flag;
    my @list = split(" ", $_);
    ($comment = join(" ", @list[7..$#list])) =~ s{\A\'|\'\z}{}g;
    $key = join(":", @list[0..3]);
    $all{$key} ||= [];
    my $val = {r0=>$list[4], b=>$list[5], reference=>$list[6], comment=>$comment};
    push @{ $all{$key} }, $val;
  };
  close $D;
  return \%all;
};

sub available {
  my ($el, $valence, $scat) = @_;
  $valence ||= '.';		# match all valences if not specified
  $scat    ||= '.';		# match all scatterers if not specified
  $el = get_symbol($el);
  return () if not $el;
  my @list = ();
  foreach my $key (%$parameters) {
    next if ($key !~ m{\A$el:$valence:$scat});
    push @list, $key;
  };
  return sort {$a cmp $b} @list;
};

sub valences {
  my ($el) = @_;
  my @list = available($el);
  my %found;
  foreach my $item (@list) {
    ++$found{$1} if ($item =~ m{\A$el:(\d+):});
  };
  return sort keys %found;
};

sub bvparams {
  my ($el, $val, $scat) = @_;
  my ($item) = available($el, $val, $scat);
  my $hash = $parameters->{$item}->[0];
  $hash->{reference} = $references{$hash->{reference}};
  return %$hash;
};

use vars qw($DataDump_exists $DataDumpColor_exists);
$DataDump_exists = eval "require Data::Dump" || 0;
$DataDumpColor_exists = eval "require Data::Dump::Color" || 0;
sub Dump {
  my ($nocolor) = @_;
  if ($DataDumpColor_exists and not $nocolor) {
    Data::Dump::Color->dd($parameters);
  } elsif ($DataDump_exists) {
    Data::Dump->dd($parameters);
  # } elsif ($name) {
  #   print Data::Dumper->Dump([$parameters], [$parameters]);
    return 1;
  } else {
    print Dumper($parameters);
  };
};

$parameters = read_database;
1;
