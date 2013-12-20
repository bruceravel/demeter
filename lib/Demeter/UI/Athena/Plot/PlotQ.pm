package Demeter::UI::Athena::Plot::PlotQ;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN
		 EVT_CHECKBOX EVT_RADIOBUTTON EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Athena::Replot;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Scalar::Util qw(looks_like_number);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxGROW|wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slots = Wx::GridSizer->new( 6, 2, 0, 1 );
  $hbox -> Add($slots, 1, wxGROW|wxALL, 0);

  $this->{mag} = Wx::CheckBox->new($this, -1, 'Magnitude', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mag}, 1,  wxGROW|wxALL, 1);
  $this->{mmag} = Wx::RadioButton->new($this, -1, 'Magnitude', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $slots -> Add($this->{mmag}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{mag},
	       sub{my ($this, $event) = @_;
		   if ($this->{mag}->GetValue) {
		     $this->{env}->SetValue(0);
		   };
		   $this->replot(qw(q single));
		 });
  EVT_RADIOBUTTON($this, $this->{mmag}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{mag},  "Plot the magnitude of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mmag}, "Plot the magnitude of $CHI(q) when ploting the marked groups in filtered k-space.");

  $this->{env} = Wx::CheckBox->new($this, -1, 'Envelope', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{env}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{env},
	       sub{my ($this, $event) = @_;
		   if ($this->{env}->GetValue) {
		     $this->{mag}->SetValue(0);
		   };
		   $this->replot(qw(q single));
		 });
  $app->mouseover($this->{mag},  "Plot the envelope of $CHI(q) when ploting the current group in filtered k-space.");
  $slots -> Add(Wx::StaticText->new($this, -1, q{}), 0, wxGROW|wxALL, 1);

  $this->{re} = Wx::CheckBox->new($this, -1, 'Real part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{re}, 1, wxGROW|wxALL, 1);
  $this->{mre} = Wx::RadioButton->new($this, -1, 'Real part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mre}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{re}, sub{$_[0]->replot(qw(q single))});
  EVT_RADIOBUTTON($this, $this->{mre}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{re},  "Plot the real part of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mre}, "Plot the real part of $CHI(q) when ploting the marked groups in filtered k-space.");

  $this->{im} = Wx::CheckBox->new($this, -1, 'Imag. part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{im}, 1, wxGROW|wxALL, 1);
  $this->{mim} = Wx::RadioButton->new($this, -1, 'Imag. part', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mim}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{im}, sub{$_[0]->replot(qw(q single))});
  EVT_RADIOBUTTON($this, $this->{mim}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{im},  "Plot the imaginary part of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mim}, "Plot the imaginary part of $CHI(q) when ploting the marked groups in filtered k-space.");

  $this->{pha} = Wx::CheckBox->new($this, -1, 'Phase', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{pha}, 1, wxGROW|wxALL, 1);
  $this->{mpha} = Wx::RadioButton->new($this, -1, 'Phase', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{mpha}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{pha}, sub{$_[0]->replot(qw(q single))});
  EVT_RADIOBUTTON($this, $this->{mpha}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{pha},  "Plot the phase of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mpha}, "Plot the phase of $CHI(q) when ploting the marked groups in filtered k-space.");

  $this->{win} = Wx::CheckBox->new($this, -1, 'Window', wxDefaultPosition, wxDefaultSize);
  $slots -> Add($this->{win}, 1, wxGROW|wxALL, 1);
  EVT_CHECKBOX($this, $this->{win}, sub{$_[0]->replot(qw(q single))});
  $app->mouseover($this->{win}, "Plot the k-space window function when ploting the current group in filtered k-space.");

  SWITCH: {
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'm') and do {
	$this->{mag} ->SetValue(1);
	$this->{mmag}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'e') and do {
	$this->{env} ->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'r') and do {
	$this->{re} ->SetValue(1);
	$this->{mre}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'i') and do {
	$this->{im} ->SetValue(1);
	$this->{mim}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'p') and do {
	$this->{pha} ->SetValue(1);
	$this->{mpha}->SetValue(1);
	last SWITCH;
      };
    };

  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "single")) )
    foreach (qw(mag env re im pha win));
  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "marked")) )
    foreach (qw(mmag mre mim mpha));

  #$hbox -> Add(0, 0, 1);

  #my $right = Wx::BoxSizer->new( wxVERTICAL );
  #$hbox -> Add($right, 0, wxALL, 4);

  $box -> Add(1, 1, 1);

  my $range = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($range, 0, wxALL|wxGROW, 0);
  my $label = Wx::StaticText->new($this, -1, "qmin", wxDefaultPosition, [35,-1]);
  $this->{qmin} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "qmin"),
				     wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{qmin}, 1, wxRIGHT, 10);
  $label = Wx::StaticText->new($this, -1, "qmax", wxDefaultPosition, [35,-1]);
  $this->{qmax} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "qmax"),
				     wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{qmax}, 1, wxRIGHT, 10);

  foreach my $x (qw(qmin qmax)) {
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
  $app->plot(q{}, q{}, 'q', $how);
};

sub label {
  return 'Plot in q-space';
};


sub pull_single_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;

  my $qmin = $this->{qmin}-> GetValue;
  my $qmax = $this->{qmax}-> GetValue;
  $::app->{main}->status(q{}, 'nobuffer');
  $qmin = 0,  $::app->{main}->status("qmin is not a number", 'error|nobuffer') if not looks_like_number($qmin);
  $qmax = 15, $::app->{main}->status("qmax is not a number", 'error|nobuffer') if not looks_like_number($qmax);
  $po->qmin($qmin);
  $po->qmax($qmax);
};

sub pull_marked_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  my $val = ($this->{mmag} -> GetValue) ? 'm'
          : ($this->{mre}  -> GetValue) ? 'r'
          : ($this->{mim}  -> GetValue) ? 'i'
          : ($this->{mpha} -> GetValue) ? 'p'
	  :                               'm';
  $po->q_pl($val);

  my $qmin = $this->{qmin}-> GetValue;
  my $qmax = $this->{qmax}-> GetValue;
  $::app->{main}->status(q{}, 'nobuffer');
  $qmin = 0,  $::app->{main}->status("qmin is not a number", 'error|nobuffer') if not looks_like_number($qmin);
  $qmax = 15, $::app->{main}->status("qmax is not a number", 'error|nobuffer') if not looks_like_number($qmax);
  $po->qmin($qmin);
  $po->qmax($qmax);
};

1;



=head1 NAME

Demeter::UI::Athena::Plot::PlotQ - q-space plotting controls

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module provides controls for plotting in q space in Athena

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
