package  Demeter::UI::Artemis::Prj;

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
use Wx::Event qw(EVT_CLOSE EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX);
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use List::MoreUtils qw{firstidx};


sub new {
  my ($class, $parent, $file, $selref) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Import from Athena project file",
				wxDefaultPosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxSTAY_ON_TOP
			       );

  my $prj = Demeter::Data::Prj->new(file=>$file);
  my ($names, $entries) = $prj -> plot_as_chi;
  $this->{prj}    = $prj;
  $this->{record} = -1;

  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );

  my $left = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($left, 1, wxGROW|wxALL, 0);

  $this->{grouplist} = Wx::ListBox->new($this, -1, wxDefaultPosition, [125,500],
					$names, wxLB_SINGLE);
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
				      ["$CHI(k)", "|$CHI(R)|", "Re[$CHI(R)]", "Im[$CHI(R)]", "|$CHI(q)|", "Re[$CHI(q)]", "Im[$CHI(q)]"],
				      4, wxRA_SPECIFY_ROWS);
  $right -> Add($this->{plotas}, 0, wxGROW|wxALL, 5);
  $this->{plotas}->SetSelection(1);
  EVT_RADIOBOX($this, $this->{plotas}, sub{OnPlotAs(@_, $prj, $names)});

  $this->{params} = Wx::RadioBox->new($this, -1, "Take parameters from", wxDefaultPosition, wxDefaultSize,
				      ['Project file', 'Artemis defaults', 'Current values'],
				      3, wxRA_SPECIFY_ROWS);
  $right -> Add($this->{params}, 0, wxGROW|wxALL, 5);

  $this->{import} = Wx::Button->new($this, wxID_OK, "Import selected data", wxDefaultPosition, wxDefaultSize, 0,
 				   );
  $right -> Add($this->{import}, 0, wxGROW|wxALL, 5);
  #$this -> SetAffirmativeId($this->{import}->GetId);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $right -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);
  #$this -> SetAffirmativeId($this->{cancel}->GetId);

  $this -> SetSizerAndFit( $hbox );

  $this->{grouplist}->SetSelection(0), $this->do_plot($prj,1);
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
  my $space = ($plotas == 0) ? 'k'
            : ($plotas <  4) ? 'r'
	    :                  'q';
  $prj->po->r_pl('m') if ($plotas == 1);
  $prj->po->r_pl('r') if ($plotas == 2);
  $prj->po->r_pl('i') if ($plotas == 3);
  $prj->po->q_pl('m') if ($plotas == 4);
  $prj->po->q_pl('r') if ($plotas == 5);
  $prj->po->q_pl('i') if ($plotas == 6);
  $prj->po->kweight(2);
  $data -> plot($space);
  $prj->po->r_pl($save[0]);
  $prj->po->q_pl($save[1]);
  $data -> DESTROY;
  undef $busy;
};

1;
