package  Demeter::UI::Artemis::Path;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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
use Wx::Event qw(EVT_RIGHT_DOWN EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_MENU
		 EVT_CHECKBOX EVT_BUTTON EVT_HYPERLINK EVT_COLLAPSIBLEPANE_CHANGED);

use Demeter::UI::Wx::SpecialCharacters qw(:all);

my %labels = (label  => 'Label',
	      n      => 'N',
	      s02    => $S02,
	      e0     => $DELTA.$E0,
	      delr   => $DELTA.'R',
	      sigma2 => $SIGSQR,
	      ei     => 'Ei',
	      third  => '3rd',
	      fourth => '4th',
	      dphase => $DELTA.$PHI,
	     );

use vars qw(%explanation);
%explanation =
  (
   label  => 'The label is a snippet of user-supplied text identifying or describing the path.',
   n      => "N, the degeneracy of the path, is multiplied by $S02.  For SS paths this can often be interpreted as the coordination number.",
   s02    => "$S02 is the amplitude factor in the EXAFS equation, which includes $S02 and possibly other amplitude factors.",
   e0     => "$DELTA$E0 is an energy shift typically interpreted as the alignment of the energy grids of the data and theory.",
   delr   => "${DELTA}R is an adjustment to the half path length.  For a SS path, this is an adjustment to the interatomic distance.",
   sigma2 => "$SIGSQR is the mean square displacement about the half path length of the path.",
   ei     => 'Ei is a correction to the imaginary energy, which includes the effect of the mean free path and other loss terms from Feff.',
   third  => '3rd is the value of the third cumulant for this path.',
   fourth => '4th is the value of the fourth cumulant for this path.',
   dphase => "A constant offset to the phase term in the EXAFS equation $MDASH this is mostly useful for DAFS and reflectivity XAFS.",
  );

