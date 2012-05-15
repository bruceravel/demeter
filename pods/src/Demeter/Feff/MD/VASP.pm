package Demeter::Feff::MD::VASP;
use Moose::Role;
use Moose::Util::TypeConstraints;

with 'Demeter::UI::Screen::Progress' if $Demeter::mode->ui eq 'screen';

use File::CountLines qw(count_lines);
use Chemistry::Elements qw (get_Z);
use Compress::Zlib;
use Regexp::Assemble;

has 'atoms'   => (traits    => ['Array'],
		  is        => 'rw',
		  isa       => 'ArrayRef',
		  default   => sub { [] },
		  handles   => {
				'push_atoms'  => 'push',
				'pop_atoms'   => 'pop',
				'clear_atoms' => 'clear',
			       },
		  documentation   => "atomic species obtained from the VRHFIN lines");
has 'numbers' => (traits    => ['Array'],
		  is        => 'rw',
		  isa       => 'ArrayRef',
		  default   => sub { [] },
		  handles   => {
				'push_numbers'  => 'push',
				'pop_numbers'   => 'pop',
				'clear_numbers' => 'clear',
			       },
		  documentation   => "numbers of each species obtained from the 'ions per type' line");
has 'indeces' => (traits    => ['Array'],
		  is        => 'rw',
		  isa       => 'ArrayRef',
		  default   => sub { [] },
		  handles   => {
				'push_indeces'  => 'push',
				'pop_indeces'   => 'pop',
				'clear_indeces' => 'clear',
			       },
		  documentation   => "index ranges of each species in the cluster lists");
has 'start'   => (is	          => 'rw',
		  isa	          => 'ArrayRef',
		  default	  => sub{[]},
		  documentation   => "the starting configuration of the cluster");



my @element_list = qw(H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca
		      Sc Ti V Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr Rb
		      Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I Xe Cs
		      Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf
		      Ta W Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac
		      Th Pa U Np Pu
		      Nu);
my $element_regexp = Regexp::Assemble->new()->add(@element_list)->re;


sub _number_of_steps {
  my ($self) = @_;
  die("File ".$self->file." does not exist\n") if (not -e $self->file);
  die("File ".$self->file." cannot be read\n") if (not -r $self->file);
  my $fh = gzopen($self->file, "rb") or die "could not open $self->file as a VASP OUTCAR file\n";
  my $count = 0;
  my $line = q{};
  local $|=1;
  while ($fh->gzreadline($line) > 0) {
    last if $line =~ m{\A\s*General timing};
    ++$count if $line =~ m{\APOSITION};
  }
  #print $steps, $/;
  $fh->gzclose();
  $self->nsteps($count);
  return $self;
};

