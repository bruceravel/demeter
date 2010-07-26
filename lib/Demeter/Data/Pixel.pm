package Demeter::Data::Pixel;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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
use MooseX::AttributeHelpers;
use MooseX::Aliases;
use Demeter::StrTypes qw( Empty );
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

has '+name' => (default => 'pixel data',);
has '+datatype' => (default => 'xmu',);
has '+is_special' => (default => 1,);

has 'standard' => (is => 'rw', isa => Empty.'|Demeter::Data',  default => q{},
		   trigger => sub{ my($self, $new) = @_;
				   if ($new) {
				     $self->standardgroup($new->group);
				     $self->_update('background');
				     $new ->_update('background');
				     $self->offset($new->bkg_e0 - $self->linear*$self->bkg_e0);
				   }
				 });
has 'standardgroup' => (is => 'rw', isa => 'Str',  default => q{});

has 'offset'    => (is => 'rw', isa => 'Num',  default => 0);
has 'linear'    => (is => 'rw', isa => 'Num',  default => 0.4);
has 'quadratic' => (is => 'rw', isa => 'Num',  default => 0);

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Pixel($self);
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

  $self->dispose($self->template('process', 'pixel_setup'));
  $self->dispose($self->template('process', 'pixel_fit'));

  $self->offset(Ifeffit::get_scalar("pixel___a"));
  $self->linear(Ifeffit::get_scalar("pixel___b"));
  $self->quadratic(Ifeffit::get_scalar("pixel___c"));
  #print Ifeffit::get_scalar('pixel___xmin'), " ",Ifeffit::get_scalar('pixel___xmax'), $/;
  #print $self->linear, "  ", $self->offset, "  ", $self->quadratic, $/;
  $self->stop_spinner if (($self->mo->ui eq 'screen') and (not $quiet));
  return $self;
};


sub apply {
  my ($self, $convert) = @_;
  $convert ||= $self;
  $convert -> _update('data');
  $convert -> set(offset=>$self->offset, linear=>$self->linear, quadratic=>$self->quadratic);
  my $new = Demeter::Data->new(name=>$convert->name);
  $new    -> mo -> standard($convert);
  $new    -> dispose($new->template('process', 'pixel_set'));
  $new    -> set(update_data=>0, update_columns=>0, update_norm=>1, datatype=>'xmu');
  $new    -> e0;
  $new    -> resolve_defaults;
  $new    -> unset_standard;
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

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the lcf configuration group for the relevant parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
