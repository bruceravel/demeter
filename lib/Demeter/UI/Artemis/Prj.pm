package  Demeter::UI::Artemis::Prj;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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
use Wx::Event qw(EVT_CLOSE EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX);
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use List::MoreUtils qw{firstidx minmax};


sub new {
  my ($class, $parent, $file, $style) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Import from Athena project file",
				wxDefaultPosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxSTAY_ON_TOP
			       );

  my $prj = Demeter::Data::Prj->new(file=>$file);
  my ($names, $entries) = $prj -> plot_as_chi;
  if ($style ne 'single') {
    $names = [$prj->allnames];
    $entries = $prj->entries;
  };
  $this->{prj}    = $prj;
  $this->{record} = -1;

  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );

  my $left = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($left, 1, wxGROW|wxALL, 0);

  my $sty = ($style eq 'single') ? wxLB_SINGLE : wxLB_EXTENDED;
  $this->{grouplist} = Wx::ListBox->new($this, -1, wxDefaultPosition, [125,500], $names, $sty);
  $left -> Add($this->{grouplist}, 1, wxGROW|wxALL, 5);
  EVT_LISTBOX( $this, $this->{grouplist}, sub{plot_selection(@_, $prj, $names)} );

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($right, 2, wxALL, 0);

  my $journalbox      = Wx::StaticBox->new($this, -1, 'Data group title lines', wxDefaultPosition, wxDefaultSize);
  my $journalboxsizer = Wx::StaticBoxSizer->new( $journalbox, wxHORIZONTAL );
  $this->{journal}      = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					    wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $journalboxsizer -> Add($this->{journal}, 1, wxGROW|wxALL, 0);
  $right           -> Add($journalboxsizer, 1, wxGROW|wxALL, 5);


  $this->{plotas} = Wx::RadioBox->new($this, -1, "Plot as", wxDefaultPosition, wxDefaultSize,
				      ["$MU(E)", "$CHI(k)", "|$CHI(R)|", "Re[$CHI(R)]", "Im[$CHI(R)]", "|$CHI(q)|", "Re[$CHI(q)]", "Im[$CHI(q)]"],
				      4, wxRA_SPECIFY_ROWS);
  $right -> Add($this->{plotas}, 0, wxGROW|wxALL, 5);
  ($style eq 'single') ? $this->{plotas}->SetSelection(2) : $this->{plotas}->SetSelection(0);
  EVT_RADIOBOX($this, $this->{plotas}, sub{OnPlotAs(@_, $prj, $names)});

  $this->{params} = Wx::RadioBox->new($this, -1, "Take parameters from", wxDefaultPosition, wxDefaultSize,
				      ['Project file', 'Artemis defaults', 'Current values'],
				      3, wxRA_SPECIFY_ROWS);
  $right -> Add($this->{params}, 0, wxGROW|wxALL, 5);

  if ($style ne 'single') {
    my $selectionbox  = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{all}    = Wx::Button->new($this, -1, "Select all", wxDefaultPosition, wxDefaultSize, 0,);
    $this->{none}   = Wx::Button->new($this, -1, "Select none", wxDefaultPosition, wxDefaultSize, 0,);
    $this->{invert} = Wx::Button->new($this, -1, "Invert", wxDefaultPosition, wxDefaultSize, 0,);
    $selectionbox  -> Add($this->{all},    0, wxGROW|wxLEFT|wxRIGHT, 2);
    $selectionbox  -> Add($this->{none},   0, wxGROW|wxLEFT|wxRIGHT, 2);
    $selectionbox  -> Add($this->{invert}, 0, wxGROW|wxLEFT|wxRIGHT, 2);
    EVT_BUTTON($this, $this->{all},    sub{set_selection(@_, 'all')});
    EVT_BUTTON($this, $this->{none},   sub{set_selection(@_, 'none')});
    EVT_BUTTON($this, $this->{invert}, sub{set_selection(@_, 'invert')});
    $right->Add($selectionbox, 0, wxGROW|wxALL, 5);

    my $skipbox    = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{skip}  = Wx::Button->new($this, -1, "Select every", wxDefaultPosition, wxDefaultSize, 0,);
    $this->{every} = Wx::TextCtrl->new($this, -1, "2", wxDefaultPosition, [30,-1]);
    $this->{start} = Wx::TextCtrl->new($this, -1, "1", wxDefaultPosition, [30,-1]);

    $skipbox     -> Add($this->{skip}, 0, wxLEFT|wxRIGHT, 2);
    $skipbox     -> Add($this->{every}, 0, wxLEFT|wxRIGHT, 2);
    $skipbox     -> Add(Wx::StaticText->new($this, -1, "th starting at #"), 0, wxALL, 2);
    $skipbox     -> Add($this->{start}, 0, wxLEFT|wxRIGHT, 2);
    EVT_BUTTON($this, $this->{skip}, sub{set_selection(@_, 'skip')});
    $right->Add($skipbox, 0, wxGROW|wxALL, 5);

    my $matchbox   = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{match} = Wx::Button->new($this, -1, "Select matching", wxDefaultPosition, wxDefaultSize, 0,);
    $this->{regex} = Wx::TextCtrl->new($this, -1, q{});
    $matchbox     -> Add($this->{match}, 0, wxGROW|wxLEFT|wxRIGHT, 2);
    $matchbox     -> Add($this->{regex}, 0, wxGROW|wxLEFT|wxRIGHT, 2);
    EVT_BUTTON($this, $this->{match}, sub{set_selection(@_, 'match')});
    $right->Add($matchbox, 0, wxGROW|wxALL, 5);
  };

  $this->{import} = Wx::Button->new($this, wxID_OK, "Import selected data", wxDefaultPosition, wxDefaultSize, 0,);
  $right -> Add($this->{import}, 0, wxGROW|wxALL, 5);
  #$this -> SetAffirmativeId($this->{import}->GetId);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $right -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);
  #$this -> SetAffirmativeId($this->{cancel}->GetId);

  $this -> SetSizerAndFit( $hbox );

  if ($style eq 'single') {
    $this->{grouplist}->SetSelection(0);
    $this->do_plot($prj,1);
  };
  return $this;
};

