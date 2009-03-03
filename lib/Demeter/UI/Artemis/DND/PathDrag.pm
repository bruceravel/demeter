package Demeter::UI::Artemis::DND::PathDrag;
use Storable qw(freeze thaw);

use Wx qw( :everything );
use Wx::DND;
use base qw(Wx::PlDataObjectSimple);

sub new {
  my ($class, $data_ref) = @_;
  my $self = $class->SUPER::new( Wx::DataFormat->newUser( __PACKAGE__ ) );
  $self->{Data} = $data_ref;
  return $self;
};

sub SetData {
  my ($self, $data_ref) = @_;
  $self->{Data} = thaw $data_ref;
  return 1;
};

#sub GetData {
#  my ($self) = @_;
#  return $self->{Data};
#};

sub GetDataHere {
  my ($self) = @_;
  return freeze $self->{Data}  if ref $self->{Data};
}

sub GetDataSize {
  my ($self) = @_;
  return length freeze $self->{Data}  if ref $self->{Data};
}

sub GetPerlData { $_[0]->{Data} };

1;