sub _cluster {
  my ($self) = @_;
  $self->reading_file(1);
  my $nruns  = count_lines($self->file, separator => 'General timing') + 1;
  my $nlines = count_lines($self->file);
  #print $nlines, $/;
  my $fh = gzopen($self->file, "rb") or die "could not open $self->file as a VASP OUTCAR file\n";
  my @cluster = ();
  my @all = ();
  my $line = q{};
  my $count = 0;
  if ($self->mo->ui eq 'screen') {
    #$self->start_spinner("Reading VASP file ".$self->file) 
    $self->progress('%30b %c of %m (x10^4) lines in file <Time elapsed: %8t>');
    $self->start_counter("Reading VASP file ".$self->file." with $nlines lines and $nruns runs", int($nlines/1e4/$nruns));
  };
  my %flag = (starting_configuration => 0,
	      time_step              => 0,
	      line_of_dashes         => 0,
	      npos                   => 0,
	      direct_lattice         => 0);
 FILE: while ($fh->gzreadline($line) > 0) {
    if (not $. % 1e4) {
      if ($self->mo->ui eq 'screen') {
	$self->count;
      } elsif (lc($self->mo->ui) eq 'wx') {
	$self->call_sentinal;
      };
    };

    if ($flag{starting_configuration}) {
      next FILE;

    ## ----------------------------------------------------------------------
    ## we are currently in a block of positions at a time step
    } elsif ($flag{time_step}) {
      if (($line =~ m{-{2,}}) and (not $flag{line_of_dashes})) {
	## this is the beginning of the time point block
	$flag{line_of_dashes} = 1;
	next FILE;
      } elsif (($line =~ m{-{2,}}) and $flag{line_of_dashes}) {
	## this is the end of the time point block
	push @all, [@cluster];
	$#cluster = -1;
	$flag{line_of_dashes} = 0;
	$flag{time_step}      = 0;
	$flag{npos}           = 0;
	next FILE;
      } else {
	## this is a position in a time point
	++$flag{npos};
	my @position = split(" ", $line);
	my $atom = q{};
      ATOM: foreach my $i (0 .. $#{$self->indeces}) {
	  #print $flag{npos}, " ", $self->indeces->[$i], $/;
	  if ($flag{npos} <= $self->indeces->[$i]) {
	    $atom = $self->atoms->[$i];
	    last ATOM;
	  };
	};
	#print join("|", @position[0..2], $atom), $/;
	push @cluster, [@position[0..2], get_Z($atom)];
      };
      next FILE;

    } elsif ($flag{direct_lattice}) {
      next if $#{$self->lattice} == 2; # already found
      my @vec = split(" ", $line);
      $self->push_lattice([@vec[0..2]]);
      $self->periodic(1);
      $flag{direct_lattice} = 0 if ($#{$self->lattice} == 2);
      next FILE;
    } elsif ($line =~ m{\A\s*direct lattice vectors}) {
      $flag{direct_lattice} = ($#{$self->lattice} == 2) ? 0 : 1;
      next FILE;

    ## ----------------------------------------------------------------------
    ## this line identifies an atom species
    } elsif ($line =~ m{\A\s*VRHFIN\s*=($element_regexp)}) {
      $self->push_atoms($1);
      next FILE;

    ## ----------------------------------------------------------------------
    ## this line identifies how many of each atom species there are
    } elsif ($line =~ m{\A\s*ions per type}) {
      my @line = split(" ", $line);
      shift @line; shift @line; shift @line; shift @line;
      $self->numbers(\@line);
      my $sum = 0;
      my @i = map {$sum+=$_} @line; # e.g. if numbers is (16,16,32,16), then indeces becomes (16,32,64,80)
      $self->indeces(\@i);
      next FILE;

    ## ----------------------------------------------------------------------
    ## this is the endof a run
    } elsif ($line =~ m{\A\s*General timing}) {
      last FILE;

    ## ----------------------------------------------------------------------
    ## this is the beginning of a block of positions at a time step
    } elsif ($line =~ m{\A\s*POSITION}) {
      ++$count;
      $flag{time_step} = 1;
      next FILE;

    ## ----------------------------------------------------------------------
    ## all other lines in this ginormous file are unimportant
    } else {
      next FILE;
    };
  };
  $self->nsteps($count);
  $self->clusters(\@all);

  $fh->gzclose();
  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->reading_file(0);
  $self->update_file(0);
  return $self;
};

1;


=head1 NAME

Demeter::Feff::MD::VASP - Role supporting VASP OUTCAR file

=head1 VERSION

This documentation refers to Demeter version 0.9.10.

=head1 SYNOPSIS

=head1 DESCRIPTION

This role provides support for importing data from the VASP formatted
OUTCAR file, which is a format for providing the trajectory of a
cluster during a molecular dynamics simulation (as well as a lot of
other information not reelvant to this context).  The VASP website is
L<http://cms.mpi.univie.ac.at/vasp/>.  The OUTCAR file format is not
well documented (or, at least, I have not found its documentation),
but not very hard to interpret.  It is, however, humungo-ginormous.

The purpose of this role is to parse the VASp OUTCAR file into the
data structures expected by the rest of Demeter's histogram subsystem.

=head1 NOTES ON THE OUTCAR FILE

=over 4

=item *

An OUTCAR file can be the concatination of more than one VASP runs.  A
run begins with a line identifying the VASP version number, a line
identifying the machine it ran on and the date of the run, and a line
identifying the number of nodes of the cluster. It ends with a table
labeled C<General timing and accounting informations for this job:>
with statistics about time, memorty, and CPU usage of the run.

=item *

The first information in the file identifies each of the potential
types.  The most relevant line begins with the keyword C<VRHFIN>.
This identifies the atomic species.  For instance

  VRHFIN =Ti: 3s3p4s3d

This line identifies a titanium atom and its electronic configuration.

There will be one such line for each atom type in the cluster.  They
will be separated by about 50 lines on other information about that
atoms potential and electronic configuration.

=item *

The information about how many of each type of atom is pretty well
hidden.  After about 400 lines, you find a section that starts
C<Dimension of arrays:>.  One of the following lines looks like so:

  ions per type =              16  16  32  16

This says how many of the atoms identified by the C<VRHFIN> lines and
in the same order as the C<VRHFIN> lines appear.

=item *

After a long stretch of data about the run (several hundred lines)
there are sections labeled 

   position of ions in fractional coordinates (direct lattice)

and

   position of ions in cartesian coordinates  (Angst):

These two lists show the starting configuration of the cluster.  The
second is more to the point, since it is in cartesian coordinates.

This list is in the order specified by the order of the C<VRHFIN>
lines and in the numbers of indicated bythe C<ions per type> line.

=item *

Soon after that, the MD time sequence starts.  After quite a bit of
self-consistency looping, you come accross a line that starts
C<POSITION>.  This is a time step.  This followed by a line of dashes,
then lines with the cartesian coordinates of and forces on each atom.
It is finished by a line of dashes and there may be blank lines.

=item *

Keep reading C<POSITION> entries until you come to the end of the run.

=back

=head1 METHODS

=over 4

=item C<_number_of_steps>

Fills the C<nsteps> attribute of the object using this role with the
number of time steps contained in the input file (contained in the
C<file> attribute).

=item C<_cluster>

Fills C<clusters> attribute with a list-of-lists, each inner list
containing the cartesian coordinates and atomic species of each item
in the cluster at that time step.  The outer list is a list of
timesteps in chronological order.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This currently only works for a monoatomic cluster.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

