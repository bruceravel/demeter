package  Demeter::UI::Artemis::Plot;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Wx qw( :everything );
use base qw(Wx::Frame);

sub new {
  my ($class, $parent) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Plot controls",
				wxDefaultPosition, wxDefaultSize,
				wx_MINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxRESIZE_BORDER);
  my $statusbar = $this->CreateStatusBar;
  $statusbar -> SetStatusText(q{});
  my $hbox  = Wx::BoxSizer->new( wxVERTICAL );
  $this -> SetSizerAndFit( $hbox );
  return $this;
};
