package  Demeter::UI::Artemis::Buffer;

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

use strict;
use warnings;

use Wx qw( :everything );
use Wx::Event qw(EVT_CLOSE);
use base qw(Wx::Frame);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Ifeffit \& Plot Buffer]",
				wxDefaultPosition, [500,800],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  EVT_CLOSE($this, \&on_close);
  #my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  my $splitter = Wx::SplitterWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxSP_NOBORDER );
  #$vbox->Add($splitter, 1, wxGROW|wxALL, 0);


  $this->{IFEFFIT} = Wx::Panel->new($splitter, -1, wxDefaultPosition, wxDefaultSize);
  my $box = Wx::BoxSizer->new( wxVERTICAL );

  $this->{IFEFFIT} = Wx::Panel->new($splitter, -1);
  my $iffbox = Wx::StaticBox->new($this->{IFEFFIT}, -1, ' Ifeffit buffer ', wxDefaultPosition, wxDefaultSize);
  my $iffboxsizer  = Wx::StaticBoxSizer->new( $iffbox, wxHORIZONTAL );
  $this->{iffcommands} = Wx::TextCtrl->new($this->{IFEFFIT}, -1, q{}, wxDefaultPosition, wxDefaultSize,
					   wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $iffboxsizer -> Add($this->{iffcommands}, 1, wxALL|wxGROW, 0);
  $box -> Add($iffboxsizer, 1, wxGROW|wxALL, 5);
  $this->{IFEFFIT} -> SetSizerAndFit($box);



  $this->{PLOT} = Wx::Panel->new($splitter, -1, wxDefaultPosition, wxDefaultSize);
  $box = Wx::BoxSizer->new( wxVERTICAL );

  my $pltbox = Wx::StaticBox->new($this->{PLOT}, -1, ' Plot buffer ', wxDefaultPosition, wxDefaultSize);
  my $pltboxsizer  = Wx::StaticBoxSizer->new( $pltbox, wxHORIZONTAL );
  $this->{pltcommands} = Wx::TextCtrl->new($this->{PLOT}, -1, q{}, wxDefaultPosition, wxDefaultSize,
					   wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $pltboxsizer -> Add($this->{pltcommands}, 1, wxALL|wxGROW, 0);
  $box -> Add($pltboxsizer, 1, wxGROW|wxALL, 5);
  $this->{PLOT} -> SetSizerAndFit($box);

  $this->{iffcommands} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $this->{pltcommands} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );


  $splitter->SplitHorizontally($this->{IFEFFIT}, $this->{PLOT}, 500);

  #$this->SetSizerAndFit($vbox);


  return $this;
};

sub insert {
  my ($self, $which, $text) = @_;
  return if ($which !~ m{\A(?:ifeffit|plot)\z});
  my $textctrl = ($which eq 'ifeffit') ? 'iffcommands' : 'pltcommands';
  $self->{$textctrl} -> AppendText($text);
};


sub on_close {
  my ($self) = @_;
  $self->Show(0);
};

1;
