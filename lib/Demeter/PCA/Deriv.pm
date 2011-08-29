package Demeter::PCA::Deriv;
use Moose::Role;

has 'emin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'emax'  => (is => 'rw', isa => 'Num',    default => 0);

has 'suffix' => (is => 'rw', isa => 'Str',    default => q{der});
has 'space_description' => (is => 'rw', isa => 'Str',    default => q{derivative mu(E)});

sub interpolate {
  my ($self) = @_;
  1;
};



1;
