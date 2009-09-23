package  Demeter::UI::Artemis::Data::Histogram;

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
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_RADIOBUTTON);

sub new {
  my ($class, $parent) = @_;

  my $data = $parent->{data};
  my $sp = $parent->{pathlist}->GetPageText($parent->{pathlist}->GetSelection);
  my $this = $class->SUPER::new($parent, -1, "Artemis: Make histogram",
				Wx::GetMousePosition, [600, -1],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $outerbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $label = Wx::StaticText->new($this, -1, "Make a histogram using \"$sp\"");
  $outerbox -> Add($label, 0, wxGROW|wxALL, 5);
  $label->SetFont( Wx::Font->new( 12, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $outerbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);

  ## -------- from file
  $this->{filesel} = Wx::RadioButton->new($this, -1, 'Read histogram from a file', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $outerbox -> Add($this->{filesel}, 0, wxGROW|wxALL, 5);
  EVT_RADIOBUTTON($this, $this->{filesel}, \&OnChoice);

  $this->{filepicker} = Wx::FilePickerCtrl->new( $this, -1, "", "Choose a File", "All files|*",
				    [-1, -1], [-1, -1], wxFLP_DEFAULT_STYLE|wxFLP_USE_TEXTCTRL );
  $outerbox -> Add($this->{filepicker}, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  my $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $outerbox -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  $this->{filerminlab} = Wx::StaticText->new($this, -1, "Rmin");
  $vbox -> Add($this->{filerminlab}, 0, wxGROW|wxALL, 5);
  $this->{filermin} = Wx::TextCtrl->new($this, -1, $data->co->default(qw(histogram rmin)), wxDefaultPosition, [60,-1],);
  $vbox -> Add($this->{filermin}, 0, wxGROW|wxALL, 5);

  $this->{filermaxlab} = Wx::StaticText->new($this, -1, "Rmax");
  $vbox -> Add($this->{filermaxlab}, 0, wxGROW|wxALL, 5);
  $this->{filermax} = Wx::TextCtrl->new($this, -1, $data->co->default(qw(histogram rmax)), wxDefaultPosition, [60,-1],);
  $vbox -> Add($this->{filermax}, 0, wxGROW|wxALL, 5);

  $this->{filexcollab} = Wx::StaticText->new($this, -1, "x-axis column");
  $vbox -> Add($this->{filexcollab}, 0, wxGROW|wxALL, 5);
  $this->{filexcol} = Wx::SpinCtrl->new($this, -1, $data->co->default(qw(histogram xcol)), wxDefaultPosition, [60,-1],);
  $vbox -> Add($this->{filexcol}, 0, wxGROW|wxALL, 5);
  $this->{filexcol}->SetRange(1,1000);

  $this->{fileycollab} = Wx::StaticText->new($this, -1, "y-axis column");
  $vbox -> Add($this->{fileycollab}, 0, wxGROW|wxALL, 5);
  $this->{fileycol} = Wx::SpinCtrl->new($this, -1, $data->co->default(qw(histogram ycol)), wxDefaultPosition, [60,-1],);
  $vbox -> Add($this->{fileycol}, 0, wxGROW|wxALL, 5);
  $this->{fileycol}->SetRange(1,1000);



  ## -------- from Gamma function
  $this->{gammasel} = Wx::RadioButton->new($this, -1, 'Create histogram from a Gamma-like function', wxDefaultPosition, wxDefaultSize);
  $outerbox -> Add($this->{gammasel}, 0, wxGROW|wxALL, 5);
  EVT_RADIOBUTTON($this, $this->{gammasel}, \&OnChoice);

  $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $outerbox -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  $this->{gammarminlab} = Wx::StaticText->new($this, -1, "Rmin");
  $vbox -> Add($this->{gammarminlab}, 0, wxGROW|wxALL, 5);
  $this->{gammarmin} = Wx::TextCtrl->new($this, -1, $data->co->default(qw(histogram rmin)), wxDefaultPosition, [60,-1],);
  $vbox -> Add($this->{gammarmin}, 0, wxGROW|wxALL, 5);

  $this->{gammarmaxlab} = Wx::StaticText->new($this, -1, "Rmax");
  $vbox -> Add($this->{gammarmaxlab}, 0, wxGROW|wxALL, 5);
  $this->{gammarmax} = Wx::TextCtrl->new($this, -1, $data->co->default(qw(histogram rmax)), wxDefaultPosition, [60,-1],);
  $vbox -> Add($this->{gammarmax}, 0, wxGROW|wxALL, 5);


  $this->{gammargridlab} = Wx::StaticText->new($this, -1, "Rgrid");
  $vbox -> Add($this->{gammargridlab}, 0, wxGROW|wxALL, 5);
  $this->{gammargrid} = Wx::TextCtrl->new($this, -1, $data->co->default(qw(histogram rgrid)), wxDefaultPosition, [60,-1],);
  $vbox -> Add($this->{gammargrid}, 0, wxGROW|wxALL, 5);

  $this->{$_}->Enable(0) foreach qw(gammarminlab gammarmin gammarmaxlab gammarmax gammargridlab gammargrid);

  ## -------- controls
  $outerbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);

  $this->{ok} = Wx::Button->new($this, wxID_OK, "Make histogram", wxDefaultPosition, wxDefaultSize, 0, );
  $outerbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $outerbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);

  $this -> SetSizerAndFit( $outerbox );
  return $this;
};

sub OnChoice {
  my ($parent, $event) = @_;
  my $is_file  = $parent->{filesel} ->GetValue;
  my $is_gamma = $parent->{gammasel}->GetValue;
  $parent->{$_}->Enable($is_file)  foreach qw(filepicker filerminlab filermin filermaxlab filermax
					      filexcollab filexcol fileycollab fileycol);
  $parent->{$_}->Enable($is_gamma) foreach qw(gammarminlab gammarmin gammarmaxlab gammarmax gammargridlab gammargrid);
};

sub ShouldPreventAppExit {
  0
};

1;
