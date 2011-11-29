package Demeter::Return;

use Moose;

has 'status'  => (is => 'rw', isa => 'Int',  default => 1);
has 'message' => (is => 'rw', isa => 'Str',  default => q{});

sub is_ok {
  my ($self) = @_;
  return 0 if not $self->status;
  return 1;
};

1;
