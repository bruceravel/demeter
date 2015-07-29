package Demeter::FPath;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

use Moose;
extends 'Demeter::Path';
use Moose::Util::TypeConstraints;
use Demeter::NumTypes qw( Ipot PosNum PosInt Natural );
use Demeter::StrTypes qw( Empty ElementSymbol );

with 'Demeter::Data::Arrays';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

use Chemistry::Elements qw(get_symbol get_Z);

has 'reff'	 => (is => 'rw', isa => 'LaxNum', default => 0.1,
		     trigger  => sub{ my ($self, $new) = @_; $self->fuzzy($new);} );
has 'fuzzy'	 => (is => 'rw', isa => 'LaxNum', default => 0.1);
has '+data'      => (isa => Empty.'|Demeter::Data');
has '+n'	 => (default => 1);
has 'source'     => (is => 'rw', isa => Empty.'|Demeter::Data', default => q{},
		     trigger => sub{ my($self, $new) = @_; $self->set_sourcegroup($new->group) if $new});
has 'sourcegroup'=> (is => 'rw', isa => 'Str',    default => q{});
has 'weight'	 => (is => 'ro', isa => 'Int',    default => 2);
has 'Type'	 => (is => 'rw', isa => 'Str',    default => 'filtered scattering path');
has 'pdtext'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'string'	 => (is => 'ro', isa => 'Str',    default => q{});
has 'tag'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'randstring' => (is => 'rw', isa => 'Str',    default => sub{Demeter->randomstring(8).'.sp'});

has 'kgrid'      => (is => 'ro', isa => 'ArrayRef',
		     default => sub{
		       [ 0.000,  0.100,  0.200,  0.300,  0.400,  0.500,  0.600,  0.700, 0.800, 0.900,
			 1.000,  1.100,  1.200,  1.300,  1.400,  1.500,  1.600,  1.700, 1.800,
			 1.900,  2.000,  2.200,  2.400,  2.600,  2.800,  3.000,  3.200, 3.400,
			 3.600,  3.800,  4.000,  4.200,  4.400,  4.600,  4.800,  5.000, 5.200,
			 5.400,  5.600,  5.800,  6.000,  6.500,  7.000,  7.500,  8.000, 8.500,
			 9.000,  9.500, 10.000, 11.000, 12.000, 13.000, 14.000, 15.000,
			16.000, 17.000, 18.000, 19.000, 20.000 ]
		     });

enum 'AllElements' => [map {ucfirst $_} @Demeter::StrTypes::element_list];
coerce 'AllElements',
  from 'Str',
  via { get_symbol($_) };
has 'absorber'	   => (is => 'rw', isa => 'AllElements',
		       coerce => 1, default => q{Fe},
		       trigger => sub{ my ($self, $new) = @_;
				       $self->abs_z(get_Z($new));
				     });
has 'scatterer'   => (is => 'rw', isa => 'AllElements',
		      coerce => 1, default => q{O},
		      trigger => sub{ my ($self, $new) = @_;
				      $self->scat_z(get_Z($new));
				    });
has 'abs_z'	 => (is => 'rw', isa => 'Int',    default => 0);
has 'scat_z'	 => (is => 'rw', isa => 'Int',    default => 0);

has 'nofilter'	 => (is => 'rw', isa => 'Bool',   default =>  0);
has 'kmin'	 => (is => 'rw', isa => 'LaxNum', default =>  0.0);
has 'kmax'	 => (is => 'rw', isa => 'LaxNum', default => 20.0);
has 'rmin'	 => (is => 'rw', isa => 'LaxNum', default =>  0.0);
has 'rmax'	 => (is => 'rw', isa => 'LaxNum', default => 31.0);

has 'nnnntext'   => (is => 'rw', isa => 'Str',    default => q{});
has 'workspace'  => (is => 'rw', isa => 'Str',    default => q{}); # valid directory


has 'pathfinder_index'=> (is=>'rw', isa=>  Natural, default => 9999);

## the sp attribute must be set to this FPath object so that the Path
## _update_from_ScatteringPath method can be used to generate the
## feffNNNN.dat file.  an ugly but functional bit of voodoo
sub BUILD {
  my ($self, @params) = @_;
  $self->parent($self->fd);
  $self->parent->workspace($self->stash_folder);
  $self->sp($self);
  $self->mo->push_FPath($self);
  $self->put_array('grid', $self->kgrid);
};

override alldone => sub {
  my ($self) = @_;
  my $nnnn = File::Spec->catfile($self->stash_folder, $self->randstring);
  unlink $nnnn if (-e $nnnn);
  $self->remove;
  return $self;
};

override make_name => sub {
  my ($self) = @_;
  $self->name(sprintf("Filtered %s-%s (%.5f)", $self->absorber, $self->scatterer, $self->reff));
};

override set_parent_method => sub {
  1;
  #my ($self, $feff) = @_;
  #$feff ||= $self->parent;
  #return if not $feff;
  #$self->parentgroup($feff->group);
};


sub set_sourcegroup {
  my ($self, $gp) = @_;
  $self->sourcegroup($gp);
  if ($self->source->name ne 'default___') {
    $self->kmin($self->source->fft_kmin);
    $self->kmax($self->source->fft_kmax);
    $self->rmin($self->source->bft_rmin);
    $self->rmax($self->source->bft_rmax);
  };
};

