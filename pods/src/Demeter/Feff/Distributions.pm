package Demeter::Feff::Distributions;

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
use Moose::Util qw(apply_all_roles);
use Moose::Util::TypeConstraints;
#use MooseX::StrictConstructor;
extends 'Demeter';
with "Demeter::Feff::MD::Null";

use Demeter::StrTypes qw( Empty );
use Demeter::NumTypes qw( Natural PosInt NonNeg Ipot );

use Readonly;
Readonly my $PI => 4*atan2(1,1);
Readonly my $TRIGEPS => 1e-6;

with 'Demeter::Data::Arrays';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};
with 'Demeter::Feff::Distributions::SS';

use List::Util qw{sum};

has '+plottable' => (default => 1);

## HISTORY file attributes
has 'nsteps'    => (is => 'rw', isa => NonNeg, default => 0);
has 'nbins'     => (is => 'rw', isa => NonNeg, default => 0);
has 'file'      => (is => 'rw', isa => 'Str', default => q{},
		    trigger => sub{ my($self, $new) = @_;
				    if ($new) {
				      $self->_cluster;
				      $self->rdf;
				    };
				  });
has 'clusters'    => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

enum 'HistogramBackends' => ['dl_poly', 'something_else'];
coerce 'HistogramBackends',
  from 'Str',
  via { lc($_) };
has backend       => (is => 'rw', isa => 'HistogramBackends', coerce => 1, alias => 'md',
		      trigger => sub{my ($self, $new) = @_;
				     if ($new eq 'dl_poly') {
				       eval {apply_all_roles($self, 'Demeter::Feff::MD::DL_POLY')};
				       $@ and die("Histogram backend Demeter::Feff::MD::DL_POLY could not be loaded");
				     } else {
				       eval {apply_all_roles($self, 'Demeter::Feff::MD::'.$new)};
				       $@ and die("Histogram backend Demeter::Feff::MD::$new does not exist");
				     };
				   });

enum 'HistogramTypes' => ['ss', 'ncl', 'thru'];
coerce 'HistogramTypes',
  from 'Str',
  via { lc($_) };
has 'type'  => (is => 'rw', isa => 'HistogramTypes', coerce => 1, default => 'ss',
		trigger => sub{my ($self, $new) = @_;
			       if ($new eq 'ss') {
				 eval {apply_all_roles($self, 'Demeter::Feff::Distributions::SS')};
				 $@ and die("Histogram configuration Demeter::Feff::Distributions::SS could not be loaded");
			       } elsif ($new eq 'ncl') {
				 eval {apply_all_roles($self, 'Demeter::Feff::Distributions::NCL')};
				 $@ and die("Histogram configuration Demeter::Feff::Distributions::NCL could not be loaded");
			       } elsif ($new eq 'thru') {
				 eval {apply_all_roles($self, 'Demeter::Feff::Distributions::Thru')};
				 $@ and die("Histogram configuration Demeter::Feff::Distributions::Thru could not be loaded");
			       } else {
				 eval {apply_all_roles($self, 'Demeter::Feff::Distributions::'.$new)};
				 $@ and die("Histogram configuration Demeter::Feff::Distributions::$new does not exist");
			       };
			     });

#has 'bin_count'   => (is => 'rw', isa => 'Int',  default => 0);
has 'timestep_count' => (is => 'rw', isa => 'Int',  default => 0);
has 'feff'           => (is => 'rw', isa => Empty.'|Demeter::Feff', default => q{},);
has 'sp'             => (is => 'rw', isa => Empty.'|Demeter::ScatteringPath', default => q{},);


has 'update_bins' => (is            => 'rw',
		      isa           => 'Bool',
		      default       => 1);
has 'populations' => (is	    => 'rw',
		      isa	    => 'ArrayRef',
		      default	    => sub{[]},
		      documentation => "array of bin populations of the extracted histogram");



## need a pgplot plotting template

sub rebin {
  my($self, $new) = @_;
  $self->_bin if ($self->update_bins);
  return $self;
};


sub _trig {
  shift;
  my $rxysqr = $_[0]*$_[0] + $_[1]*$_[1];
  my $r   = sqrt($rxysqr + $_[2]*$_[2]);
  my $rxy = sqrt($rxysqr);
  my ($ct, $st, $cp, $sp) = (1, 0, 1, 0);

  ($ct, $st) = ($_[2]/$r,   $rxy/$r)    if ($r   > $TRIGEPS);
  ($cp, $sp) = ($_[0]/$rxy, $_[1]/$rxy) if ($rxy > $TRIGEPS);

  return ($ct, $st, $cp, $sp);
};

sub fpath {
  my ($self) = @_;
  my $composite;
  my $index = $self->mo->pathindex;
  $composite = $self -> chi;	# make FPath from list of path-like objects
  $self->describe($composite);	# text describing distribution
  $composite->Index($index);
  $self->mo->pathindex($index+1);
  return $composite;
};



no Moose::Util::TypeConstraints;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Feff::Distributions:: - Make historams from arbitrary clusters of atoms

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

=head1 DESCRIPTION

This provides support for importing data from clusters computed by
molecular dynamics and making histograms for different types of paths.

This takes methods for parsing files of atomic configurations from its
roles:

  Demeter::Feff::MD::Null
  Demeter::Feff::MD::DL_POLY

This takes methods for making distributions functions and chi(k) (in
the form of a L<Demeter::FPath> object from its roles:

  Demeter::Feff::Distributions::SS
  Demeter::Feff::Distributions::NCL

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
