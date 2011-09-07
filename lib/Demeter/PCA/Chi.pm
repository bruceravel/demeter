package Demeter::PCA::Chi;
use Moose::Role;

has 'kmin'  => (is => 'rw', isa => 'Num', default => Demeter->co->default('pca', 'kmin'));
has 'kmax'  => (is => 'rw', isa => 'Num', default => Demeter->co->default('pca', 'kmax'));
has 'space_description' => (is => 'rw', isa => 'Str',    default => q{chi(k)});

sub set_space_description {
  my ($self) = @_;
  $self->space_description(sprintf("k^%d*chi(k)", $self->po->kweight));
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

sub interpolate_data {
  my ($self) = @_;
  1;
};

sub interpolate_stack {
  my ($self) = @_;
  1;
};



1;
