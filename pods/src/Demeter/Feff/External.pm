package Demeter::Feff::External;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use autodie qw(open close);

use Moose;
extends 'Demeter::Feff';
use MooseX::Aliases;

use List::MoreUtils qw(none firstidx);
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;

use Demeter::StrTypes qw(FileName);
use Demeter::Constants qw($CTOKEN $EPSILON4);

has '+source'   => (default => 'external');
has 'file'      => (is => 'rw', isa => FileName,  default => q{},
		    trigger => sub{my ($self, $new) = @_;
				   $self->rdinp if $new;
				   $self->folder(File::Spec->rel2abs(dirname($new)));
				 });
has '+name'     => (default => 'external Feff',);
has 'folder'    => (is => 'rw', isa => 'Str',  default => q{},
		    trigger => sub{my ($self, $new) = @_; $self->read_folder($new)} );
has 'workspace' => (is=>'rw', isa => 'Str', default => q{}, # valid directory
		    trigger=>sub{my ($self, $new) = @_;
				 mkpath($new);
				 copy($self->phasebin, $new) if (-e $self->phasebin);
			       });

has 'phasebin'  => (is => 'rw', isa => 'Str',  default => q{},);
has 'filesdat'  => (is => 'rw', isa => 'Str',  default => q{},);
has 'pathsfile' => (is => 'rw', isa => 'Str',  default => q{},);
has 'npaths'    => (is => 'rw', isa => 'Int',  default => 0,);
has 'nnnn'      => (
		    traits    => ['Hash'],
		    is        => 'rw',
		    isa       => 'HashRef',
		    default   => sub { {} },
		    handles   => {
				  'exists_in_nnnn' => 'exists',
				  'ids_in_nnnn'    => 'keys',
				  'get_nnnn'       => 'get',
				  'set_nnnn'       => 'set',
				 },
		   );


