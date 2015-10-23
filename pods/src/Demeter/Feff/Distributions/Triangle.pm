package Demeter::Feff::Distributions::Triangle;
use Moose::Role;
use MooseX::Aliases;

use POSIX qw(acos);
use Demeter::Constants qw($PI);

use Demeter::NumTypes qw( Ipot );

## DS triangle histogram attributes
has 'skip'      => (is => 'rw', isa => 'Int', default => 50,);
has 'nconfig'   => (is => 'rw', isa => 'Int', default => 0, documentation => "the number of triangle configurations found at each time step");
has 'r1'        => (is => 'rw', isa => 'LaxNum', default => 0.0,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'r2'        => (is => 'rw', isa => 'LaxNum', default => 3.5,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'r3'        => (is => 'rw', isa => 'LaxNum', default => 5.2,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'r4'        => (is => 'rw', isa => 'LaxNum', default => 5.7,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'angle'     => (is => 'rw', isa => 'LaxNum', default => 90,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'margin'    => (is => 'rw', isa => 'LaxNum', default => 10,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'rbin'      => (is            => 'rw',
		    isa           => 'LaxNum',
		    default       => 0.02,
		    trigger	  => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);
has 'betabin'   => (is            => 'rw',
		    isa           => 'LaxNum',
		    default       => 0.5,
		    trigger	  => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);

has 'ipot'      => (is => 'rw', isa => Ipot, default => 1,
		    traits  => ['MooseX::Aliases::Meta::Trait::Attribute'],
		    alias   => 'ipot1',
		    trigger => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new});
has 'ipot2'     => (is => 'rw', isa => Ipot, default => 1,
		    trigger => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new}, );

has 'triang'    => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

sub _bin {
  my ($self) = @_;

  $self->start_spinner(sprintf("Rebinning triangle configurations into %.3f A x %.2f deg bins", $self->rbin, $self->betabin)) if ($self->mo->ui eq 'screen');

  ## slice the configurations in R
  my @slices = ();
  my @this   = ();
  my $r_start = $self->triang->[0]->[0];
  my $aa = 0;
  foreach my $tb (@{$self->triang}) {
    my $rr = $tb->[0];
    if (($rr - $r_start) > $self->rbin) {
      push @slices, [@this];
      $r_start += $self->rbin;
      $#this=-1;
      push @this, $tb;
    } else {
      push @this, $tb;
    };
    ++$aa;
  };
  push @slices, [@this];
  #print ">>>>>>>>", $#slices+1, $/;

  ## pixelate each slice in angle
  my @plane = ();
  my @pixel = ();
  my $bb = 0;
  foreach my $sl (@slices) {
    my @slice = sort {$a->[4] <=> $b->[4]} @$sl; # sort by angle within this slice in R
    my $beta_start = 0;
    @pixel = ();
    foreach my $tb (@slice) {
      my $beta = $tb->[4];
      if (($beta - $beta_start) > $self->betabin) {
	push @plane, [@pixel];
	$beta_start += $self->betabin;
	@pixel = ();
	push @pixel, $tb;
      } else {
	push @pixel, $tb;
      };
      ++$bb;
    };
    push @plane, [@pixel];
  };
  ##print ">>>>>>>>", $#plane+1, $/;

};

sub rdf {
  my ($self) = @_;
  my $count = 0;
  my $r1sqr = $self->r1**2;
  my $r2sqr = $self->r2**2;
  my $r3sqr = $self->r3**2;
  my $r4sqr = $self->r4**2;

  $self->start_counter(sprintf("Making radial/angle distribution from every %d-th timestep", $self->skip), ($#{$self->clusters}+1)/$self->skip) if ($self->mo->ui eq 'screen');
  my ($x0, $x1, $x2) = (0,0,0);
  my ($bx, $by, $bz) = (0,0,0);
  my @rdf_1 = ();
  my @rdf_2 = ();
  my @tri   = ();
  my @this  = ();
  my $costh;
  my $i4;
  my $halfpath;
  my ($ct, $st, $cp, $sp, $ctp, $stp, $cpp, $spp, $cppp, $sppp, $beta, $leg2);
  foreach my $step (@{$self->clusters}) {
    @rdf1 = ();
    @rdf4 = ();

    @this = @$step;
    $self->timestep_count(++$count);
    next if ($count % $self->skip); # only process every Nth timestep
    $self->count if ($self->mo->ui eq 'screen');
    $self->call_sentinal;

    ## dig out the coordination shells corresponding to atoms 1 and 2
    foreach my $i (0 .. $#this) {
      ($x0, $x1, $x2) = @{$this[$i]};
      foreach my $j (0 .. $#this) {
	next if ($i == $j);
	my $rsqr = ($x0 - $this[$j]->[0])**2
	         + ($x1 - $this[$j]->[1])**2
	         + ($x2 - $this[$j]->[2])**2; # this loop has been optimized for speed, hence the weird syntax
	push @rdf_1, [sqrt($rsqr), $i, $j] if (($rsqr > $r1sqr) and ($rsqr < $r2sqr));
	push @rdf_2, [sqrt($rsqr), $i, $j] if (($rsqr > $r3sqr) and ($rsqr < $r4sqr));
      };
    };

    ## find those 1st/2nd atom pairs that share an absorber and have the correct angle between them
    foreach my $second (@rdf4) {
      $i2 = $fourth->[1];
      foreach my $first (@rdf1) {
	next if ($i2 != $first->[1]);

	## the absorber
	($absx, $absy, $absz) = ($this[ $i2  ]->[0], $this[ $i2  ]->[1], $this[ $i2  ]->[2]);

	## absorber --> atom 1 vector
	($ct, $st, $cp, $sp)     = $self->_trig( $this[ $first->[2]  ]->[0]-$absx,
						 $this[ $first->[2]  ]->[1]-$absy,
						 $this[ $first->[2]  ]->[2]-$absz );
	## absorber --> atom 2 vector
	($ctp, $stp, $cpp, $spp) = $self->_trig( $this[ $second->[2] ]->[0]-$absx,
						 $this[ $second->[2] ]->[1]-$absy,
						 $this[ $second->[2] ]->[2]-$absz );
	$cppp = $cp*$cpp + $sp*$spp;
	$sppp = $spp*$cp - $cpp*$sp;

	$beta = $ct*$ctp + $st*$stp*$cppp;
	if ($beta < -1) {
	  $beta = 180;
	} elsif ($beta >  1) {
	  $beta = 0;
	} else {
	  $beta = 180 * acos($beta)  / $PI;
	};
	next if (($beta > $self->angle + $self->margin) or ($beta < $self->angle - $self->margin));

	$leg1 = sqrt( ($bx - $this[ $first->[2]  ]->[0])**2 +
		      ($by - $this[ $first->[2]  ]->[1])**2 +
		      ($bz - $this[ $first->[2]  ]->[2])**2 );
	$leg2 = sqrt( ($bx - $this[ $second->[2] ]->[0])**2 +
		      ($by - $this[ $second->[2] ]->[1])**2 +
		      ($bz - $this[ $second->[2] ]->[2])**2 );
	$leg3 = sqrt( ($this[ $first->[2]->[0]  ] - $this[ $second->[2] ]->[0])**2 +
		      ($this[ $first->[2]->[1]  ] - $this[ $second->[2] ]->[1])**2 +
		      ($this[ $first->[2]->[2]  ] - $this[ $second->[2] ]->[2])**2 );
	$halfpath = ($leg1 + $leg2 + $leg3) / 2;
	push @tri, [$halfpath, $leg1, $leg2, $leg3, $beta];


      };
    };
  };

  if ($self->mo->ui eq 'screen') {
    $self->stop_counter;
    $self->start_spinner("Sorting triangle path length/angle distribution by path length");
  };
  @tri = sort { $a->[0] <=> $b->[0] } @tri;
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  $self->nconfig( $#tri+1 );
  #$self->nconfig( int( ($#three+1) / (($#{$self->clusters}+1) / $self->skip) + 0.5 ) );
  # local $|=1;
  # print "||||||| ", $self->nconfig, $/;
  $self->triang(\@tri);
  $self->update_rdf(0);
  return $self;
};

sub chi {

};

sub describe {
  my ($self, $composite) = @_;
  my $text = sprintf("\n\ntriangle configurations with atom 1 between %.3f and %.3f A\natom 2 between %.3f and %.3f A\nbinned into %.4f A x %.4f deg bins",
		     $self->get(qw{r1 r2 r3 r4 rbin betabin}));
  $composite->pdtext($text);
};

sub plot {

};

sub info {
  my ($self) = @_;
  my $text = sprintf "Made histogram from %s file '%s'\n\n", uc($self->backend), $self->file;
  return $text;
};



1;

=head1 NAME

Demeter::Feff::Distributions::Triangle - Histograms for short triangular paths

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

=head1 DESCRIPTION

This provides methods for generating two-dimensional histograms in
path length and scattering angle for nearly short triangular
arrangements of three atoms, like so:

   Absorber ---> Scatterer ---> Scatterer --+
     ^                                      |
     |                                      |
     +--------------------------------------+

Given two radial ranges for the nearer and more distant scatterers and
bin sizes for 

=head1 ATTRIBUTES

=over 4

=item C<file> (string)

The path to and name of the HISTORY file.  Setting this will trigger
reading of the file and construction of a histogram using the values
of the other attributes.

=item C<nsteps> (integer)

When the HISTORY file is first read, it will be parsed to obtain the
number of time steps contained in the file.  This number will be
stored in this attribute.

=item C<r1> and C<r2>; C<r3> and C<r4> (numbers)

The lower and upper bounds of the radial distribution function for the
near and distant scatterer.

=item C<rbin> (number)

The width of the histogram bin to be extracted from the RDF.

=item C<betabin> (number)

The forward scattering angular range of the histogram bin to be
extracted from the RDF.

=back

=head1 METHODS

=over 4

=item C<fpath>

Return a L<Demeter::FPath> object representing the sum of the bins of
the histogram extracted from the cluster.

=item C<plot>

Make a plot of the the RDF.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.
Many attributes of a Data object can be configured via the
configuration system.  See, among others, the C<bkg>, C<fft>, C<bft>,
and C<fit> configuration groups.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 SERIALIZATION AND DESERIALIZATION


=head1 BUGS AND LIMITATIONS


Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
