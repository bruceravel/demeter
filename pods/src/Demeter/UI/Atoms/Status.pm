package  Demeter::UI::Atoms::Status;
use vars qw(@ISA @EXPORT);
@ISA       = qw(Exporter);
@EXPORT    = qw(status);

sub status {
  my ($self, $text) = @_;
  $self->{statusbar}->SetStatusText($text);
};

1;

=head1 NAME

Demeter::UI::Atoms::Status - Statusbar management for stand-alone Atoms

=head1 VERSION

This documentation refers to Demeter version 0.9.13.

=head1 DESCRIPTION

This exports a single subroutine for handling statusbar messages when
Atoms is run outside of Artemis.

When run as part of Artemis, the status method is provided by the
insertion of the C<status> method into the C<Wx::Frame> namespace by
F<lib/Demeter/UI/Artemis.pm>.

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
