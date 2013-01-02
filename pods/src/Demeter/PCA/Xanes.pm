package Demeter::PCA::Xanes;
use Moose::Role;

use PDL::Lite;

has 'emin'  => (is => 'rw', isa => 'Num',    default => Demeter->co->default('pca', 'emin'));
has 'emax'  => (is => 'rw', isa => 'Num',    default => Demeter->co->default('pca', 'emax'));

sub space_description {
  my ($self) = @_;
  return q{normalized mu(E)};
};

sub ylabel {
  my ($self) = @_;
  return q{Normalized absorption};
};

sub update {
  my ($self, $data) = @_;
  $data -> _update('fft');
  return $data;
};

sub interpolate_data {
  my ($self, $data) = @_;
  $self->update($data);
  $self->data($data);
  $self->dispense('analysis', 'pca_interpolate', {suff=>$data->nsuff});
  $self->data(q{});
  return $self;
};

sub interpolate_stack {
  my ($self) = @_;

  $self->xmin($self->emin);
  $self->xmax($self->emax);

  my @groups = @{ $self->stack };
  @groups = grep {ref($_) =~ m{Data\z}} @groups;

  my $first = shift @groups;
  $self->update($first);

  my $e1 = $first->bkg_e0 + $self->xmin;
  my $i1 = $first->iofx('energy', $e1);
  my $e2 = $first->bkg_e0 + $self->xmax;
  my $i2 = $first->iofx('energy', $e2);
  $self->observations($i2-$i1+1);
  $self->undersampled($self->observations <= $#{$self->stack});
  $first->standard;
  $self->dispense('analysis', 'pca_prep', {suff=>$first->nsuff, i1=>$i1, i2=>$i2});

  foreach my $g (@groups) {
    $self->interpolate_data($g);
  };

  $first->unset_standard;
  $self->update_stack(0);
  return $self;
};

1;


=head1 NAME

Demeter::PCA::Deriv - Principle components analysis on mu(E) data

=head1 VERSION

This documentation refers to Demeter version 0.9.14.

=head1 SYNOPSIS

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the C<pca> configuration group for the relevant parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Document me!

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


