package Demeter::UI::Artemis::DND::PathDrag;

use Wx qw( :everything );
use Wx::DND;
use base qw(Wx::PlDataObjectSimple);

sub new {
  my ($class, @data) = @_;
  my $self = $class->SUPER::new( Wx::DataFormat->newUser( __PACKAGE__ ) );
  $self->{Data} = \@data;
  return $self;
};

sub SetData {
  my ($self, @data) = @_;
  $self->{Data} = \@data ;
  return 1;
};

sub GetData {
  my ($self) = @_;
  return $self->{Data} ;
};

sub GetDataHere {
  my ($self) = @_;
  return @{ $self->{Data} };
}

sub GetDataSize {
  my ($self) = @_;
  return $#{ $self->{Data} };
}

sub GetPerlData { $_[0]->{Data} };

1;
