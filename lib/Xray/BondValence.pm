package Xray::BondValence;

use strict;
use warnings;
use version;

require Exporter;
use vars qw($VERSION);

our @ISA = qw(Exporter);
our @EXPORT = qw();
our @EXPORT_OK = qw(bvparams bvdescribe valences available);

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
  open(my $D, '<', File::Spec->catfile($data_dir, 'bvparm2006.cif'));
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
  my ($el, $valence, $scat, $scatval) = @_;
  $valence ||= '.';		# match all valences if not specified
  $scat    ||= '.';		# match all scatterers if not specified
  $scatval ||= '.';		# match all scatterer valences if not specified
  if (ref($el) =~ m{Demeter}) {
    my $path = $el;
    ($el, $valence, $scat, $scatval) = $path->get(qw(bvabs valence_abs bvscat valence_scat));
  };
  $el = get_symbol($el);
  return () if not $el;
  my @list = ();
  foreach my $key (%$parameters) {
    next if ($key !~ m{\A$el:$valence:$scat:$scatval});
    push @list, $key;
  };
  return sort {$a cmp $b} @list;
};

sub valences {
  my ($el) = @_;
  $el = $el->bvabs if ($el =~ m{Demeter});
  my @list = available($el);
  my %found;
  foreach my $item (@list) {
    ++$found{$1} if ($item =~ m{\A$el:(\d+):});
  };
  return sort keys %found;
};

sub anions {
  my %seen;
  my @list;
  foreach my $key (keys %$parameters) {
    @list = split(/:/, $key);
    ++$seen{join(" ", $list[2], $list[3])};
  };
  my $sum = 0;
  $sum += $_ foreach (values %seen);
  return %seen;
};

sub bvparams {
  my ($el, $val, $scat, $scatval) = @_;
  my ($item) = available($el, $val, $scat, $scatval);
  my $hash = {};
  $hash = $parameters->{$item}->[0] if ($item and exists $parameters->{$item});
  $hash->{citation} = $references{$hash->{reference}} if exists $hash->{reference};
  return %$hash;
};

sub bvdescribe {
  my ($el, $valence, $scat, $scatval) = @_;
  $valence ||= '.';		# match all valences if not specified
  $scat    ||= '.';		# match all scatterers if not specified
  $scatval ||= '.';		# match all scatterer valences if not specified
  if (ref($el) =~ m{Demeter}) {
    my $path = $el;
    ($el, $valence, $scat, $scatval) = $path->get(qw(bvabs valence_abs bvscat valence_scat));
  };
  my %hash = bvparams($el, $valence, $scat, $scatval);
  return sprintf("%s %s+ with %s %s: b=%s  r0=%s", $el, $valence, $scat, $scatval, $hash{b}, $hash{r0});
};

sub Dump {
  my ($nocolor) = @_;
  my $DataDump_exists = eval "require Data::Dump" || 0;
  my $DataDumpColor_exists = eval "require Data::Dump::Color" || 0;
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

# As -3|68
# B   3|1
# Br -1|125
# C  -4|6
# C   2|3
# C   4|1
# Cl -1|142
# Cl -2|1
# Co -1|1
# F  -1|168
# H  -1|68
# Hg  2|1
# I  -1|99
# I  -2|1
# I   0|1
# Mn -2|1
# N  -2|1
# N  -3|109
# O  -1|1
# O  -2|183
# P  -3|68
# P   5|1
# S  -2|128
# S   2|1
# Se -1|4
# Se -2|78
# Te -2|70


=head1 NAME

Xray::BondValence - A perl interface to David Brown's tabulation of bond valence parameters

=head1 SYNOPSIS

   use Xray::BondValence qw(bvdescribe valences available);
   ...

=head1 DESCRIPTION

This provides an interface to the tabulation of bond valence parameters

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

The tabulation of bond valence parameters carried the following
copyright notice and disclaimer:

  #***************************************************************
  # COPYRIGHT NOTICE
  # This table may be used and distributed without fee for
  # non-profit purposes providing
  # 1) that this copyright notice is included and
  # 2) no fee is charged for the table and
  # 3) details any changes made in this list by anyone other than
  # the copyright owner are suitably noted in the _audit_update record
  # Please consult the copyright owner regarding any other uses.
  #
  # The copyright is owned by I. David Brown, Brockhouse Institute for
  # Materials Research, McMaster University, Hamilton, Ontario Canada.
  # idbrown@mcmaster.ca
  #
  #*****************************DISCLAIMER************************
  #
  # The values reported here are taken from the literature and
  # other sources and the author does not warrant their correctness
  # nor accept any responsibility for errors.  Users are advised to
  # consult the primary sources.
  #
  #***************************************************************

