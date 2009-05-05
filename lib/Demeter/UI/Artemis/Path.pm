package  Demeter::UI::Artemis::Path;

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
use base qw(Wx::Panel);
use Wx::Event qw(EVT_RIGHT_DOWN EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_MENU);

my %labels = (label  => 'Label',
	      n      => 'N',
	      s02    => 'S02',
	      e0     => 'ΔE0',
	      delr   => 'ΔR',
	      sigma2 => 'σ²',
	      ei     => 'Ei',
	      third  => '3rd',
	      fourth => '4th',
	     );

my %explanation =
  (
   label  => 'The label is a user-supplied bit of text identifying or describing the path.',
   n      => 'N is the degeneracy of the path.  For a SS path this can often be interpreted as the coordination number.',
   s02    => 'S02 is the amplitude factor in the EXAFS equation, which includes S02 and possibly other amplitude factors.',
   e0     => 'ΔE0 is an energy shift typically interpreted as the alignment of the energy grids of the data and theory.',
   delr   => 'ΔR is an adjustment to the half path length of the path.  For a SS path, this is an adjustment to the interatomic distance.',
   sigma2 => 'σ² is the mean square displacement about the half path length of the path.',
   ei     => 'Ei is a correction to the imaginary energy, which includes the effect of the mean free path and other loss terms from Feff.',
   third  => '3rd is the value of the third cumulant for this path.',
   fourth => '4th is the value of the fourth cumulant for this path.',
  );