sub intrplist {
  q{};
};

sub labelline {
  my ($self) = @_;
  return sprintf("Reff=%6.3f  nleg=%d   degen=%2d", $self->fuzzy, 2, 1);
};

sub _filter {
  my ($self) = @_;
  $self->source->_update('fft');
  $self->dispense('process', 'filtered_filter');
  return $self;
};

sub _nnnn {
  my ($self) = @_;
  my $text = $self->template('process', 'filtered_head');
  my @k   = @{$self->kgrid};
  my @mag = $self->get_array('filtered');
  $mag[0] = 0;
  my @pha = $self->get_array('phase');
  foreach my $i (0 .. $#k) {
    $text .= sprintf "%7.3f %11.4e %11.4e %11.4e %10.3e %11.4e %11.4e\n", $k[$i], 0.0, $mag[$i], $pha[$i], 1.0, 1e8, $k[$i];
  };
  return $text;
};

sub _nnnnfile {
  my ($self, $text) = @_;
  $text ||= $self->_nnnn;
  open(my $NNNN, '>', File::Spec->catfile($self->stash_folder, $self->randstring));
  print $NNNN $text;
  close $NNNN;
};

before _update_from_ScatteringPath => sub {
  my ($self) = @_;
  $self->_filter if not $self->nnnntext;
  $self->_nnnnfile($self->nnnntext);
};

override path => sub {
  my ($self) = @_;
  $self->_update_from_ScatteringPath;
  $self->label(sprintf("%s-%s path at %s", $self->absorber, $self->scatterer, $self->reff));
  $self->dispose($self->_path_command(1));
  $self->update_path(0);
  return $self;
};

sub pathsdat {
  my ($self) = @_;
  return $self->pdtext;
};


override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  delete $all{$_} foreach (qw(data source weight string kgrid sentinal));
  return %all;
};

before serialization => sub {
  my ($self) = @_;
  return if $self->nnnntext;
  $self->_update('path');
  #$self->_filter;
  $self->nnnntext($self->_nnnn);
};


## need to check that fname is really an fpath yaml, return 0 if not
override deserialize => sub {
  my ($self, $fname) = @_;
  my $r_args;
  eval {local $SIG{__DIE__} = undef; $r_args = YAML::Tiny::LoadFile($fname)};
  return 0 if $@;
  my @args = %$r_args;
  $self->set(@args);
  my $source = $self->mo->fetch('Data', $self->sourcegroup);
  $self->source($source);
  my $data = $self->mo->fetch('Data', $self->datagroup);
  $self->data($data);
  $self->update_path(1);
  return $self;
};

1;


=head1 NAME

Demeter::FPath - Filtered paths

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 SYNOPSIS

Build a single scattering path by Fourier filtering  chi(k) data:

  my $fpath = Demeter::FPath->new(source    => $data_object,
                                  name      => "my filtered path",
                                  absorber  => 'Cu',
                                  scatterer => 'O',
                                  reff      => 2.1,
                                  n         => 6,
                                 );
  $fpath -> plot('R');

=head1 DESCRIPTION

This object handles the creation of a path filtered from chi(k) data.
This could be used to create an empirical standard that can be used in
Artemis in the same way as any other Path or Path-like object.  It
could also be used to create a single path-like object from some kind
of theoretical model -- for instance, a histogram created from a
molecular dynamics simulation.

The difference between a Path and FPath is the provenance of the path.
For a Path object, you  must specify either a ScatteringPath object as
the  C<sp>  attribute  or  you  must set  the  C<folder>  and  C<file>
attributes to point at the location of a F<feffNNNN.dat> file.

For an FPath object, you set none of those attributes yourself (they
all get set, but not by you).  Instead, you specify the C<source> from
which the filterted path will be extracted, the C<absorber>,
C<scatterer>, C<reff>, and C<n> attributes, which describe the basic
features of the path being generated.  Demeter will then generate a
single scattering path from the Data object at the approximate
distance in the data. The resulting path will have a natural
degeneracy of 1, which can, of course, be overriden by the C<n>
attribute.

FPath objects are plotted just like any Path object, as shown in the
synopsis above.  They are used in fits in the same way as ordinary
Path objects.  That is, the C<paths> attribute of the Fit object takes
a reference to a list of Path and/or FPath (or other path-like)
objects.

=head1 ATTRIBUTES

As with any Moose object, the attribute names are the name of the
accessor methods.

This extends L<Demeter::Path>.  Along with the standard attributes of
any Demeter object (C<name>, C<plottable>, C<source>, and so on), and of
the Path object, an SSPath has the following:

=over 4

=item C<source>

This takes the reference to the Data object from which the path will
be extracted.

=item C<absorber>

The atomic species of the absorbing atom.  This can be the name
(e.g. copper), the symbol (e.g. Cu), or Z number (e.g. 29).

=item C<scatterer>

The atomic species of the scattering atom.  This can be the name
(e.g. oxygen), the symbol (e.g. O), or Z number (e.g. 8).

=item C<reff>

The approximate path length of the shell being filtered from the data.

=back

=head1 METHODS

There are no outward-looking methods for the FPath object beyond those
inherited from the Path object.  All methods in this module are used
behind the scenes and need never be called by the user.

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Sanity checking, for instance that the data is set before anything is
done, that reff is sensible

=item *

Serialization by itself and in a fit.

=back

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

