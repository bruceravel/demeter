package Demeter::UI::Athena::Plot::PlotR;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN
		 EVT_CHECKBOX EVT_RADIOBUTTON EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Scalar::Util qw(looks_like_number);

use Demeter::UI::Athena::Replot;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxGROW|wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slots = Wx::GridSizer->new( 6, 2, 0, 1 );
  $hbox -> Add($slots, 1, wxGROW|wxALL, 0);

  $this->{mag} = Wx::CheckBox->new($this, -1, 'Magnitude', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mag}, 1, wxGROW|wxALL, 1);
  $this->{mmag} = Wx::RadioButton->new($this, -1, 'Magnitude', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $slots -> Add($this->{mmag}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{mag},
	       sub{my ($this, $event) = @_;
		   if ($this->{mag}->GetValue) {
		     $this->{env}->SetValue(0);
		   };
		   $this->replot(qw(r single));
		 });
  EVT_RADIOBUTTON($this, $this->{mmag}, sub{$_[0]->replot(qw(r marked))});
  $app->mouseover($this->{mag},  "Plot the magnitude of $CHI(R) when ploting the current group in R-space.");
  $app->mouseover($this->{mmag}, "Plot the magnitude of $CHI(R) when ploting the marked groups in R-space.");

  $this->{env} = Wx::CheckBox->new($this, -1, 'Envelope', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{env}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{env},
	       sub{my ($this, $event) = @_;
		   if ($this->{env}->GetValue) {
		     $this->{mag}->SetValue(0);
		   };
		   $this->replot(qw(r single));
		 });
  $app->mouseover($this->{mag},  "Plot the envelope of $CHI(R) when ploting the current group in R-space.");
  $slots -> Add(Wx::StaticText->new($this, -1, q{}), 0, wxGROW|wxALL, 1);

  $this->{re} = Wx::CheckBox->new($this, -1, 'Real part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{re}, 1, wxGROW|wxALL, 1);
  $this->{mre} = Wx::RadioButton->new($this, -1, 'Real part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mre}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{re}, sub{$_[0]->replot(qw(r single))});
  EVT_RADIOBUTTON($this, $this->{mre}, sub{$_[0]->replot(qw(r marked))});
  $app->mouseover($this->{re},  "Plot the real part of $CHI(R) when ploting the current group in R-space.");
  $app->mouseover($this->{mre}, "Plot the real part of $CHI(R) when ploting the marked groups in R-space.");

  $this->{im} = Wx::CheckBox->new($this, -1, 'Imag. part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{im}, 1, wxGROW|wxALL, 1);
  $this->{mim} = Wx::RadioButton->new($this, -1, 'Imag. part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mim}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{im}, sub{$_[0]->replot(qw(r single))});
  EVT_RADIOBUTTON($this, $this->{mim}, sub{$_[0]->replot(qw(r marked))});
  $app->mouseover($this->{im},  "Plot the imaginary part of $CHI(R) when ploting the current group in R-space.");
  $app->mouseover($this->{mim}, "Plot the imaginary part of $CHI(R) when ploting the marked groups in R-space.");

  $this->{pha} = Wx::CheckBox->new($this, -1, 'Phase', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{pha}, 1, wxGROW|wxALL, 1);
  $this->{mpha} = Wx::RadioButton->new($this, -1, 'Phase', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mpha}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{pha}, sub{$_[0]->replot(qw(r single))});
  EVT_RADIOBUTTON($this, $this->{mpha}, sub{$_[0]->replot(qw(r marked))});
  $app->mouseover($this->{pha},  "Plot the phase of $CHI(R) when ploting the current group in R-space.");
  $app->mouseover($this->{mpha}, "Plot the phase of $CHI(R) when ploting the marked groups in R-space.");

  $this->{win} = Wx::CheckBox->new($this, -1, 'Window', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{win}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{win}, sub{$_[0]->replot(qw(r single))});
  $app->mouseover($this->{win}, "Plot the window function when ploting the current group in R-space.");
  $slots -> Add(Wx::StaticText->new($this, -1, q{}), 0, wxGROW|wxALL, 1);

  $this->{dphase} = Wx::CheckBox->new($this, -1, 'Deriv of phase', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{dphase}, 1, wxGROW|wxALL, 1);
  $this->{mdphase} = Wx::CheckBox->new($this, -1, 'Deriv of phase', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mdphase}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{dphase}, sub{$_[0]->replot(qw(r single))});
  EVT_CHECKBOX($this, $this->{mdphase}, sub{$_[0]->replot(qw(r marked))});
  $app->mouseover($this->{dphase}, "Plot the the derivative of the phase of $CHI(R) for the current group.");
  $app->mouseover($this->{mdphase}, "Plot the the derivative of the phase of $CHI(R) for all marked groups.");
  if (not $Demeter::UI::Athena::demeter->co->default("athena", "show_dphase")) {
    $this->{dphase}->Hide;
    $this->{mdphase}->Hide;
  };

  SWITCH: {
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'm') and do {
	$this->{mag} ->SetValue(1);
	$this->{mmag}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'e') and do {
	$this->{env} ->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'r') and do {
	$this->{re} ->SetValue(1);
	$this->{mre}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'i') and do {
	$this->{im} ->SetValue(1);
	$this->{mim}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'p') and do {
	$this->{pha} ->SetValue(1);
	$this->{mpha}->SetValue(1);
	last SWITCH;
      };
    };

  #$hbox -> Add(0, 0, 1);

  #my $right = Wx::BoxSizer->new( wxVERTICAL );
  #$hbox -> Add($right, 0, wxALL, 4);

  $box -> Add(1, 1, 1);

  my $range = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($range, 0, wxALL|wxGROW, 0);
  my $label = Wx::StaticText->new($this, -1, "Rmin", wxDefaultPosition, [35,-1]);
  $this->{rmin} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "rmin"),
				     wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{rmin}, 1, wxRIGHT, 10);
  $label = Wx::StaticText->new($this, -1, "Rmax", wxDefaultPosition, [35,-1]);
  $this->{rmax} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "rmax"),
				     wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{rmax}, 1, wxRIGHT, 10);

  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "single")) )
    foreach (qw(mag env re im pha win dphase));
  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "marked")) )
    foreach (qw(mmag mre mim mpha mdphase));

  foreach my $x (qw(rmin rmax)) {
    $this->{$x} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
    EVT_TEXT_ENTER($this, $this->{$x}, sub{OnTextEnter(@_, $::app, $x)});
  };

  $this->SetSizerAndFit($box);
  return $this;
};

