package Demeter::PCA::Xanes;
use Moose::Role;

has 'emin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'emax'  => (is => 'rw', isa => 'Num',    default => 0);

has 'suffix' => (is => 'rw', isa => 'Str',    default => q{flat});
has 'space_description' => (is => 'rw', isa => 'Str',    default => q{normalized mu(E)});

sub interpolate {
  my ($self) = @_;
  1;
};



1;