sub new {
  my ($class, $parent, $pathobject, $datapage) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, [420,300]);
  $this->{listbook} = $parent;
  $this->{datapage} = $datapage;

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  ## -------- identifier string
  $this->{idlabel} = Wx::StaticText -> new($this, -1, "Feff name : Path name");
  $this->{idlabel}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $vbox -> Add($this->{idlabel}, 0, wxGROW|wxALL, 5);

  ## -------- show feff button and various check buttons
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  my $gbs = Wx::GridBagSizer->new( 5,5 );
  $hbox -> Add($gbs, 0, wxGROW|wxALL, 5);
  $this->{include}      = Wx::CheckBox->new($this, -1, "Include path");
  $this->{plotafter}    = Wx::CheckBox->new($this, -1, "Plot after fit");
  $this->{useasdefault} = Wx::CheckBox->new($this, -1, "Use this path as the default after the fit");
  $gbs -> Add($this->{include},      Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{plotafter},    Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{useasdefault}, Wx::GBPosition->new(1,0), Wx::GBSpan->new(1,2));


  ## -------- geometry
  $this->{geombox}  = Wx::StaticBox->new($this, -1, 'Geometry ', wxDefaultPosition, wxDefaultSize);
  my $geomboxsizer  = Wx::StaticBoxSizer->new( $this->{geombox}, wxHORIZONTAL );
  $this->{geometry} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [308,-1],
					wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $this->{geometry} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $geomboxsizer -> Add($this->{geometry}, 1, wxGROW|wxALL, 0);
  $vbox         -> Add($geomboxsizer, 1, wxLEFT|wxRIGHT, 5);

  ## -------- path parameters
  $gbs = Wx::GridBagSizer->new( 3, 10 );

  my $i = 0;
  foreach my $k (qw(label n s02 e0 delr sigma2 ei third fourth)) {
    my $label        = Wx::StaticText->new($this, -1, $labels{$k}, wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT);
    $label->{which} = $k;
    my $w = ($k eq 'n') ? 50 : 250;
    $this->{"pp_$k"} = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [$w,-1]);
    $gbs     -> Add($label,           Wx::GBPosition->new($i,1));
    $gbs     -> Add($this->{"pp_$k"}, Wx::GBPosition->new($i,2));
    ++$i;
    EVT_RIGHT_DOWN($label, sub{DoLabelKeyPress(@_, $this)});
    EVT_MENU($label, -1, sub{ $this->OnLabelMenu(@_)    });
    #EVT_ENTER_WINDOW($label, sub{$this->DoLabelEnter});
    #EVT_LEAVE_WINDOW($label, sub{$this->DoLabelLeave});
  };
  $vbox -> Add($gbs, 2, wxGROW|wxALL, 10);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);
  my $sz = 20; # [$sz,$sz]
  $this->{upbutton} = Wx::Button->new($this, wxID_UP, q{}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $hbox -> Add($this->{upbutton}, 0, wxALL, 1);
  $this->{dnbutton} = Wx::Button->new($this, wxID_DOWN, q{}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $hbox -> Add($this->{dnbutton}, 0, wxALL, 1);
  $this->{plotmarkedbutton} = Wx::Button->new($this, -1, q{&Transfer marked}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $hbox -> Add($this->{plotmarkedbutton}, 0, wxALL, 1);
  $this->{makevpathbutton} = Wx::Button->new($this, -1, q{Make &VPath}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $hbox -> Add($this->{makevpathbutton}, 0, wxALL, 1);

  $this -> populate($parent, $pathobject);
  $this -> SetSizerAndFit($vbox);

  return $this;
};

sub populate {
  my ($this, $parent, $pathobject) = @_;
  $this->{path} = $pathobject;

  my $label = $pathobject->parent->name . " : " . $pathobject->name;
  $this->{idlabel} -> SetLabel($label);

  $this->{geombox} -> SetLabel(" " . $pathobject->sp->intrplist . " ");

  my $geometry = $pathobject->sp->pathsdat;
  $geometry =~ s{.*\n}{};
  #$geometry =~ s{\d+\s* }{};
  #$geometry =~ s{index, }{};
  $this->{geometry} -> SetValue($geometry);

  $this->{include} -> SetValue(1);

  $this->{pp_label}  -> SetValue($pathobject->sp->labelline);
  $this->{pp_n}      -> SetValue($pathobject->degen);
  $this->{pp_s02}    -> SetValue($pathobject->s02);
  $this->{pp_e0}     -> SetValue($pathobject->e0     || q{});
  $this->{pp_delr}   -> SetValue($pathobject->delr   || q{});
  $this->{pp_sigma2} -> SetValue($pathobject->sigma2 || q{});
  $this->{pp_ei}     -> SetValue($pathobject->ei     || q{});
  $this->{pp_third}  -> SetValue($pathobject->third  || q{});
  $this->{pp_fourth} -> SetValue($pathobject->fourth || q{});
};

sub fetch_parameters {
  my ($this) = @_;
  foreach my $k (qw(n s02 e0 delr sigma2 ei third fourth)) {
    $this->{path}->$k($this->{"pp_$k"}->GetValue);
  };
  $this->{path}->include( $this->{include}->GetValue );
  $this->{path}->plot_after_fit($this->{plotafter}->GetValue );
};

sub DoLabelEnter {
  my ($st, $event) = @_;
  print join(" ", $st, $event), $/;
  print "entering ", $st->{which}, $/;
};
sub DoLabelLeave {
  my ($st, $event) = @_;
  print "leaving ", $st->{which}, $/;
};


sub this_path {
  my ($page) = @_;
  my $this = 0;
  foreach my $n (0 .. $page->{listbook}->GetPageCount-1) {
    $this = $n if ($page->{listbook}->GetPage($n) eq $page);
  };
  return $this;
};

use Readonly;
Readonly my $CLEAR	 => Wx::NewId();
Readonly my $THISFEFF	 => Wx::NewId();
Readonly my $THISDATA	 => Wx::NewId();
Readonly my $EACHDATA	 => Wx::NewId();
Readonly my $MARKED	 => Wx::NewId();
Readonly my $PREV	 => Wx::NewId();
Readonly my $NEXT	 => Wx::NewId();
Readonly my $DEBYE	 => Wx::NewId();
Readonly my $EINS	 => Wx::NewId();
Readonly my $EXPLAIN	 => Wx::NewId();

## use this to post context menu for path parameter
sub DoLabelKeyPress {
  #print join(" ", @_), $/;
  my ($st, $event, $page) = @_;
  my $param =  $st->{which};
  #return 0 if (($param eq 'n') or ($param eq 'label'));
  my $label = $labels{$param};
  my $menu = Wx::Menu->new(q{});
  $menu->Append($CLEAR,    "Clear $label");
  if (($param ne 'label') and ($param ne 'n')) {
    $menu->AppendSeparator;
    $menu->Append($THISFEFF, "Export this $label to every path in THIS Feff calculation");
    $menu->Append($THISDATA, "Export this $label to every path in THIS data set");
    $menu->Append($EACHDATA, "Export this $label to every path in EVERY data set");
    $menu->Append($MARKED,   "Export this $label to marked paths");
    $menu->AppendSeparator;
    $menu->Append($PREV,     "Grab $label from previous path");
    $menu->Append($NEXT,     "Grab $label from next path");
    if ($param eq 'sigma2') {
      $menu->AppendSeparator;
      $menu->Append($DEBYE, "Insert Debye model");
      $menu->Append($EINS,  "Insert Einstein model");
    };
  };
  $menu->AppendSeparator;
  $menu->Append($EXPLAIN,  "Explain $label");
  $menu->Enable($EACHDATA, 0);

  my $this = $page->this_path;
  $menu->Enable($PREV, 0) if ($this == 0);
  $menu->Enable($NEXT, 0) if ($this == $page->{listbook}->GetPageCount-1);
  $st->PopupMenu($menu, $event->GetPosition);
};

sub OnLabelMenu {
  my ($currentpage, $st, $event) = @_;
  my $listbook = $currentpage->{listbook};
  my $param = $st->{which};
  my $id = $event->GetId;

  my $this = $currentpage->this_path();
  my $thisfeff = $currentpage->{path}->parent->group;
  my $thisme = $currentpage->{"pp_$param"}->GetValue;

 SWITCH: {
    ($id == $CLEAR) and do {		# clear
      $currentpage->{"pp_$param"}->SetValue(q{});
      $currentpage->{datapage}->{statusbar}->SetStatusText("Cleared $labels{$param} for this path." );
      last SWITCH;
    };

    (($id == $THISFEFF) or ($id == $THISDATA)) and do {
      my $how = ($id == $THISFEFF) ? 0 : 1;
      $currentpage->{datapage}->add_parameters($param, $thisme, $how);
      last SWITCH;
    };
    ($id == $MARKED) and do {
      $currentpage->{datapage}->add_parameters($param, $thisme, 3);
      last SWITCH;
    };

    ($id == $EACHDATA) and do {
      ## from %frames keys, find data pages, loop over all {listpath} pages
      print $currentpage->{datapage}, $/;
      $currentpage->{datapage}->{statusbar}->SetStatusText("Set $labels{$param} for every path in every data set." );
      last SWITCH;
    };

    (($id == $PREV) or ($id == $NEXT)) and do {
      my $which = ($id == $PREV) ? $this - 1 : $this + 1;
      $currentpage->{"pp_$param"}->SetValue( $listbook->GetPage($which)->{"pp_$param"}->GetValue );
      $which = ($id == $PREV) ? "previous" : "next";
      $currentpage->{datapage}->{statusbar}->SetStatusText("Grabbed $labels{$param} from the $which path." );
      last SWITCH;
    };

    (($id == $DEBYE) or ($id == $EINS)) and do {	# correlated Debye model / Einstein model
      my $theta = ($id == $DEBYE) ? 'thetad' : 'thetae';
      my $func  = ($id == $DEBYE) ? 'debye'  : 'eins';
      my $full  = ($id == $DEBYE) ? 'Debye'  : 'Einstein';
      $currentpage->{"pp_$param"}->SetValue("$func(temp, $theta)");
      $Demeter::UI::Artemis::frames{GDS}  -> put_param(qw(set temp 300));
      $Demeter::UI::Artemis::frames{GDS}  -> put_param('guess', $theta, '500');
      $Demeter::UI::Artemis::frames{GDS}  -> clear_highlight;
      $Demeter::UI::Artemis::frames{GDS}  -> set_highlight('\A(?:temp|theta[de])\z');
      $Demeter::UI::Artemis::frames{GDS}  -> Show(1);
      $Demeter::UI::Artemis::frames{main} -> {toolbar}->ToggleTool(1,1);
      $Demeter::UI::Artemis::frames{GDS}  -> {toolbar}->ToggleTool(2,1);
      $currentpage->{datapage}->{statusbar}->SetStatusText("Inserted math expression for $full model and created two GDS parameters." );
      last SWITCH;
    };

    ($id == $EXPLAIN) and do {
      $currentpage->{datapage}->{statusbar}->SetStatusText($explanation{$param});
      last SWITCH;
    };

  };
};

sub Rename {
  my ($self, $newname) = @_;
  $self->{path}->name($newname);
  my $label = $self->{path}->parent->name . " : " . $newname;
  $self->{idlabel} -> SetLabel($label);
};


## edit for many paths : TextCtrl with toggles for choices
## -----------
## 1. export to every path, this feff calc, this data set
## 2. export to every path, each feff calc, this data set
## 3. export to every path, each feff calc, each data set
## 4. selected
## ------------
## 5. grab from previous
## 6. grab from next
##
## for sigma^2: insert Debye, insert Einstein

1;