sub OnTextEnter {
  my ($main, $event, $app, $which) = @_;
  my @list = $app->marked_groups;
  my $how = (@list) ? 'marked' : 'single';
  $app->plot(q{}, q{}, 'R', $how);
};

sub label {
  return 'Plot in R-space';
};

sub pull_single_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  my $rmin = $this->{rmin}-> GetValue;
  my $rmax = $this->{rmax}-> GetValue;
  $::app->{main}->status(q{}, 'nobuffer');
  $rmin = 0, $::app->{main}->status("Rmin is not a number", 'error|nobuffer') if not looks_like_number($rmin);
  $rmax = 6, $::app->{main}->status("Rmax is not a number", 'error|nobuffer') if not looks_like_number($rmax);
  $po->rmin($rmin);
  $po->rmax($rmax);
};

sub pull_marked_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  my $val = ($this->{mmag} -> GetValue) ? 'm'
          : ($this->{mre}  -> GetValue) ? 'r'
          : ($this->{mim}  -> GetValue) ? 'i'
          : ($this->{mpha} -> GetValue) ? 'p'
	  :                               'm';
  $po->r_pl($val);
  $::app->{main}->status(q{}, 'nobuffer');
  my $rmin = $this->{rmin}-> GetValue;
  my $rmax = $this->{rmax}-> GetValue;
  $rmin = 0, $::app->{main}->status("Rmin is not a number", 'error|nobuffer') if not looks_like_number($rmin);
  $rmax = 6, $::app->{main}->status("Rmax is not a number", 'error|nobuffer') if not looks_like_number($rmax);
  $po->rmin($rmin);
  $po->rmax($rmax);
};

1;

=head1 NAME

Demeter::UI::Athena::Plot::PlotR - R-space plotting controls

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

This module provides controls for plotting in R space in Athena

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
