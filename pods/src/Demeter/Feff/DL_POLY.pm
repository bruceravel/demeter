package Demeter::Feff::DL_POLY;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;

use Moose;
use MooseX::Aliases;
#use MooseX::StrictConstructor;
extends 'Demeter';
use Demeter::StrTypes qw( Empty );
use Demeter::NumTypes qw( Natural PosInt NonNeg Ipot );

use POSIX qw(acos);
use Readonly;
Readonly my $PI => 4*atan2(1,1);
Readonly my $TRIGEPS => 1e-6;

with 'Demeter::Data::Arrays';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

use List::Util qw{sum};

has '+plottable'      => (default => 1);

## HISTORY file attributes
has 'nsteps'    => (is => 'rw', isa => NonNeg, default => 0);
has 'nbins'     => (is => 'rw', isa => NonNeg, default => 0);
has 'file'      => (is => 'rw', isa => 'Str', default => q{},
		    trigger => sub{ my($self, $new) = @_;
				    if ($new and (-e $new)) {
				      $self->_cluster;
				      $self->rdf if $self->ss;
				      $self->nearly_collinear if $self->ncl;
				    };
				  });
has 'clusters'    => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

## SS histogram attributes
has 'update_bins' => (is            => 'rw',
		      isa           => 'Bool',
		      default       => 1);
has 'rmin'        => (is	    => 'rw',
		      isa	    => 'Num',
		      default	    => 0.0,
		      trigger	    => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},
		      documentation => "The lower bound of the SS histogram to be extracted from the cluster");
has 'rmax'        => (is	    => 'rw',
		      isa	    => 'Num',
		      default	    => 5.6,
		      trigger	    => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},
		      documentation => "The upper bound of the SS histogram to be extracted from the cluster");
has 'bin'         => (is            => 'rw',
		      isa           => 'Num',
		      default       => 0.005,);
has 'ssrdf'       => (is	    => 'rw',
		      isa	    => 'ArrayRef',
		      default	    => sub{[]},
		      documentation => "unbinned distribution extracted from the cluster");
has 'npairs'      => (is            => 'rw',
		      isa           => NonNeg,
		      default       => 0);
has 'positions'   => (is            => 'rw',
		      isa           => 'ArrayRef',
		      default       => sub{[]},
		      documentation => "array of bin positions of the extracted histogram");
has 'populations' => (is	    => 'rw',
		      isa	    => 'ArrayRef',
		      default	    => sub{[]},
		      documentation => "array of bin populations of the extracted histogram");

## nearly collinear DS and TS historgram attributes
has 'skip'      => (is => 'rw', isa => 'Int', default => 50,);
has 'nconfig'   => (is => 'rw', isa => 'Int', default => 0, documentation => "the number of 3-body configurations found at each time step");
has 'r1'        => (is => 'rw', isa => 'Num', default => 0.0,);
has 'r2'        => (is => 'rw', isa => 'Num', default => 3.5,);
has 'r3'        => (is => 'rw', isa => 'Num', default => 5.2,);
has 'r4'        => (is => 'rw', isa => 'Num', default => 5.7,);
has 'beta'      => (is => 'rw', isa => 'Num', default => 20,);
has 'rbin'      => (is            => 'rw',
		    isa           => 'Num',
		    default       => 0.02,);
has 'betabin'   => (is            => 'rw',
		    isa           => 'Num',
		    default       => 0.5,);

has 'ss'        => (is => 'rw', isa => 'Bool', default => 0, trigger=>sub{my($self, $new) = @_; $self->ncl(0) if $new});
has 'ncl'       => (is => 'rw', isa => 'Bool', default => 0, trigger=>sub{my($self, $new) = @_; $self->ss(0)  if $new});

has 'bin_count'   => (is => 'rw', isa => 'Int',  default => 0);
has 'timestep_count' => (is => 'rw', isa => 'Int',  default => 0);
has 'nearcl'      => (is => 'rw', isa => 'ArrayRef', default => sub{[]});


