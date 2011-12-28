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
  $self->dispose($self->template('analysis', 'pca_kw', {suff=>$data->nsuff}));
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
  $self->dispose($self->template('analysis', 'pca_prep_k', {i1=>$i1, i2=>$i2}));

  foreach my $g (@groups) {
    $self->interpolate_data($g);
  };

  $first->unset_standard;
  $self->update_stack(0);
  return $self;
};



1;