sub new {
  my ($class, $parent, $pathobject, $datapage) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, [420,300]);
  $this->{listbook} = $parent;
  $this->{datapage} = $datapage;

  $this->{color2} = Wx::Colour->new( $this->{datapage}->{data}->co->default('feff', 'intrp2color') );
  $this->{color1} = Wx::Colour->new( $this->{datapage}->{data}->co->default('feff', 'intrp1color') );
  $this->{color0} = Wx::Colour->new( $this->{datapage}->{data}->co->default('feff', 'intrp0color') );

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  ## -------- identifier string
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxBOTTOM, 4);
  $this->{plotgrab} = Wx::BitmapButton->new($this, -1, Demeter::UI::Artemis::icon('plotgrab'));
  $hbox -> Add($this->{plotgrab}, 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $this->{fefflabel}  = Wx::StaticText -> new($this, -1, "[Feff name] ");
  $this->{fefflabel} -> SetFont( Wx::Font->new( 12, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $hbox -> Add($this->{fefflabel}, 0, wxLEFT|wxTOP|wxBOTTOM, 5);
  EVT_BUTTON($this, $this->{plotgrab}, sub{transfer(@_)});
  $this->mouseover("plotgrab", "Transfer this path to the plotting list.");

  $this->{idlabel}  = Wx::StaticText -> new($this, -1, "Path name");
  $this->{idlabel} -> SetFont( Wx::Font->new( 12, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $hbox -> Add($this->{idlabel}, 0, wxRIGHT|wxTOP|wxBOTTOM, 5);

  ## -------- show feff button and various check buttons
  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  $this->{include}      = Wx::CheckBox->new($this, -1, "Include path");
  $this->{plotafter}    = Wx::CheckBox->new($this, -1, "Plot after fit");
  $hbox -> Add($this->{include},  1, wxALL, 1);
  $hbox -> Add($this->{plotafter},1, wxALL, 1);
  EVT_CHECKBOX($this, $this->{include},      sub{include_label(@_)});

  my $cpane = Wx::CollapsiblePane->new($this, -1, "Other path options");
  $vbox -> Add($cpane, 0, wxALL|wxLEFT, 4);
  my $window = $cpane->GetPane;
  my $sizer = Wx::BoxSizer->new( wxVERTICAL );
  $this->{useasdefault} = Wx::CheckBox->new($window, -1, "Use this path as the default after the fit");
  $this->{useforpc}     = Wx::CheckBox->new($window, -1, "Use this path for phase corrected plotting.");
  $sizer -> Add($this->{useasdefault}, 0, wxGROW|wxALL, 1);
  $sizer -> Add($this->{useforpc},     0, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{useasdefault}, sub{set_default_path(@_)});
  EVT_CHECKBOX($this, $this->{useforpc},     sub{set_pc_path(@_)});
  $window->SetSizer($sizer);
  #$sizer->SetSizeHints($window);
  EVT_COLLAPSIBLEPANE_CHANGED($this, $cpane, sub{$this -> SetSizerAndFit($vbox);
						 $this->{datapage} -> SetSizerAndFit($this->{datapage}->{mainbox});
					       });

  $this->mouseover("include",      "Check this button to include this path in the fit, uncheck to exclude it.");
  $this->mouseover("plotafter",    "Check this button to have this path automatically transfered to the plotting list after a fit.");
  $this->mouseover("useasdefault", "Check this button to have this path serve as the default path for evaluation of def and after parameters for the log file.");
  $this->mouseover("useforpc",     "Check this button to use this path for phase corrected plotting for this data set and its paths.");


  ## -------- geometry
  $this->{geombox}  = Wx::StaticBox->new($this, -1, 'Geometry ', wxDefaultPosition, wxDefaultSize);
  my $geomboxsizer  = Wx::StaticBoxSizer->new( $this->{geombox}, wxHORIZONTAL );
  $this->{geometry} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [-1,110],
					wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY);
  $this->{geometry} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $geomboxsizer -> Add($this->{geometry}, 1, wxGROW|wxALL, 0);
  $vbox         -> Add($geomboxsizer,     1, wxGROW|wxALL, 5);

  #my ($w,$h) = $this->{geometry}->GetSizeWH;
  #$this->{geometry}->SetSizeWH($w, 1.5*$h);

  $this->{geometry}->{2} = Wx::TextAttr->new(Wx::Colour->new( $this->{datapage}->{data}->co->default('feff', 'intrp2color') ),
					     wxNullColour, Wx::Font->new( 10, wxDEFAULT, wxSLANT, wxNORMAL, 0, "" ) );
  $this->{geometry}->{1} = Wx::TextAttr->new(Wx::Colour->new( $this->{datapage}->{data}->co->default('feff', 'intrp1color') ),
					     wxNullColour, Wx::Font->new( 10, wxDEFAULT, wxSLANT, wxNORMAL, 0, "" ) );
  $this->{geometry}->{0} = Wx::TextAttr->new(Wx::Colour->new( $this->{datapage}->{data}->co->default('feff', 'intrp0color') ),
					     wxNullColour, Wx::Font->new( 10, wxDEFAULT, wxSLANT, wxNORMAL, 0, "" ) );

  $this->mouseover("geometry", "This box contains a succinct description of the geometry of this path.");

  ## -------- path parameters
  my $gbs = Wx::GridBagSizer->new( 2, 10 );

  my $i = 0;

  foreach my $k (qw(label n s02 e0 delr sigma2 ei third fourth dphase)) {
    next if (($k eq 'dphase') and (not $this->{datapage}->{data}->co->default('artemis', 'offer_dphase')));
    my $label = Wx::HyperlinkCtrl -> new($this, -1, $labels{$k}, q{}, wxDefaultPosition, wxDefaultSize );
    $label->{which} = $k;
    $this->{"lab_$k"} = $label;
    my $w = 250;
    $this->{"pp_$k"} = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [$w,-1]);
    $gbs     -> Add($label,           Wx::GBPosition->new($i,1));
    $gbs     -> Add($this->{"pp_$k"}, Wx::GBPosition->new($i,2));
    ++$i;
    EVT_RIGHT_DOWN($label, sub{DoLabelKeyPress(@_, $this)});
    EVT_MENU($label, -1, sub{ $this->OnLabelMenu(@_)    });
    EVT_HYPERLINK($this, $label, sub{DoLabelKeyPress($label, $_[1], $_[0])});
    $label -> SetFont( Wx::Font->new( 9, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
    my $black = Wx::Colour->new(wxNullColour);
    $label -> SetNormalColour($black);
    $label -> SetHoverColour($black);
    $label -> SetVisitedColour($black);
    $this  -> mouseover("lab_$k", "(Click for the " . $labels{$k} . " menu) " . $explanation{$k});
    $this  -> mouseover("pp_$k",  $explanation{$k});
  };
  $vbox -> Add($gbs, 2, wxGROW|wxTOP|wxBOTTOM, 10);
  $this->{pp_n} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);
  my $sz = 20; # [$sz,$sz]

  $this -> populate($parent, $pathobject);
  $this -> SetSizerAndFit($vbox);

  return $this;
};

sub mouseover {
  my ($self, $widget, $text) = @_;
  EVT_ENTER_WINDOW($self->{$widget}, sub{$self->{datapage}->{statusbar}->PushStatusText($text); $_[1]->Skip;});
  EVT_LEAVE_WINDOW($self->{$widget}, sub{$self->{datapage}->{statusbar}->PopStatusText;         $_[1]->Skip;});
};

sub populate {
  my ($this, $parent, $pathobject) = @_;
  $this->{path} = $pathobject;
  return if not ($pathobject->sp); # it is kind of a disaster for a pth not to have an sp associated with it
				   # this is non-ideal as it will leave a blank path page, but it
				   # is better than crashing.  even better would be to figure out how
                                   # gets here....

  $this->{fefflabel} -> SetLabel('[' . $pathobject->parent->name . '] ');
  my $name = $pathobject->name;
  $name =~ s{\A\s+}{};
  $name =~ s{\s+\z}{};
  $this->{idlabel} -> SetLabel($name);
  $this->{idlabel} -> SetForegroundColour($this->{sprintf("color%d", $pathobject->sp->weight)});

  $this->{geombox} -> SetLabel(" " . $pathobject->sp->intrplist . " ");

  my $geometry = $pathobject->sp->pathsdat;
  $geometry =~ s{.*\n}{};
  #$geometry =~ s{\d+\s* }{};
  #$geometry =~ s{index, }{};
  $this->{geometry} -> SetValue(q{});
  my $imp = sprintf(" %s, %s\n", $pathobject->sp->Type, (qw(low medium high))[$pathobject->sp->weight]);
  $this->{geometry} -> WriteText($imp);
  $this->{geometry} -> SetStyle(0, length($imp), $this->{geometry}->{$pathobject->sp->weight});
  $this->{geometry} -> WriteText($geometry);
  $this->{geometry} -> SetInsertionPoint(0);

  $this->{include}   -> SetValue(1);
  $this->{pp_label}  -> SetValue($pathobject->sp->labelline);
  $this->{pp_n}      -> SetValue($pathobject->degen);
  $this->{pp_s02}    -> SetValue($pathobject->s02);
  $this->{pp_e0}     -> SetValue($pathobject->e0     || q{});
  $this->{pp_delr}   -> SetValue($pathobject->delr   || q{});
  $this->{pp_sigma2} -> SetValue($pathobject->sigma2 || q{});
  $this->{pp_ei}     -> SetValue($pathobject->ei     || q{});
  $this->{pp_third}  -> SetValue($pathobject->third  || q{});
  $this->{pp_fourth} -> SetValue($pathobject->fourth || q{});
  $this->{pp_dphase} -> SetValue($pathobject->dphase || q{}) if ($pathobject->co->default('artemis', 'offer_dphase'));

  $this->{include}      -> SetValue($pathobject->include);
  $this->{plotafter}    -> SetValue($pathobject->plot_after_fit);
  $this->{useasdefault} -> SetValue($pathobject->default_path);
  $this->{useforpc}     -> SetValue($pathobject->pc);
};

sub fetch_parameters {
  my ($this) = @_;
  #my $rgds = $Demeter::UI::Artemis::frames{GDS}->reset_all;
  foreach my $k (qw(n s02 e0 delr sigma2 ei third fourth dphase)) {
    next if (($k eq 'dphase') and (not $this->{path}->co->default('artemis', 'offer_dphase')));
    $this->{path}->$k($this->{"pp_$k"}->GetValue);
  };
  $this->{path}->include( $this->{include}->GetValue );
  $this->{path}->plot_after_fit($this->{plotafter}->GetValue);
  $this->{path}->default_path($this->{useasdefault}->GetValue);
  $this->{path}->pc($this->{useforpc}->GetValue);
  $this->{path}->mark($this->marked);
  ## default path after fit...
};

sub marked {
  my ($this) = @_;
  my $which = $this->{datapage}->{pathlist}->{LIST}->GetSelection; # this fails for the first item in the list!!!
  my $check_state = $this->{datapage}->{pathlist}->{LIST}->IsChecked($which) || 0;
  return $check_state;
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
  my $label = $labels{$param};
  my $menu  = Wx::Menu->new(q{});
  $menu->Append($CLEAR,    "Clear $label");
  if (($param ne 'label') and ($param ne 'n')) {
    $menu->AppendSeparator;
    $menu->Append($THISFEFF, "Export this $label to every path in THIS Feff calculation");
    $menu->Append($THISDATA, "Export this $label to every path in THIS data set");
    $menu->Append($EACHDATA, "Export this $label to every path in EVERY data set");
    $menu->Append($MARKED,   "Export this $label to marked paths in THIS data set");
    $menu->AppendSeparator;
    $menu->Append($PREV,     "Grab $label from previous path");
    $menu->Append($NEXT,     "Grab $label from next path");
    if ($param eq 'sigma2') {
      $menu->AppendSeparator;
      $menu->Append($DEBYE, "Insert Debye model");
      $menu->Append($EINS,  "Insert Einstein model");
    };
  };

  my $this = $page->this_path;
  $menu->Enable($PREV, 0) if ($this == 0);
  $menu->Enable($NEXT, 0) if ($this == $page->{listbook}->GetPageCount-1);
  my $here = ($event =~ m{Mouse}) ? $event->GetPosition : Wx::Point->new(10,10);
  $st -> PopupMenu($menu, $here);
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
      $currentpage->{datapage}->status("Cleared $labels{$param} for this path." );
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
      $currentpage->{datapage}->add_parameters($param, $thisme, 2);
      $currentpage->{datapage}->status("Set $labels{$param} for every path in every data set." );
      last SWITCH;
    };

    (($id == $PREV) or ($id == $NEXT)) and do {
      my $which = ($id == $PREV) ? $this - 1 : $this + 1;
      $currentpage->{"pp_$param"}->SetValue( $listbook->GetPage($which)->{"pp_$param"}->GetValue );
      $which = ($id == $PREV) ? "previous" : "next";
      $currentpage->{datapage}->status("Grabbed $labels{$param} from the $which path." );
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
      $currentpage->{datapage}->status("Inserted math expression for $full model and created two GDS parameters." );
      last SWITCH;
    };

    ($id == $EXPLAIN) and do {
      $currentpage->{datapage}->status($explanation{$param});
      last SWITCH;
    };

  };
};

sub include_label {
  my ($self, $event, $n) = @_;
  my $which = $n || $self->{datapage}->{pathlist}->{LIST}->GetSelection; # this fails for the first item in the list!!!
  my $check_state = $self->{datapage}->{pathlist}->{LIST}->IsChecked($which);
  my $inc   = $self->{include}->IsChecked;
  $self->{path}->include($inc);

  my $name = $self->{path}->name;

  $self->Rename($name);
  my $label = $self->{path}->label;
  ($label = sprintf("((( %s )))", $label)) if not $inc;
  $self->{datapage}->{pathlist}->SetPageText($which, $label);
  $self->{datapage}->{pathlist}->{LIST}->Check($which, $check_state);
};
sub set_default_path {
  my ($self, $event) = @_;
  foreach my $fr (keys %Demeter::UI::Artemis::frames) {
    my $datapage = $Demeter::UI::Artemis::frames{$fr};
    next if ($fr !~ m{data});
    foreach my $n (0 .. $datapage->{pathlist}->GetPageCount - 1) {
      next if ($self eq $datapage->{pathlist}->GetPage($n));
      $datapage->{pathlist}->GetPage($n)->{useasdefault}->SetValue(0);
    };
  };
};
sub set_pc_path {
  my ($self, $event) = @_;
  foreach my $fr (keys %Demeter::UI::Artemis::frames) {
    my $datapage = $Demeter::UI::Artemis::frames{$fr};
    next if ($fr !~ m{data});
    foreach my $n (0 .. $datapage->{pathlist}->GetPageCount - 1) {
      next if ($self eq $datapage->{pathlist}->GetPage($n));
      $datapage->{pathlist}->GetPage($n)->{useforpc}->SetValue(0);
    };
  };
};

sub Rename {
  my ($self, $newname) = @_;
  my $included = $self->{path}->include;
  $self->{path}->name($newname);
  $self->{path}->label(sprintf("[%s] %s", $self->{path}->parent->name, $newname));
  my $label = $newname;
  ($label = sprintf("((( %s )))", $label)) if not $included;
  $self->{idlabel} -> SetLabel($label);
};



sub transfer {
  my ($self, $event) = @_;
  my $plotlist  = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  my $name      = $self->{path}->label;
  my $found     = 0;
  my $thisgroup = $self->{path}->group;
  foreach my $i (0 .. $plotlist->GetCount - 1) {
    if ($thisgroup eq $plotlist->GetClientData($i)->group) {
      $found = 1;
      last;
    };
  };
  if ($found) {
    $self->{datapage}->status("\"$name\" is already in the plotting list.");
    return;
  };
  $plotlist->Append("Path: $name");
  my $i = $plotlist->GetCount - 1;
  $plotlist->SetClientData($i, $self->{path});
  $plotlist->Check($i,1);
  $self->{datapage}->status("Transfered path \"$name\" to the plotting list.");
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