has 'feff'        => (is => 'rw', isa => Empty.'|Demeter::Feff', default => q{},);
has 'sp'          => (is => 'rw', isa => Empty.'|Demeter::ScatteringPath', default => q{},);

has 'ipot'        => (is => 'rw', isa => Ipot, default => 1, alias => 'ipot1');
has 'ipot2'       => (is => 'rw', isa => Ipot, default => 1, );

## need a pgplot plotting template

sub rebin {
  my($self, $new) = @_;
  $self->_bin   if ($self->ss  and $self->update_bins);
  $self->_bin2d if ($self->ncl and $self->update_bins);
  return $self;
};

sub _number_of_steps {
  my ($self) = @_;
  open(my $H, '<', $self->file);
  my $count = 0;
  while (<$H>) {
    ++$count if m{\Atimestep};
  }
  #print $steps, $/;
  close $H;
  $self->nsteps($count);
  return $self;
};

sub _cluster {
  my ($self) = @_;
  $self->_number_of_steps;
  open(my $H, '<', $self->file);
  my @cluster = ();
  my @all = ();
  while (<$H>) {
    if (m{\Atimestep}) {
      push @all, [@cluster] if $#cluster>0;
      $#cluster = -1;
      next;
    };
    next if not m{\APt}; # skip the three lines trailing the timestamp
    my $position = <$H>;
    my @vec = split(' ', $position);
    push @cluster, \@vec;
    <$H>;
    <$H>;
    #my $velocity = <$H>;
    #my $force    = <$H>;
    #chomp $position;
  };
  push @all, [@cluster];
  $self->clusters(\@all);
  close $H;
  return $self;
};

