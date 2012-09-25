package Demeter::PCA::Chi;
use Moose::Role;

has 'kmin'  => (is => 'rw', isa => 'Num', default => Demeter->co->default('pca', 'kmin'));
has 'kmax'  => (is => 'rw', isa => 'Num', default => Demeter->co->default('pca', 'kmax'));

sub space_description {
  my ($self) = @_;
  return sprintf("k^%d*chi(k)", $self->po->kweight);
};

sub ylabel {
  my ($self) = @_;
  return $self->po->plot_kylabel;
};

sub update {
  my ($self, $data) = @_;
  $data -> _update('fft');
  return $data;
};

## chi(k) data are always on the same grid, so this is k-weighting
## rather than interpolating, but that's what the method is called...
sub interpolate_data {
  my ($self, $data) = @_;
  $self->update($data);
  $self->data($data);
  $self->dispense('analysis', 'pca_kw', {suff=>$data->nsuff});
  $self->data(q{});
  return $self;
};

sub interpolate_stack {
  my ($self) = @_;

  $self->xmin($self->kmin);
  $self->xmax($self->kmax);

  my @groups = @{ $self->stack };
  @groups = grep {ref($_) =~ m{Data\z}} @groups;

  my $first = shift @groups;
  $self->update($first);

  my $i1 = $first->iofx('k', $self->xmin);
  my $i2 = $first->iofx('k', $self->xmax);
  $self->observations($i2-$i1+1);
  $self->undersampled($self->observations <= $#{$self->stack});
  $first->standard;
  $self->dispense('analysis', 'pca_prep_k', {i1=>$i1, i2=>$i2});

  foreach my $g (@groups) {
    $self->interpolate_data($g);
  };

  $first->unset_standard;
  $self->update_stack(0);
  return $self;
};



1;

=head1 NAME

Demeter::PCA::Chi - Principle components analysis on chi(k) data

=head1 VERSION

This documentation refers to Demeter version 0.9.12.

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

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


