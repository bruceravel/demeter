package  Demeter::UI::Artemis::Plot::Stack;


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

  my $box = Wx::BoxSizer->new( wxVERTICAL );
  #my $top =  Wx::BoxSizer->new( wxHORIZONTAL );
  #$box -> Add($top, 0, wxGROW);

  my $stackbox       = Wx::StaticBox->new($this, -1, 'Stack plots', wxDefaultPosition, wxDefaultSize);
  my $stackboxsizer  = Wx::StaticBoxSizer->new( $stackbox, wxHORIZONTAL );

  my $vv =  Wx::BoxSizer->new( wxVERTICAL );
  my $stack = Wx::CheckBox->new($this, -1, "Do stacked plot", wxDefaultPosition, wxDefaultSize);

  $vv -> Add($stack, 0, wxTOP, 2);

  my $label  = Wx::StaticText->new($this, -1, 'Starting value');
  my $start  = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, [-1, -1]);
  $vv -> Add($label, 0, wxTOP, 2);
  $vv -> Add($start, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  $label  = Wx::StaticText->new($this, -1, 'Increment');
  my $increment = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, [-1, -1]);
  $vv -> Add($label,     0, wxTOP, 2);
  $vv -> Add($increment, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  $stackboxsizer->Add($vv, 1, wxGROW|wxALL, 5);
  $box->Add($stackboxsizer, 1, wxGROW|wxTOP|wxBOTTOM, 3);



  my $invert = Wx::RadioBox->new($this, -1, "Invert paths", wxDefaultPosition, wxDefaultSize,
				 ['Never', "|χ(R)| + |χ(q)|", 'Only |χ(R)|'],
				 2, wxRA_SPECIFY_ROWS);
  $box -> Add($invert, 0, wxGROW|wxALL, 3);



  my $dsbox       = Wx::StaticBox->new($this, -1, 'Stack data sets', wxDefaultPosition, wxDefaultSize);
  my $dsboxsizer  = Wx::StaticBoxSizer->new( $dsbox, wxHORIZONTAL );
  $label  = Wx::StaticText->new($this, -1, 'Offset');
  my $offset = Wx::TextCtrl->new($this, -1, 0);
  $dsboxsizer -> Add($label, 0, wxALL, 5);
  $dsboxsizer -> Add($offset, 1, wxALL, 5);
  $box->Add($dsboxsizer, 0, wxGROW|wxALL, 3);


  $this -> SetSizer($box);
  return $this;
};

1;