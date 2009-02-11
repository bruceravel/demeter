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

use Demeter::UI::Artemis::Plot::Limits;
use Demeter::UI::Artemis::Plot::Stack;
use Demeter::UI::Artemis::Plot::Indicators;
use Demeter::UI::Artemis::Plot::VPaths;

use List::Util qw(sum);

sub new {
  my ($class, $parent) = @_;
  my ($w, $h) = $parent->GetSizeWH;
  my $pos = $parent->GetScreenPosition;

  ## position of upper left corner
  my $windowsize = sum(wxSYS_BORDER_Y, wxSYS_BORDER_Y, wxSYS_BORDER_Y, wxSYS_FRAMESIZE_Y);
  my $yy = sum($pos->y, $h, $windowsize, $parent->GetStatusBar->GetSize->GetHeight);
  my $hh = Wx::SystemSettings::GetMetric(wxSYS_SCREEN_Y) - $yy - 2*$windowsize;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Plot controls",
				[0,$yy], wxDefaultSize,
				wx_MINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxRESIZE_BORDER);

  my $statusbar = $this->CreateStatusBar;
  $statusbar -> SetStatusText(q{});

  my $hbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $left  = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($left,  0, wxALL, 0);




  my $buttonbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left -> Add($buttonbox, 0, wxALL, 5);
  my $k_button = Wx::Button->new($this, -1, "k", wxDefaultPosition, wxDefaultSize);
  my $r_button = Wx::Button->new($this, -1, "R", wxDefaultPosition, wxDefaultSize);
  my $q_button = Wx::Button->new($this, -1, "q", wxDefaultPosition, wxDefaultSize);
  foreach my $b ($k_button, $r_button, $q_button) {
    $buttonbox -> Add($b, 1, wxALL, 2);
    $b -> SetForegroundColour(Wx::Colour->new("#000000"));
    $b -> SetBackgroundColour(Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default("happiness", "average_color")));
    $b -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };

  my $nb = Wx::Notebook->new( $this, -1, wxDefaultPosition, wxDefaultSize, wxBK_TOP );
  foreach my $utility (qw(limits stack indicators VPaths)) {
    my $count = $nb->GetPageCount;
    my $page = ($utility eq 'limits')     ? Demeter::UI::Artemis::Plot::Limits     -> new($nb)
             : ($utility eq 'stack')      ? Demeter::UI::Artemis::Plot::Stack      -> new($nb)
             : ($utility eq 'indicators') ? Demeter::UI::Artemis::Plot::Indicators -> new($nb)
             : ($utility eq 'VPaths')     ? Demeter::UI::Artemis::Plot::VPaths     -> new($nb)
	     :                              q{};
    next if not $page;
    $nb->AddPage($page, $utility, 0);#, $count);
  };
  $left -> Add($nb, 1, wxGROW|wxALL, 5);





  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($right, 1, wxGROW|wxALL, 5);

  my $groupbox       = Wx::StaticBox->new($this, -1, 'Plotting list', wxDefaultPosition, wxDefaultSize);
  my $groupboxsizer  = Wx::StaticBoxSizer->new( $groupbox, wxHORIZONTAL );

  my $grouplist = Wx::CheckListBox->new($this, -1, wxDefaultPosition, wxDefaultSize, [ qw(a b c a b c a b c a  ) ]);
  foreach my $i (0 .. $grouplist->GetCount) {
    $grouplist -> Check($i, 1) if ($grouplist->GetString($i) !~ m{c});
  };

  $groupboxsizer -> Add($grouplist,     1, wxGROW|wxALL, 0);
  $right         -> Add($groupboxsizer, 1, wxGROW|wxALL, 0);

  my $reset_plot = Wx::Button->new($this, -1, "Reset plot list", wxDefaultPosition, wxDefaultSize);
  $right        -> Add($reset_plot, 0, wxGROW|wxALL, 5);


  #$this -> SetSizer( $hbox );
  $this -> SetSizerAndFit( $hbox );
  #print $yy, " ", $hh, $/;
  $this -> SetSize($this->GetSize->GetWidth,$hh*0.8);
  #$this -> SetMaxSize($this->GetSize);
  return $this;


};

1;
