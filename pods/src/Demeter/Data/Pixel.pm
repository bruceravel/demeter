package Demeter::Data::Pixel;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

use Carp;
use autodie qw(open close);

use Moose;
extends 'Demeter::Data';
use MooseX::Aliases;
use Demeter::StrTypes qw( Empty );
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

use List::MoreUtils qw(minmax);

#has '+name' => (default => 'pixel data',);
has '+datatype' => (default => 'xmu',);
has '+is_special' => (default => 1,);

has 'standard' => (is => 'rw', isa => Empty.'|Demeter::Data',  default => q{},
		   trigger => sub{ my($self, $new) = @_;
				   if ($new) {
				     $self->standardgroup($new->group);
				     $self->_update('background');
				     $new ->_update('background');
				     #$self->offset($new->bkg_e0 - $self->linear*$self->bkg_e0);
				   }
				 });
has 'standardgroup' => (is => 'rw', isa => 'Str',  default => q{});

has 'offset'    => (is => 'rw', isa => 'Num',  default => 0);
has 'linear'    => (is => 'rw', isa => 'Num',  default => 0.4);
has 'quadratic' => (is => 'rw', isa => 'Num',  default => sub{ shift->co->default("dispersive", "quadratic")  || 0});

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Pixel($self);
};


after read_data => sub {
  my ($self) = @_;
  $self->name($self->name . ' (pixel)') if ($self->name !~ m{\(pixel\)\z});
  $self->source($self->name);
  return $self;
};

sub _sanity {
  my ($self) = @_;
  if (ref($self->standard) !~ m{Data}) {
    croak("** Data::Pixel: You have not set the standard for fitting your calibration parameters");
  };
  return $self;
};


sub guess {
  my ($self, $quiet) = @_;

  $self->start_spinner("Demeter is setting initial DXAS calibration parameters") if (($self->mo->ui eq 'screen') and (not $quiet));
  $self->standard->bkg_e0_fraction(0.1);
  my $st1 = $self->standard->e0('fraction');
  $self->standard->bkg_e0_fraction(0.9);
  my $st9 = $self->standard->e0('fraction');
  $self->standard->e0('ifeffit');

  $self->bkg_e0_fraction(0.1);
  my $da1 = $self->e0('fraction');
  $self->bkg_e0_fraction(0.9);
  my $da9 = $self->e0('fraction');
  $self->e0('ifeffit');

  #print "\n$st1  $st9 \n";
  #print "\n$da1  $da9 \n";
  #printf "%.9f\n", ($st9-$st1)/($da9-$da1);
  #printf "%.9f\n",  $st1 - (($st9-$st1)/($da9-$da1)) * $da1;

  $self->linear(($st9-$st1)/($da9-$da1));
  $self->offset($st1 - ($self->linear * $da1));

  $self->stop_spinner if (($self->mo->ui eq 'screen') and (not $quiet));
  return $self;
};

sub pixel {
  my ($self, $quiet) = @_;
  $self->_sanity;
  $self->start_spinner("Demeter is determining DXAS calibration parameters") if (($self->mo->ui eq 'screen') and (not $quiet));

  $self->_update('fft');
  $self->standard->_update('fft');

  $self->dispense('process', 'pixel_setup');
  $self->dispense('process', 'pixel_fit');

  $self->offset($self->fetch_scalar("pixel___a"));
  $self->linear($self->fetch_scalar("pixel___b"));
  $self->quadratic($self->fetch_scalar("pixel___c"));
  #print $self->fetch_scalar('pixel___xmin'), " ",$self->fetch_scalar('pixel___xmax'), $/;
  #print $self->linear, "  ", $self->offset, "  ", $self->quadratic, $/;
  $self->stop_spinner if (($self->mo->ui eq 'screen') and (not $quiet));
  return $self;
};