sub read_folder {
  my ($self, $folder) = @_;
  opendir(my $F, $folder);
  my @files = readdir $F;
  closedir $F;

  if (none {$_ eq 'phase.bin'} @files) {
    #carp("Demeter::Feff::External::read_folder: $folder does not contain a phase.bin file");
    $self->phasebin();
    #return $self;
  } else {
    $self->phasebin(File::Spec->catfile($folder, 'phase.bin'));
    if ($self->folder ne $self->workspace) {
      if (-d $self->workspace) {
	copy($self->phasebin, $self->workspace);
      } elsif ($self->workspace) {
	mkpath($self->workspace);
	copy($self->phasebin, $self->workspace);
      } else {
	$self->check_workspace;
      };
    };
  };
  if (none {$_ eq 'files.dat'} @files) {
    #carp("Demeter::Feff::External::read_folder: $folder does not contain a files.dat file");
    $self->filesdat();
    #return 0;
  };
  #if (none {$_ eq 'paths.dat'} @files) {
  #  carp("Demeter::Feff::External::read_folder: $folder does not contain a paths.dat file");
  #  $self->pathsfile();
  #  return 0;
  #};

  $self->filesdat (File::Spec->catfile($folder, 'files.dat'));
  $self->pathsfile(File::Spec->catfile($folder, 'paths.dat'));

  $self->_preload_distances;
  my $zcwif_of = $self->parse_zcwif_from_files;
  my @feffNNNN = sort {$a cmp $b} grep {$_ =~ m{\Afeff\d{4}\.dat\z}} @files;
  my %hash;
  foreach my $f (@feffNNNN) {	# convert each feffNNNN to a ScatteringPath object
    my $sp = Demeter::ScatteringPath->new(feff=>$self, pathfinding=>0);
    $sp->mo->push_ScatteringPath($sp);
    my ($string, $nleg, $degen, $reff, $pathno) = $self->parse_info_from_nnnn($f);
    $zcwif_of->{$f} ||= 0;	# handle absence of files.dat gracefully
    $sp->set(string=>$string, nleg=>$nleg, n=>int($degen), fuzzy=>$reff, zcwif=>$zcwif_of->{$f});
    my $weight = ($zcwif_of->{$f} > 20) ? 2
               : ($zcwif_of->{$f} > 10) ? 1
	       :                          0;
    $sp->weight($weight);
    #print $f, "  ", $zcwif_of->{$f}, $/;
    $sp->evaluate;
    $sp->degeneracies([$sp->string]);
    $sp->fromnnnn(File::Spec->catfile($folder, $f));
    $sp->orig_nnnn($pathno);
    $self->push_pathlist($sp);
    #set_nnnn($f, $sp->group);
    $hash{$f} = $sp->group;
  };
  $self->nnnn(\%hash);
  my @ids = $self->ids_in_nnnn;
  $self->npaths($#ids + 1);
  return $self;
};


##################################################################################
## here is an example of the first few lines of a feffNNNN.dat file:
##
#  PbTiO3 25C                                             Feff 6L.02    potph 4.12
#  Glazer and Mabud, Acta Cryst. B34, 1065-1070 (1978)
#  Abs   Z=22 Rmt= 1.047 Rnm= 1.371 K shell
#  Pot 1 Z=82 Rmt= 1.527 Rnm= 1.733
#  Pot 2 Z=22 Rmt= 1.053 Rnm= 1.384
#  Pot 3 Z= 8 Rmt= 0.822 Rnm= 1.136
#  Gam_ch=9.067E-01 H-L exch
#  Mu=-3.881E+00 kf=2.139E+00 Vint=-2.132E+01 Rs_int= 1.695
#  Path   10      icalc       2                           Feff 6L.02   genfmt 1.44
#  -------------------------------------------------------------------------------
#    2   4.000   3.9050    2.4484   -3.88128 nleg, deg, reff, rnrmav(bohr), edge
#         x         y         z   pot at#
#      0.0000    0.0000    0.0000  0  22 Ti       absorbing atom
#     -3.9050    0.0000    0.0000  2  22 Ti
#     k   real[2*phc]   mag[feff]  phase[feff] red factor   lambda      real[p]@#
#   0.000  2.2848E+00  0.0000E+00  7.3999E-01  0.1017E+01  3.5964E+01  2.1396E+00
#   0.200  2.2794E+00  1.0810E-01 -7.3986E-01  0.1017E+01  3.6107E+01  2.1485E+00
#   0.400  2.2635E+00  1.9981E-01 -2.0608E+00  0.1017E+01  3.6451E+01  2.1751E+00
#   0.600  2.2375E+00  2.6484E-01 -3.2362E+00  0.1016E+01  3.6748E+01  2.2187E+00
#             and so on ....
##################################################################################

sub parse_info_from_nnnn {
  my ($self, $f) = @_;
  my $file = File::Spec->catfile($self->folder, $f);
  my @geometry = ();
  my ($nleg, $degen, $reff, $pathno);
  my $flag = 0;
  open(my $NNNN, $file);
  while (<$NNNN>) {
    last if (m{\A\s+k\s+real\[2\*phc\]});
    if (m{\A\s+Path\s+(\d+)}) { # find line with path index
      $pathno = sprintf("%4.4d", $1);
    };
    if (m{nleg,\s+deg,\s+reff}) { # find line with degeneracy and Reff
      my @fields = split(" ", $_);
      ($nleg, $degen, $reff) = @fields[0..2];
    };
    $flag = 1 if (m{absorbing atom\s*\z});
    next unless $flag;
    ## make a simple id string out of the coordinates of the scatterers in this path
    my @fields = split(" ", $_);
    push @geometry, [@fields[0..2]];
  };
  close $NNNN;

  ## make a ScatteringPath string out of this scattering geometry
  ## see _visit and _parentage in Demeter::Feff
  my $string = q{};
  foreach my $atom (@geometry) {
    my $i = 0;
    foreach my $s (@{$self->sites}) { # identify atoms in the feffNNNN geometry by index in the feff.inp ATOMS list
      if ( (abs($atom->[0] - $s->[0]) < $EPSILON4) and
	   (abs($atom->[1] - $s->[1]) < $EPSILON4) and
	   (abs($atom->[2] - $s->[2]) < $EPSILON4) ) {
	$string .= "$i.";
	last;
      } else {
	++$i;
      };
    };
  };
  $string =~ s{\A0}{$CTOKEN};
  $string .= $CTOKEN;
  $pathno ||= '0000';

  return ($string, $nleg, $degen, $reff, $pathno);
};


sub parse_zcwif_from_files {
  my ($self) = @_;
  my %hash = ();
  return %hash if (not -e $self->filesdat);
  open(my $FD, $self->filesdat);
  while (<$FD>) {
    next if ($_ !~ m{\A\s*feff\d{4}\.dat});
    my @fields = split(" ", $_);
    $hash{$fields[0]} = $fields[2];
  };
  close $FD;
  return \%hash;
};

sub is_complete {
  my ($self) = @_;
  return 0 if (not $self->file);
  return ( $self->npaths
	   and $self->filesdat and (-e $self->filesdat) and (-r $self->filesdat)
	   and $self->phasebin and (-e $self->phasebin) and (-r $self->phasebin)
	 );
};

sub problem {
  my ($self) = @_;
  my $message = q{};
  $message .= "That folder has no feffNNNN files.\n"  if (not $self->npaths);
  $message .= "That folder has no phase.bin file.\n"  if (not $self->phasebin);
  $message .= "That phase.bin file cannot be read.\n" if ((-e $self->phasebin) and (not -r $self->phasebin));
  $message .= "That folder has no files.dat file.\n"  if (not $self->filesdat);
  $message .= "That files.dat file cannot be read.\n" if ((-e $self->filesdat) and (not -r $self->filesdat));
  return $message;
};

override 'pathfinder' => sub {
  1;
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Feff::External - Import and manipulate external Feff calculations

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

  my $feff = Demeter::Feff::External -> new();
  $feff   -> set(workspace=>"temp", screen=>0);
  $feff   -> file('/path/to/feff.inp');
  foreach my $sp (@{$feff->pathlist}) {
    Demeter::Path -> new(sp=>$sp) -> plot('r');
  };

=head1 DESCRIPTION

This extension of the L<Demeter::Feff> class allows you to import an
externally calculated Feff6 (or Feff7) calculation and interact with
it very similarly to a Feff calculation handled in the normal manner in
Demeter.

The assumption is that you have a folder somewhere on disk in which
you have already made a Feff calculation.  Specifically, that folder
should be populated by

=over 4

=item *

A F<feff.inp>, which can be called something other than F<feff.inp>.

=item *

The F<phase.bin> file from the calculation.

=item *

Some number of F<feffNNNN.dat> files from that calculation.

=item *

Possibly a F<files.dat> and C<paths.dat> files as well, although
neither is currently used.  These are written normally by Feff and
should be found in any folder containing a Feff calculation.

=back

When you set the C<workspace> and C<file> attributes inherited from
the normal Demeter::Feff object, the F<feff.inp> file is parsed to set
the attributes inherited from Demeter::Feff, the F<phase.bin> file is
copied to the C<workspace>, and the F<feffNNNN.dat> files are parsed
and made into L<Demeter::ScatteringPath> objects.  The ScatteringPath
objects are then loaded into the C<pathlist> attribute of this object.

Once all that is done, everything proceeds in the manner of a
Demeter-handled Feff calculation.  Path objects are created using the
ScatteringPath objects generated from the F<feffNNNN.dat> files as the
values of the C<sp> attribute (see L<Demeter::Path>).  Most methods of
the Feff object are available, including C<find_path> and
C<find_all_paths> (see L<Demeter::Feff::Paths>).

There are a few differences bewteen a normal Feff calculation and an
external one.  This object has no C<pathfinder> method at this time,
the assumption being that the pathfinder need not be run again.  Also
the ScatteringPath objects do not retain a memory of the geometries of
the degenerate paths nor will the concept of fuzzy degeneracy used in
any way.

Aside from being able to import existing Feff calculations, there are
two obvious uses for the external Feff object:

=over 4

=item *

Import old-style Artemis project files, which contain entire Feff
calculations

=item *

Consider Feff calculations with more than 4-legged paths, something
Demeter's pathfinder cannot yet do.

=back

=head1 ATTRIBUTES

Along with all the attributes inherited from the Demeter::Feff object,
these are added:

=over 4

=item C<folder>

The location on disk of the external Feff calculation.  This is set
automatically once the C<file> attribute is set.

=item C<phasebin>

The fully resolved file name for the C<phase.bin> file.

=item C<filesdat>

The fully resolved file name for the C<files.dat> file.  This is not
currently used.

=item C<pathsfile>

The fully resolved file name for the C<paths.dat> file from the
external Feff calculation.  This is not currently used.

=back

Note that the C<source> attribute is set to "external" for a
Demeter::Feff::External object.

=head1 METHODS

There are no new methods relevant to the user beyond those inherited
from the Demeter::Feff object.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter> for a description of the configuration system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Import a Feff8 calculation (requires ability to parse a Feff8 input file).

=item *

Serialization/deserialization is scantily tested.

=item *

Let pathfinder method actually run Feff's pathfinder.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
