package  Demeter::UI::Artemis::Plot::Indicators;


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
use base qw(Wx::Panel);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize);

  my $box  = Wx::BoxSizer->new( wxVERTICAL );
  my $text = Wx::StaticText->new($this, -1, "Controls for creating, managing, and erasing indicators", [-1,-1], [200,200]);
  $box -> Add($text, 0, wxALL, 0);

  $this -> SetSizer($box);
  return $this;
};

1;
