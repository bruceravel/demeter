package Demeter::UI::Hephaestus::Transitions;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use strict;
use warnings;
use Carp;
use Wx qw( :everything );

use base 'Wx::Panel';

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{echo} = $echoarea;

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );

  my $file = File::Spec->catfile($Demeter::UI::Hephaestus::hephaestus_base, 'Hephaestus', 'data', "trans_table.png");
  my $bitmap = Wx::Bitmap->new($file, wxBITMAP_TYPE_PNG);
  my $picture = Wx::StaticBitmap->new($self, -1, $bitmap);
  $hbox -> Add($picture, 1, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $self->SetSizerAndFit($hbox);

  return $self;
};


1;

=head1 NAME

Demeter::UI::Hephaestus::Transitions - Hephaestus' electronic transitions utility

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

The contents of Hephaestus' electronic transistions utility can be
added to any Wx application.

  my $page = Demeter::UI::Hephaestus::Transitions->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility presents a diagram explaining the electronic transitions
associated with the various fluorescence lines.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Draw the chart on a canvas and provide some interactivity along with a
periodic table popup.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
