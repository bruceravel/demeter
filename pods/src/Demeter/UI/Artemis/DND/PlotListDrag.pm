package Demeter::UI::Artemis::DND::PlotListDrag;
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

=head1 NAME

Demeter::UI::Artemis::DND::PlotListDrag - Drag and drop utility for lists in Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This module inherits from Wx::DND to provide drag and drop utilities
for use with lists in Artemis.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
