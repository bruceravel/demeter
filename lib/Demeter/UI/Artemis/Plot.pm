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

use strict;
use warnings;

use Wx qw( :everything );
use base qw(Wx::Frame);
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_RIGHT_DOWN EVT_MENU);

use Demeter::UI::Artemis::Plot::Limits;
use Demeter::UI::Artemis::Plot::Stack;
use Demeter::UI::Artemis::Plot::Indicators;
use Demeter::UI::Artemis::Plot::VPaths;

use List::Util qw(sum);

my $demeter = $Demeter::UI::Artemis::demeter;

sub new {
  my ($class, $parent) = @_;
  my ($w, $h) = $parent->GetSizeWH;
  my $pos = $parent->GetScreenPosition;

  ## position of upper left corner
  my $windowsize = sum(wxSYS_BORDER_Y, wxSYS_BORDER_Y, wxSYS_BORDER_Y, wxSYS_FRAMESIZE_Y);
  my $yy = sum($pos->y, $h, $windowsize, $parent->GetStatusBar->GetSize->GetHeight);

  my $this = $class->SUPER::new($parent, -1, "Artemis [Plot]",
				[0,$yy], wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxRESIZE_BORDER);
  $this->{last} = q{};
  #my $statusbar = $this->CreateStatusBar;
  #$statusbar -> SetStatusText(q{});

  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $left  = Wx::BoxSizer->new( wxVERTICAL );
  $vbox -> Add($left,  0, wxGROW|wxALL, 0);




  my $buttonbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left -> Add($buttonbox, 0, wxGROW|wxALL, 5);
  $this->{k_button} = Wx::Button->new($this, -1, "&k", wxDefaultPosition, [50,-1]);
  $this->{r_button} = Wx::Button->new($this, -1, "&R", wxDefaultPosition, [50,-1] );
  $this->{q_button} = Wx::Button->new($this, -1, "&q", wxDefaultPosition, [50,-1] );
  foreach my $b (qw(k_button r_button q_button)) {
    $buttonbox -> Add($this->{$b}, 1, wxALL, 2);
    $this->{$b} -> SetForegroundColour(Wx::Colour->new("#000000"));
    $this->{$b} -> SetBackgroundColour(Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default("happiness", "average_color")));
    $this->{$b} -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };
  EVT_BUTTON($this, $this->{k_button}, sub{plot(@_, 'k')});
  EVT_BUTTON($this, $this->{r_button}, sub{plot(@_, 'r')});
  EVT_BUTTON($this, $this->{q_button}, sub{plot(@_, 'q')});

  $this->{kweight} = Wx::RadioBox->new($this, -1, "k-weight", wxDefaultPosition, wxDefaultSize,
				       [0, 1, 2, 3, 'kw'],
				       1, wxRA_SPECIFY_ROWS);
  $left -> Add($this->{kweight}, 0, wxLEFT|wxRIGHT|wxGROW, 5);
  $this->{kweight}->SetSelection(2);
  $this->{kweight}->Enable(4, 0);
  EVT_RADIOBOX($this, $this->{kweight},
	       sub{
		 my ($self, $event) = @_;
		 my $kw = $this->{kweight}->GetStringSelection;
		 $demeter->po->kweight($kw);
		 $self->plot($event, $self->{last});
	       });


  my $nb = Wx::Notebook->new( $this, -1, wxDefaultPosition, wxDefaultSize, wxBK_TOP );
  foreach my $utility (qw(limits stack indicators VPaths)) {
    my $count = $nb->GetPageCount;
    $this->{$utility} = ($utility eq 'limits')     ? Demeter::UI::Artemis::Plot::Limits     -> new($nb)
                      : ($utility eq 'stack')      ? Demeter::UI::Artemis::Plot::Stack      -> new($nb)
                      : ($utility eq 'indicators') ? Demeter::UI::Artemis::Plot::Indicators -> new($nb)
                      : ($utility eq 'VPaths')     ? Demeter::UI::Artemis::Plot::VPaths     -> new($nb)
	              :                              q{};
    next if not $this->{$utility};
    $nb->AddPage($this->{$utility}, ($utility eq 'indicators') ? 'indic.' : $utility, 0);#, $count);
  };
  $left -> Add($nb, 1, wxGROW|wxALL, 5);


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);

  my $groupbox       = Wx::StaticBox->new($this, -1, 'Plotting list', wxDefaultPosition, wxDefaultSize);
  my $groupboxsizer  = Wx::StaticBoxSizer->new( $groupbox, wxVERTICAL );

  $this->{plotlist} = Wx::CheckListBox->new($this, -1, wxDefaultPosition, [-1,200], [ ], wxLB_MULTIPLE);
  #foreach my $i (0 .. $this->{plotlist}->GetCount) {
  #  $this->{plotlist} -> Check($i, 1) if ($i%3);
  #};

  $groupboxsizer -> Add($this->{plotlist},     1, wxGROW|wxALL, 0);
  $hbox          -> Add($groupboxsizer, 1, wxGROW|wxALL, 0);
  EVT_RIGHT_DOWN($this->{plotlist}, sub{OnRightDown(@_)});
  EVT_MENU($this->{plotlist}, -1, sub{ $this->OnPlotMenu(@_)    });

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $groupboxsizer -> Add($hbox, 0, wxGROW|wxALL, 0);
  $this->{freeze} = Wx::CheckBox->new($this, -1, "&Freeze");
  $hbox -> Add($this->{freeze}, 1, wxGROW|wxALL, 5);
  $this->{clear} = Wx::Button->new($this, -1, "&Clear", wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{clear}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{clear}, sub{$_[0]->{plotlist}->Clear});

  $this -> SetSizerAndFit( $vbox );
  my $hh = Wx::SystemSettings::GetMetric(wxSYS_SCREEN_Y) - $yy - 2*$windowsize - $this->GetParent->GetSize->GetHeight;
  $this -> SetSize(Wx::Size->new(-1, $hh));
  return $this;
};