sub rdf {
  my ($self) = @_;
  my @rdf = ();
  my $count = 0;
  my $rminsqr = $self->rmin*$self->rmin;
  my $rmaxsqr = $self->rmax*$self->rmax;
  $self->start_counter("Making RDF from each timestep", $#{$self->clusters}+1) if ($self->mo->ui eq 'screen');
  my ($x0, $x1, $x2) = (0,0,0);
  my @this;
  foreach my $step (@{$self->clusters}) {
    @this = @$step;
    $self->count if ($self->mo->ui eq 'screen');
    $self->timestep_count(++$count);
    $self->call_sentinal;
    foreach my $i (0 .. $#this) {
      ($x0, $x1, $x2) = @{$this[$i]};
      foreach my $j ($i+1 .. $#this) { # remember that all pairs are doubly degenerate
	my $rsqr = ($x0 - $this[$j]->[0])**2
	         + ($x1 - $this[$j]->[1])**2
	         + ($x2 - $this[$j]->[2])**2; # this loop has been optimized for speed, hence the weird syntax
	push @rdf, $rsqr if (($rsqr > $rminsqr) and ($rsqr < $rmaxsqr));
	#if (($i==1) and ($j==2)) {
	#  print join("|", @{$this[$i]}, @{$this[$j]}, $rsqr), $/;
	#};
      };
    };
  };
  if ($self->mo->ui eq 'screen') {
    $self->stop_counter;
    $self->start_spinner("Sorting RDF");
  };
  @rdf = sort { $a <=> $b } @rdf;
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  $self->ssrdf(\@rdf);
  $self->npairs(($#rdf+1)/$self->nsteps);
  return $self;
};

sub nearly_collinear {
  my ($self) = @_;
  my $count = 0;
  my $r1sqr = $self->r1**2;
  my $r2sqr = $self->r2**2;
  my $r3sqr = $self->r3**2;
  my $r4sqr = $self->r4**2;

  $self->start_counter(sprintf("Making radial/angle distribution from every %d-th timestep", $self->skip), ($#{$self->clusters}+1)/$self->skip) if ($self->mo->ui eq 'screen');
  my ($x0, $x1, $x2) = (0,0,0);
  #my ($ax, $ay, $az) = (0,0,0);
  my ($bx, $by, $bz) = (0,0,0);
  #my ($cx, $cy, $cz) = (0,0,0);
  my @rdf1  = ();
  my @rdf4  = ();
  my @three = ();
  my @this  = ();
  my $costh;
  my $i4;
  my $halfpath;
  my ($ct, $st, $cp, $sp, $ctp, $stp, $cpp, $spp, $cppp, $sppp, $beta, $leg2);
  #my $cosbetamax = cos($PI*$self->beta/180);
  foreach my $step (@{$self->clusters}) {
    @rdf1 = ();
    @rdf4 = ();

    @this = @$step;
    $self->timestep_count(++$count);
    next if ($count % $self->skip); # only process every Nth timestep
    $self->count if ($self->mo->ui eq 'screen');
    $self->call_sentinal;

    ## dig out the first and fourth coordination shells
    foreach my $i (0 .. $#this) {
      ($x0, $x1, $x2) = @{$this[$i]};
      foreach my $j (0 .. $#this) {
	next if ($i == $j);
	my $rsqr = ($x0 - $this[$j]->[0])**2
	         + ($x1 - $this[$j]->[1])**2
	         + ($x2 - $this[$j]->[2])**2; # this loop has been optimized for speed, hence the weird syntax
	push @rdf1, [sqrt($rsqr), $i, $j] if (($rsqr > $r1sqr) and ($rsqr < $r2sqr));
	push @rdf4, [sqrt($rsqr), $i, $j] if (($rsqr > $r3sqr) and ($rsqr < $r4sqr));
      };
    };

    ## find those 1st/4th pairs that share an absorber and have a small angle between them
    foreach my $fourth (@rdf4) {
      $i4 = $fourth->[1];
      foreach my $first (@rdf1) {
	next if ($i4 != $first->[1]);

	#($ax, $ay, $az) = ($this[ $i4          ]->[0], $this[ $i4          ]->[1], $this[ $i4          ]->[2]);
	($bx, $by, $bz) = ($this[ $first->[2]  ]->[0], $this[ $first->[2]  ]->[1], $this[ $first->[2]  ]->[2]);
	#($cx, $cy, $cz) = ($this[ $fourth->[2] ]->[0], $this[ $fourth->[2] ]->[1], $this[ $fourth->[2] ]->[2]);

	#my @vector = ( $cx-$bx, $cy-$by, $cz-$bz);
	($ct, $st, $cp, $sp)     = _trig( $this[ $fourth->[2] ]->[0]-$bx, $this[ $fourth->[2] ]->[1]-$by, $this[ $fourth->[2] ]->[2]-$bz );
	#@vector    = ( $bx-$ax, $by-$ay, $bz-$az);
	($ctp, $stp, $cpp, $spp) = _trig( $bx-$this[ $i4 ]->[0], $by-$this[ $i4 ]->[1], $bz-$this[ $i4 ]->[2]);

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
	next if ($beta > $self->beta);

	$leg2 = sqrt( ($bx - $this[ $fourth->[2] ]->[0])**2 +
		      ($by - $this[ $fourth->[2] ]->[1])**2 +
		      ($bz - $this[ $fourth->[2] ]->[2])**2 );
	$halfpath = $leg2 + $first->[0]; # + $fourth->[0]) / 2;
	push @three, [$halfpath, $first->[0], $leg2, $fourth->[0], $beta];

	#($a0, $a1, $a2) = ($this[ $i4 ]->[0], $this[ $i4 ]->[1], $this[ $i4 ]->[2]);
	#$costh =
 	#  (($this[ $first->[2] ]->[0] - $a0) * ($this[ $fourth->[2] ]->[0] - $a0) +
	#   ($this[ $first->[2] ]->[1] - $a1) * ($this[ $fourth->[2] ]->[1] - $a1) +
	#   ($this[ $first->[2] ]->[2] - $a2) * ($this[ $fourth->[2] ]->[2] - $a2))  / ($fourth->[0] * $first->[0]);
	#next if ($costh < $cosbetamax);
	#$halfpath = sqrt(($first->[0]*sin(acos($costh)))**2 + ($fourth->[0]-$first->[0]*$costh)**2);
	#push @three, [$halfpath, $first->[0], $fourth->[0], acos($costh)*180/$PI];
      };
    };
  };
  if ($self->mo->ui eq 'screen') {
    $self->stop_counter;
    $self->start_spinner("Sorting path length/angle distribution by path length");
  };
  @three = sort { $a->[0] <=> $b->[0] } @three;
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  $self->nconfig( $#three+1 );
  #$self->nconfig( int( ($#three+1) / (($#{$self->clusters}+1) / $self->skip) + 0.5 ) );
  #print "||||||| ", $self->nconfig, $/;
  $self->nearcl(\@three);
};

sub _trig {
  my $rxysqr = $_[0]*$_[0] + $_[1]*$_[1];
  my $r   = sqrt($rxysqr + $_[2]*$_[2]);
  my $rxy = sqrt($rxysqr);
  my ($ct, $st, $cp, $sp) = (1, 0, 1, 0);

  ($ct, $st) = ($_[2]/$r,   $rxy/$r)    if ($r   > $TRIGEPS);
  ($cp, $sp) = ($_[0]/$rxy, $_[1]/$rxy) if ($rxy > $TRIGEPS);

  return ($ct, $st, $cp, $sp);
};

sub _bin {
  my ($self) = @_;
  my (@x, @y);
  my $bin_start = sqrt($self->ssrdf->[0]);
  my ($population, $average) = (0,0);
  $self->start_spinner(sprintf("Rebinning RDF into %.4f A bins", $self->bin)) if ($self->mo->ui eq 'screen');
  foreach my $pair (@{$self->ssrdf}) {
    my $rr = sqrt($pair);
    if (($rr - $bin_start) > $self->bin) {
      $average = $average/$population;
      push @x, sprintf("%.5f", $average);
      push @y, $population*2;
      #print join(" ", sprintf("%.5f", $average), $population*2), $/;
      $bin_start += $self->bin;
      $average = $rr;
      $population = 1;
    } else {
      $average += $rr;
      ++$population;
    };
  };
  push @x, sprintf("%.5f", $average);
  push @y, $population*2;
  $self->positions(\@x);
  $self->populations(\@y);
  $self->update_bins(0);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};

sub _bin2d {
  my ($self) = @_;

  $self->start_spinner(sprintf("Rebinning three-body configurations into %.3f A x %.2f deg bins", $self->rbin, $self->betabin)) if ($self->mo->ui eq 'screen');

  ## slice the configurations in R
  my @slices = ();
  my @this   = ();
  my $r_start = $self->nearcl->[0]->[0];
  my $aa = 0;
  foreach my $tb (@{$self->nearcl}) {
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

  ## compute the population and average distance and angle of each pixel
  my @binned_plane = ();
  my ($r, $b, $l1, $l2, $count, $total) = (0, 0, 0, 0);
  my $cc = 0;
  foreach my $pix (@plane) {
    next if ($#{$pix} == -1);
    ($r, $b, $l1, $l2, $count) = (0, 0, 0);
    foreach my $tb (@{$pix}) {
      $r  += $tb->[0];
      $l1 += $tb->[1];
      $l2 += $tb->[2];
      $b  += $tb->[4];
      ++$count;
      ++$total;
    };
    $cc += $count;
    push @binned_plane, [$r/$count, $b/$count, $l1/$count, $l2/$count, $count];
  };
  $self->populations(\@binned_plane);
  $self->nbins($#binned_plane+1);
  $self->update_bins(0);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  #printf "number of pixels: unbinned = %d    binned = %d\n", $#plane+1, $#binned_plane+1;
  #printf "stripe pass = %d   pixel pass = %d    last pass = %d\n", $aa, $bb, $cc;
  #printf "binned = %d  unbinned = %d\n", $total, $#{$self->nearcl}+1;
  return $self;
};

sub plot {
  my ($self) = @_;
  Ifeffit::put_array(join(".", $self->group, 'x'), $self->positions);
  Ifeffit::put_array(join(".", $self->group, 'y'), $self->populations);
  $self->po->start_plot;
  $self->dispose($self->template('plot', 'histo'), 'plotting');
  return $self;
};

sub histogram {
  my ($self) = @_;
  return if not $self->feff;
  my $histo = $self -> feff -> make_histogram($self->positions, $self->populations, $self->ipot, q{}, q{});
  $self->nbins($#{$histo}+1);
  return $histo;
};

sub fpath {
  my ($self) = @_;
  my $composite;
  my $index = $self->mo->pathindex;
  if ($self->ss) {
    my $histo = $self->histogram;
    $composite = $self -> feff -> chi_from_histogram($histo);
    my $text = sprintf("\n\ntaken from %d samples between %.3f and %.3f A\nbinned into %.4f A bins",
		       $self->get(qw{npairs rmin rmax bin}));
    $text .= "\n\nThe structural contributions to the first four cumulants are \n";
    $text .= sprintf "       first  = %9.6f\n",   $composite->c1;
    $text .= sprintf "       sigsqr = %9.6f\n",   $composite->c2;
    $text .= sprintf "       third  = %9.6f\n",   $composite->c3;
    $text .= sprintf "       fourth = %9.6f",     $composite->c4;
    $composite->pdtext($text);
  } elsif ($self->ncl) {
    $composite = $self->chi_nearly_colinear;
    my $text = sprintf("\n\nthree body configurations with the near atom between %.3f and %.3f A\nthe distant atom between %.3f and %.3f A\nbinned into %.4f A x %.4f deg bins",
		       $self->get(qw{r1 r2 r3 r4 rbin betabin}));
    $composite->pdtext($text);
  };
  $composite->Index($index);
  $self->mo->pathindex($index+1);
  return $composite;
};


sub chi_nearly_colinear {
  my ($self, $paths, $common) = @_;
  $self->start_counter("Making FPath from radial/angle distribution", $#{$self->populations}+1) if ($self->mo->ui eq 'screen');
  #$self->start_spinner("Making FPath from path length/angle distribution") if ($self->mo->ui eq 'screen');

  my @paths = ();
  foreach my $c (@{$self->populations}) {
    push @paths, Demeter::ThreeBody->new(r1    => $c->[2],      r2    => $c->[3],
					 ipot1 => $self->ipot1, ipot2 => $self->ipot2,
					 beta  => $c->[1],      s02   => $c->[4]/$self->nconfig,
					 parent=> $self->feff,
					 update_path => 1,
					 @$common);
  };

  my $index = $self->mo->pathindex;

  my $first = $paths[0];
  $first->_update('fft');
  my $save = $first->group;

  $self->count if ($self->mo->ui eq 'screen');
  $first->dspath->Index(255);
  $first->dspath->group("h_i_s_t_o"); # add up the SSPaths without requiring an Ifeffit group for each one
  $first->dspath->path(1);
  $first->dspath->dispose($first->dspath->template('process', 'histogram_first'));
  $first->dspath->group($save);
  $first->dspath->dispose($first->dspath->template('process', 'histogram_clean', {index=>255}));

  $first->tspath->Index(255);
  $first->tspath->group("h_i_s_t_o");
  $first->tspath->path(1);
  $first->tspath->dispose($first->tspath->template('process', 'histogram_add'));
  $first->tspath->group($save);
  $first->tspath->dispose($first->tspath->template('process', 'histogram_clean', {index=>255}));

  my $ravg = $first->s02 * ($first->r1+$first->r2);
  my $n    = $first->s02;
  foreach my $i (1 .. $#paths) {
    $self->call_sentinal;
    $paths[$i]->_update('fft');
    my $save = $paths[$i]->group;

    $self->count if ($self->mo->ui eq 'screen');
    $paths[$i]->dspath->Index(255);
    $paths[$i]->dspath->group("h_i_s_t_o");
    $paths[$i]->dspath->path(1);
    $paths[$i]->dispose($paths[$i]->dspath->template('process', 'histogram_add'));
    $paths[$i]->dspath->group($save);
    $paths[$i]->dispose($paths[$i]->dspath->template('process', 'histogram_clean', {index=>255}));

    $paths[$i]->tspath->Index(255);
    $paths[$i]->tspath->group("h_i_s_t_o");
    $paths[$i]->tspath->path(1);
    $paths[$i]->dispose($paths[$i]->tspath->template('process', 'histogram_add'));
    $paths[$i]->tspath->group($save);
    $paths[$i]->dispose($paths[$i]->tspath->template('process', 'histogram_clean', {index=>255}));

    $ravg += $paths[$i]->s02 * ($paths[$i]->r1+$paths[$i]->r2);
    $n += $paths[$i]->s02;
  }
  $self->mo->pathindex($index);
  my @k    = Ifeffit::get_array('h___isto.k');
  my @chi  = Ifeffit::get_array('h___isto.chi');
  my $data = Demeter::Data  -> put(\@k, \@chi, datatype=>'chi', name=>'sum of histogram',
				   fft_kmin=>0, fft_kmax=>20, bft_rmin=>0, bft_rmax=>31);
  my $path = Demeter::FPath -> new(absorber  => $self->feff->abs_species,
				   scatterer => $self->feff->potentials->[$paths[0]->ipot2]->[2],
				   reff      => $ravg,
				   source    => $data,
				   n         => 1,
				   degen     => 1,
				   @$common
				  );
  my $name = sprintf("Histo 3-Body %s-%s-%s (%.5f)",
		     $self->feff->potentials->[0]->[2],
		     $self->feff->potentials->[$self->ipot1]->[2],
		     $self->feff->potentials->[$self->ipot2]->[2],
		     $path->reff);
  $path->name($name);
  $self->stop_counter if ($self->mo->ui eq 'screen');
  return $path;
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Feff::DL_POLY - Support for DL_POLY HISTORY file

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

=head1 DESCRIPTION

This provides support for importing data from the DL_POLY HISTORY
file, which is a format for providing the trajectory of a cluster
during a molecular dynamics simulation.  The DL_POLY website is
L<http://www.cse.scitech.ac.uk/ccg/software/DL_POLY/> and a
description of the HISTORY format is in section 5.2.1 of the User
Guide, a link to which can be found at the DL_POLY website.

The main purpose of this module is to extract the coordinates for a
given timestep from the history file and use those coordinates to
construct a histogram representation of that cluster for use in a fit
to EXAFS data using Demeter.

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

=item C<rmin> and C<rmax> (numbers)

The lower and upper bounds of the radial distribution function to
extract from the cluster.  These are set to values that include a
single coordination shell when constructing input for an EXAFS fit.
However, for constructing a plot of the RDF, it may be helpful to set
these to cover a larger range of distances.

=item C<bin> (number)

The width of the histogram bin to be extracted from the RDF.

=item C<sp> (number)

This is set to the L<Demeter::ScatteringPath> object used to construct
the bins of the histogram.  A good choice would be the similar path
from a Feff calculation on the bulk, crystalline analog to your
cluster.

=back

=head1 METHODS

=over 4

=item C<fpath>

Return a L<Demeter::FPath> object representing the sum of the bins of
the histogram extracted from the cluster.

=item C<histogram>

Return a reference to an array of L<Demeter::SSPath> objects
representing the bins of the histogram extracted from the cluster.

=item C<plot>

Make a plot of the the RDF.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.
Many attributes of a Data object can be configured via the
configuration system.  See, among others, the C<bkg>, C<fft>, C<bft>,
and C<fit> configuration groups.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 SERIALIZATION AND DESERIALIZATION

An XES object and be frozen to and thawed from a YAML file in the same
manner as a Data object.  The attributes and data arrays are read to
and from YAMLs with a single object perl YAML.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This currently only works for a monoatomic cluster.

=item *

Feff interaction is a bit unclear

=item *

Triangles and nearly colinear paths

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
