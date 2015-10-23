package Demeter::UI::Athena::Plot::PlotE;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::Replot;

use Scalar::Util qw(looks_like_number);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slots = Wx::GridSizer->new( 7, 2, 0, 1 );
  $hbox -> Add($slots, 0, wxGROW|wxALL, 0);
  $this->{mu} = Wx::CheckBox->new($this, -1, $MU.'(E)', wxDefaultPosition, wxDefaultSize);
  $this->{mu} -> SetValue(Demeter->co->default("plot", "e_mu"));
  $slots -> Add($this->{mu}, 1, wxGROW|wxALL, 0);
  $this->{mmu} = Wx::RadioButton->new($this, -1, $MU.'(E)', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $this->{mmu} -> SetValue(Demeter->co->default("plot", "e_mu"));
  $slots -> Add($this->{mmu}, 1, wxGROW|wxALL, 0);
  EVT_CHECKBOX($this, $this->{mu}, sub{$_[0]->replot(qw(E single))});
  EVT_RADIOBUTTON($this, $this->{mmu}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{mu},  "Plot $MU(E) when ploting the current group in energy.");
  $app->mouseover($this->{mmu}, "Plot $MU(E) when ploting the marked groups in energy.");

  $this->{bkg} = Wx::CheckBox->new($this, -1, 'Background', wxDefaultPosition, wxDefaultSize);
  $this->{bkg} -> SetValue(Demeter->co->default("plot", "e_bkg"));
  $slots -> Add($this->{bkg}, 1, wxGROW|wxALL, 0);
  EVT_CHECKBOX($this, $this->{bkg},
	       sub{my ($this, $event) = @_;
		   if ($this->{bkg}->GetValue) {
		     $this->{der}->SetValue(0);
		     $this->{sec}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_CHECKBOX($this, $this->{mbkg}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{bkg},  "Plot the background when ploting the current group in energy.");
  $slots -> Add(Wx::StaticText->new($this, -1, q{}), 0, wxGROW|wxALL, 0);

  $this->{pre} = Wx::CheckBox->new($this, -1, 'pre-edge line', wxDefaultPosition, wxDefaultSize);
  $this->{pre} -> SetValue(Demeter->co->default("plot", "e_pre"));
  $slots -> Add($this->{pre}, 1, wxGROW|wxALL, 0);
  EVT_CHECKBOX($this, $this->{pre},
	       sub{my ($this, $event) = @_;
		   if ($this->{pre}->GetValue) {
		     $this->{norm}->SetValue(0);
		     $this->{der}->SetValue(0);
		     $this->{sec}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  $app->mouseover($this->{pre},  "Plot the pre-edge line when ploting the current group in energy.");
  $slots -> Add(Wx::StaticText->new($this, -1, q{}), 0, wxGROW|wxALL, 0);

  $this->{post} = Wx::CheckBox->new($this, -1, 'post-edge line', wxDefaultPosition, wxDefaultSize);
  $this->{post} -> SetValue(Demeter->co->default("plot", "e_post"));
  $slots -> Add($this->{post}, 1, wxGROW|wxALL, 0);
  EVT_CHECKBOX($this, $this->{post},
	       sub{my ($this, $event) = @_;
		   if ($this->{post}->GetValue) {
		     $this->{norm}->SetValue(0);
		     $this->{der}->SetValue(0);
		     $this->{sec}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  $app->mouseover($this->{post},  "Plot the post-edge line when ploting the current group in energy.");
  $slots -> Add(Wx::StaticText->new($this, -1, q{}), 0, wxGROW|wxALL, 0);

  $this->{norm} = Wx::CheckBox->new($this, -1, 'Normalized', wxDefaultPosition, wxDefaultSize);
  $this->{norm} -> SetValue(Demeter->co->default("plot", "e_norm"));
  $slots -> Add($this->{norm}, 1, wxGROW|wxALL, 0);
  $this->{mnorm} = Wx::RadioButton->new($this, -1, 'Normalized', wxDefaultPosition, wxDefaultSize);
  $this->{mnorm} -> SetValue(Demeter->co->default("plot", "e_norm"));
  $slots -> Add($this->{mnorm}, 1, wxGROW|wxALL, 0);
  EVT_CHECKBOX($this, $this->{norm},
	       sub{my ($this, $event) = @_;
		   if ($this->{norm}->GetValue) {
		     $this->{pre}->SetValue(0);
		     $this->{post}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_RADIOBUTTON($this, $this->{mnorm}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{norm},  "Plot normalized data when ploting the current group in energy.");
  $app->mouseover($this->{mnorm}, "Plot normalized data when ploting the marked groups in energy.");

  $this->{der} = Wx::CheckBox->new($this, -1, 'Derivative', wxDefaultPosition, wxDefaultSize);
  $this->{der} -> SetValue(Demeter->co->default("plot", "e_der"));
  $slots -> Add($this->{der}, 1, wxGROW|wxALL, 0);
  $this->{mder} = Wx::CheckBox->new($this, -1, 'Derivative', wxDefaultPosition, wxDefaultSize);
  $this->{mder} -> SetValue(Demeter->co->default("plot", "e_der"));
  $slots -> Add($this->{mder}, 1, wxGROW|wxALL, 0);
  EVT_CHECKBOX($this, $this->{der},
	       sub{my ($this, $event) = @_;
		   if ($this->{der}->GetValue) {
		     $this->{bkg}->SetValue(0);
		     $this->{pre}->SetValue(0);
		     $this->{post}->SetValue(0);
		     $this->{sec}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_CHECKBOX($this, $this->{mder},
	       sub{my ($this, $event) = @_;
		   if ($this->{mder}->GetValue) {
		     $this->{msec}->SetValue(0);
		   };
		   $this->replot(qw(E marked))
		 });
  $app->mouseover($this->{der},  "Plot first derivative data when ploting the current group in energy.");
  $app->mouseover($this->{mder}, "Plot first derivative data when ploting the marked groups in energy.");

  $this->{sec} = Wx::CheckBox->new($this, -1, '2nd derivative', wxDefaultPosition, wxDefaultSize);
  $this->{sec} -> SetValue(Demeter->co->default("plot", "e_sec"));
  $slots -> Add($this->{sec}, 1, wxGROW|wxALL, 0);
  $this->{msec} = Wx::CheckBox->new($this, -1, '2nd derivative', wxDefaultPosition, wxDefaultSize);
  $this->{msec} -> SetValue(Demeter->co->default("plot", "e_sec"));
  $slots -> Add($this->{msec}, 1, wxGROW|wxALL, 0);
  EVT_CHECKBOX($this, $this->{sec},
	       sub{my ($this, $event) = @_;
		   if ($this->{sec}->GetValue) {
		     $this->{bkg}->SetValue(0);
		     $this->{pre}->SetValue(0);
		     $this->{post}->SetValue(0);
		     $this->{der}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_CHECKBOX($this, $this->{msec},
	       sub{my ($this, $event) = @_;
		   if ($this->{msec}->GetValue) {
		     $this->{mder}->SetValue(0);
		   };
		   $this->replot(qw(E marked))
		 });
  $app->mouseover($this->{sec},  "Plot second derivative data when ploting the current group in energy.");
  $app->mouseover($this->{msec}, "Plot second derivative data when ploting the marked groups in energy.");

  $this->{mnorm}->SetValue(1);

  $this->{$_}->SetBackgroundColour( Wx::Colour->new(Demeter->co->default("athena", "single")) )
    foreach (qw(mu bkg pre post norm der sec));
  $this->{$_}->SetBackgroundColour( Wx::Colour->new(Demeter->co->default("athena", "marked")) )
    foreach (qw(mmu mnorm mder msec));

#  my $right = Wx::BoxSizer->new( wxVERTICAL );
#  $hbox -> Add($right, 0, wxALL, 4);

  $box -> Add(1, 1, 1);

  my $range = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($range, 0, wxALL|wxGROW, 0);
  my $label = Wx::StaticText->new($this, -1, "Emin", wxDefaultPosition, wxDefaultSize);
  $this->{emin} = Wx::TextCtrl ->new($this, -1, Demeter->co->default("plot", "emin"),
				     wxDefaultPosition, [40,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{emin}, 1, wxRIGHT, 10);
  $label = Wx::StaticText->new($this, -1, "Emax", wxDefaultPosition, wxDefaultSize);
  $this->{emax} = Wx::TextCtrl ->new($this, -1, Demeter->co->default("plot", "emax"),
				     wxDefaultPosition, [40,-1], wxTE_PROCESS_ENTER);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{emax}, 1, wxRIGHT, 5);

  foreach my $x (qw(emin emax)) {
    $this->{$x} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
    EVT_TEXT_ENTER($this, $this->{$x}, sub{OnTextEnter(@_, $::app, $x)});
  };

  $this->SetSizerAndFit($box);
  return $this;
};

sub OnTextEnter {
  my ($main, $event, $app, $which) = @_;
  my @list = $app->marked_groups;
  my $how = (@list) ? 'marked' : 'single';
  $app->plot(q{}, q{}, 'E', $how);
};

sub label {
  return 'Plot in energy';
};


sub pull_single_values {
  my ($this) = @_;
  my $po = Demeter->po;
  $po->e_mu  ($this->{mu}  -> GetValue);
  $po->e_bkg ($this->{bkg} -> GetValue);
  $po->e_pre ($this->{pre} -> GetValue);
  $po->e_post($this->{post}-> GetValue);
  $po->e_norm($this->{norm}-> GetValue);
  $po->e_der ($this->{der} -> GetValue);
  $po->e_sec ($this->{sec} -> GetValue);

  my $emin = $this->{emin}-> GetValue;
  my $emax = $this->{emax}-> GetValue;
  ($emin,$emax) = sort {$a <=> $b} ($emin,$emax);
  $::app->{main}->status(q{}, 'nobuffer');
  if (not looks_like_number($emin)) {
    $emin = Demeter->co->default('plot','emin');
    $::app->{main}->status("Emin is not a number", 'error|nobuffer');
  };
  if (not looks_like_number($emax)) {
    $emax = Demeter->co->default('plot','emax');
    $::app->{main}->status("Emax is not a number", 'error|nobuffer');
  };
  $po->emin($emin);
  $po->emax($emax);

  $po->e_markers(1);
};

sub pull_marked_values {
  my ($this) = @_;
  my $po = Demeter->po;
  $po->e_mu  ($this->{mmu}  -> GetValue);
  $po->e_bkg (0);
  $po->e_pre (0);
  $po->e_post(0);
  $po->e_norm($this->{mnorm}-> GetValue);
  $po->e_der ($this->{mder} -> GetValue);
  $po->e_sec ($this->{msec} -> GetValue);

  my $emin = $this->{emin}-> GetValue;
  my $emax = $this->{emax}-> GetValue;
  ($emin,$emax) = sort {$a <=> $b} ($emin,$emax);
  $::app->{main}->status(q{}, 'nobuffer');
  if (not looks_like_number($emin)) {
    $emin = Demeter->co->default('plot','emin');
    $::app->{main}->status("Emin is not a number", 'error|nobuffer');
  };
  if (not looks_like_number($emax)) {
    $emax = Demeter->co->default('plot','emax');
    $::app->{main}->status("Emax is not a number", 'error|nobuffer');
  };
  $po->emin($emin);
  $po->emax($emax);

  $po->e_mu(1) if $po->e_norm;
  $po->e_markers(0);
};

1;

=head1 NAME

Demeter::UI::Athena::Plot::PlotE - energy space plotting controls

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This module provides controls for plotting in energy in Athena

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