sub on_close {
  my ($self) = @_;
  $self->SetReturnCode(wxID_CANCEL);
};

sub ShouldPreventAppExit {
  0
};

sub OnPlotAs {
  my ($this, $event, $prj, $names) = @_;
  return if ($this->{grouplist}->GetSelections < 0);
  my ($sel) = $this->{grouplist}->GetSelections;
  $this -> do_plot($prj, $sel+1);
};

sub plot_selection {
  my ($this, $event, $prj, $names) = @_;
  $this->Refresh;
  my ($sel) = $this->{grouplist}->GetSelections;
  $this->{record} = $sel+1;
  #my $index = firstidx {$_ eq $event->GetString } @$names;
  $this -> do_plot($prj, $sel+1);
};
sub do_plot {
  my ($this, $prj, $record) = @_;
  my $busy   = Wx::BusyCursor->new();
  my @save = ($prj->po->r_pl, $prj->po->q_pl);
  $this->{record} = $record;
  my $data = $prj->record($record);
  $this->{journal}->SetValue(join($/, @{$data->titles}));
  $prj->po->start_plot;
  my $plotas = $this->{plotas}->GetSelection;
  my $space = ($plotas == 0) ? 'E'
            : ($plotas == 1) ? 'k'
            : ($plotas <  5) ? 'r'
	    :                  'q';
  if ($plotas == 0) {
    $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  };
  $prj->po->r_pl('m') if ($plotas == 2);
  $prj->po->r_pl('r') if ($plotas == 3);
  $prj->po->r_pl('i') if ($plotas == 4);
  $prj->po->q_pl('m') if ($plotas == 5);
  $prj->po->q_pl('r') if ($plotas == 6);
  $prj->po->q_pl('i') if ($plotas == 7);
  $prj->po->kweight(2);
  $data -> plot($space);
  $prj->po->r_pl($save[0]);
  $prj->po->q_pl($save[1]);
  $data -> DESTROY;
  undef $busy;
};

sub set_selection {
  my ($this, $event, $how) = @_;
  foreach my $i (0 .. $this->{grouplist}->GetCount-1) {
    if ($how eq 'skip') {
      my $j = $i - ($this->{start}->GetValue - 1);
      my $n = $this->{every}->GetValue;
      my $select = not ($j % $n);
      ($select = 0) if ($j < 0);
      $this->{grouplist}->SetSelection($i, $select);
    } elsif ($how eq 'match') {
      my $regex = $this->{regex}->GetValue;
      next if ($this->{regex}->GetValue =~ m{\A\s*\z});
      my $re;
      my $is_ok = eval '$re = qr/$regex/';
      next if not $is_ok;
      my $matches = $this->{grouplist}->GetString($i) =~ m{$re};
      $this->{grouplist}->SetSelection($i, $matches);
    } else {
      my $val = ($how eq 'all')    ? 1
	      : ($how eq 'none')   ? 0
	      : ($how eq 'invert') ? (not $this->{grouplist}->IsSelected($i))
	      :                      $this->{grouplist}->IsSelected($i);
      $this->{grouplist}->SetSelection($i, $val);
    };
  };
};


1;