sub apply {
  my ($self, $convert) = @_;
  $convert ||= $self;
  $convert -> _update('data');
  $convert -> set(offset=>$self->offset, linear=>$self->linear, quadratic=>$self->quadratic);
  my $new  = Demeter::Data->new(name=>$convert->name);
  $new     -> source('DXAS: '.$convert->file);
  $new     -> mo -> standard($convert);
  $new     -> dispense('process', 'pixel_set');
  $new     -> set(update_data=>0, update_columns=>0, update_norm=>1, datatype=>'xmu');
  $new     -> e0;
  $new     -> resolve_defaults;
  $new     -> unset_standard;
  return $new;
};

sub report {
  my ($self) = @_;
  return sprintf("offset = %.3f, linear = %.3f, quadratic = %.3g\n", $self->get(qw(offset linear quadratic)))
};

1;


=head1 NAME

Demeter::Data::Pixel - Handle dispersive XAS data

=head1 VERSION

This documentation refers to Demeter version 0.9.11.

=head1 SYNOPSIS

   use Demeter;

   my $stan = Demeter::Data->new(file=>'ESRF_ID24/cus2/cufoil_rt.txt', bkg_nor2=>1000);
   $stan->set_mode(screen=>0);

   my $data = Demeter::Data::Pixel->new(file=>'ESRF_ID24/cus2/cu_08', bkg_nor2=>1000);

   $data->standard($stan);
   $data->guess;
   $data->pixel;

   my $cus2 = Demeter::Data::Pixel->new(file=>$file, name=>basename($file));
   $dispersive_data = $data->apply($cus2);

=head1 DESCRIPTION

The standard way of implementing a dispersive XAS measurement is to
measure a known sample such as a foil in the same dispersive geometry
as the real experiment.  The function for converting from pixel
position to energy is determined by comparing the dispersively
measured sample to a conventionally measurement on the same sample.
This determines as set of conversion parameters that can then be used
on each scan in  the subsequent measurement.

In the synopsis above, the conventional scan on a Cu foil is imported
as a normal Data object.  The foil measured dispersively is then
imported as a Data::Pixel object.  The conventional scan is
established as the standard and the conversion parameters are
determined by fitting a quadratic function relating pixels to energy.

  energy = A + B*pixel + C*pixel^2

In fact, a slightly more complex function is used as the fitting
function in an attempt to to give some weight to the high energy data
where the variations in the data and thus the sensitivity to the fit
is somewhat less than near the edge where the data is changing quickly.

Once the parameters for the conversion are known, they can be applied
to the real data.  Each dispersive scan is imported as a Data::Pixel
object and a normal Data object is generated from that.

=head1 ATTRIBUTES

This is inherited from the Data object, so all of the Data attributes
are inherited.  Additionally, there are these attributes:

=over 4

=item C<standard>

This takes the refernece to the Data object containing the
conventionally measured standard.

=item C<offset>

The value of the offset conversion parameter, C<A> in the formula above.

=item C<linear>

The value of the linear conversion parameter, C<B> in the formula above.

=item C<quadratic>

The value of the quadratic conversion parameter, C<C> in the formula above.

=back

=head1 METHODS

=over 4

=item C<guess>

Make an initial guesss for the conversion parameters.  This is done by
finding e0 values for the conventional and dispersive standard data
(normally a foil or some such) using the fraction-of-an-edge step
method described in L<Demeter::Data::E0>.  The e0 position is found
for fractions of 0.1 and 0.9 in each measurement and offset and linear
terms are determined from those values.  The initial quadratic value
is 0.  This fills the C<offset>, C<linear>, and C<quadratic>
attributes.

=item C<pixel>

Perform the fit between the flattened, normalized conventionald and
dispersive standards to determine values for the conversion
parameters.  This fills the C<offset>, C<linear>, and C<quadratic>
attributes.

=item C<apply>

This method applies the C<offset>, C<linear>, and C<quadratic>
attributes to convert a pixel data groups, returning a normal Data
object.

=item C<report>

This generates a bit of text documenting the values of the conversion
parameters.

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the lcf configuration group for the relevant parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

The fitting algorithm is not so robust.

=back

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
