package Demeter::PCA::Chi;
use Moose::Role;

has 'kmin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'kmax'  => (is => 'rw', isa => 'Num',    default => 0);

has 'suffix' => (is => 'rw', isa => 'Str',    default => q{chi});
has 'space_description' => (is => 'rw', isa => 'Str',    default => q{chi(E)});

sub interpolate {
  my ($self) = @_;
  1;
};



1;