sub fetch_parameters {
  my ($self) = @_;
  foreach my $p (qw(kmin kmax rmin rmax qmin qmax)) {
    $demeter->po->$p($self->{limits}->{$p}->GetValue);
  };
};

sub plot {
  my ($self, $event, $space) = @_;
  return if ($space !~ m{[krq]}i);
  $self->fetch_parameters;
  $demeter->po->start_plot;
  my @list = ();
  foreach my $i (0 .. $self->{plotlist}->GetCount-1) {
    next if not $self->{plotlist}->IsChecked($i);
    push @list, $self->{plotlist}->GetClientData($i);
  };


  my $invert_r = (    (lc($space) eq 'r')
		  and ($self->{stack}->{invert}->GetStringSelection !~ m{Never})
		  and ($self->{limits}->{rpart}->GetStringSelection eq 'Magnitude') );
  my $invert_q = (    (lc($space) eq 'q')
		  and ($self->{stack}->{invert}->GetStringSelection !~ m{(?:Never|Only)})
		  and ($self->{limits}->{qpart}->GetStringSelection eq 'Magnitude') );


  ## for data set stacking, determine how many data sets are
  ## represented in the list, pre-set y_offsets for the data groups,
  ## process normally, reset y_offsets to their starting values

  ## stack overrides invert
  if ($self->{stack}->{dostack}->GetValue) {
    my $save = $list[0]->data->y_offset;
    $list[0] -> data -> y_offset($self->{stack}->{start}->GetValue);
    $list[0] -> po -> stackjump($self->{stack}->{increment}->GetValue);
    $list[0] -> po -> space($space);
    $list[0] -> stack(@list);
    $list[0] -> data -> y_offset($save);
  } elsif ($invert_r or $invert_q) {
    foreach my $obj (@list) {
      if (ref($obj) =~ m{Data}) { # Data plotted normally
	$obj->plot($space);
      } else {			# invert Path or VPath
	my $save = $obj->data->plot_multiplier;
	$obj->data->plot_multiplier(-1*$save);
	$obj->plot($space);
	$obj->data->plot_multiplier($save);
      };
    };
  } else {			# plot normally
    $_->plot($space) foreach @list;
  };

  $self->{last} = $space;
};

use Readonly;
Readonly my $PLOT_REMOVE => Wx::NewId();
Readonly my $PLOT_TOGGLE => Wx::NewId();

sub OnRightDown {
  my ($self, $event) = @_;
  my @sel  = $self->GetSelections;
  return if ($#sel == -1);
  my $name = ($#sel == 0) ? sprintf("\"%s\"", $self->GetString($sel[0])) : 'selected items';
  my $menu = Wx::Menu->new(q{});
  $menu->Append($PLOT_REMOVE, "Remove $name from plotting list");
  $menu->Append($PLOT_TOGGLE, "Toggle $name for plotting");
  $self->PopupMenu($menu, $event->GetPosition);
};

sub OnPlotMenu {
  print join(" ", @_), $/;
};

1;
