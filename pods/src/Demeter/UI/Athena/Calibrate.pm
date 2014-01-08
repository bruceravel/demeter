package Demeter::UI::Athena::Calibrate;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHOICE EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Scalar::Util qw(looks_like_number);
use Xray::Absorption;

use vars qw($label $tag);
$label = "Calibrate data";
$tag = 'Calibrate';

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{parent} = $parent;


  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $gbs->Add(Wx::StaticText->new($this, -1, 'Group'),        Wx::GBPosition->new(0,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Display'),      Wx::GBPosition->new(1,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Smoothing'),    Wx::GBPosition->new(2,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'E0'),           Wx::GBPosition->new(3,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Calibrate to'), Wx::GBPosition->new(4,0));

  $this->{group}   = Wx::StaticText->new($this, -1, q{});
  $this->{display} = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize,
				     ["$MU(E)", 'norm(E)', 'deriv(E)', 'second(E)']);
  $this->{smooth}  = Wx::SpinCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS|wxTE_PROCESS_ENTER, 0, 10);
  $this->{e0}      = Wx::TextCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{cal}     = Wx::TextCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);

  $gbs->Add($this->{group},   Wx::GBPosition->new(0,1));
  $gbs->Add($this->{display}, Wx::GBPosition->new(1,1));
  $gbs->Add($this->{smooth},  Wx::GBPosition->new(2,1));
  $gbs->Add($this->{e0},      Wx::GBPosition->new(3,1));
  $gbs->Add($this->{cal},     Wx::GBPosition->new(4,1));

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $this->{select}    = Wx::Button->new($this, -1, 'Select a point',      wxDefaultPosition, $tcsize);
  $this->{zero}      = Wx::Button->new($this, -1, 'Find zero crossing',  wxDefaultPosition, $tcsize);
  $this->{replot}    = Wx::Button->new($this, -1, 'Replot',              wxDefaultPosition, $tcsize);
  $this->{calibrate} = Wx::Button->new($this, -1, 'Calibrate',           wxDefaultPosition, $tcsize);
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 5) foreach (qw(select zero replot calibrate));

  EVT_CHOICE($this, $this->{display},   sub{$this->{zero}->Enable($this->{display}->GetSelection == 3); $this->plot($app->current_data)});
  EVT_BUTTON($this, $this->{replot},    sub{$this->plot($app->current_data)});
  EVT_BUTTON($this, $this->{zero},      sub{OnFindZeroCrossing(@_, $app)});
  EVT_BUTTON($this, $this->{select},    sub{Pluck(@_, $app)});
  EVT_BUTTON($this, $this->{calibrate}, sub{OnCalibrate(@_, $app)});
  foreach my $x (qw(smooth e0 cal)) {
    EVT_TEXT_ENTER($this, $this->{$x}, sub{$this->plot($app->current_data)});
  };

  $this->{e0}  -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
  $this->{cal} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );

  $box->Add(1,1,1);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: calibrate');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.cal")});

  $this->{display}->SetSelection(2);
  $this->{zero}->Enable(0);

  $app->{lastplot}=['E', 'single'];

  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  1;
};
sub push_values {
  my ($this, $data) = @_;
  $this->{group}->SetLabel($data->name);
  $this->{e0}->SetValue($data->bkg_e0);
  $this->{save} = $data->bkg_e0;
  $this->{cal}->SetValue(Xray::Absorption->get_energy($data->bkg_z, $data->fft_edge));
  $this->Enable(1);
  if ($data->datatype eq 'chi') {
    $this->Enable(0);
    return;
  };
  return if $::app->{plotting};
  $this->plot($data);
  1;
};
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnFindZeroCrossing {
  my ($this, $event, $app) = @_;
  my $data = $app->current_data;
  $data->e0('zero');
  $this->{e0}->SetValue($data->bkg_e0);
  $this->plot($data);
};

sub OnCalibrate {
  my ($this, $event, $app) = @_;
  if (not looks_like_number($this->{cal}->GetValue)) {
    $::app->{main}->status("Not calibrating -- your calibration value is not a number!", 'error|nobuffer');
    return;
  };
  my $data = $app->current_data;
  my $shift = sprintf("%.3f", $this->{cal}->GetValue - $data->bkg_e0 + $data->bkg_eshift);
  $data->bkg_eshift($shift);
  $data->bkg_e0($this->{cal}->GetValue);
  $this->{e0}->SetValue($data->bkg_e0);
  $app->{main}->status("Calbrated, setting e0 to ".$data->bkg_e0." and the energy shift to ".$data->bkg_eshift);
  $::app->modified(1);
};

sub plot {
  my ($this, $data) = @_;
  if (not looks_like_number($this->{e0}->GetValue)) {
    $::app->{main}->status("Not plotting -- your e0 value is not a number!", 'error|nobuffer');
    return;
  };
  my $save = $data->po->e_smooth;
  $data->bkg_e0($this->{e0}->GetValue);
  $data->po->set(emin=>-30, emax=>50, e_smooth=>$this->{smooth}->GetValue);
  $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  $data->po->e_norm(1) if ($this->{display}->GetSelection == 1);
  $data->po->e_der(1)  if ($this->{display}->GetSelection == 2);
  $data->po->e_sec(1)  if ($this->{display}->GetSelection == 3);
  $data->po->start_plot;
  $data->plot('e');
  $data->po->set(e_smooth=>$save);
};

sub Pluck {
  my ($this, $event, $app) = @_;
  my $on_screen = lc($app->{lastplot}->[0]);
  if ($on_screen ne 'e') {
    $this->plot($app->current_data);
  };
  my ($ok, $x, $y) = $app->cursor;
  if (not $ok) {
    $app->{main}->status("Failed to pluck a point from the plot.");
    return;
  };
  $this->{e0}->SetValue($x);
  $app->current_data->bkg_e0($x);
  $this->plot($app->current_data);
  $app->{main}->status("Plucked $x as the new E0 value.");
};

1;



=head1 NAME

Demeter::UI::Athena::Calibrate - A calibration tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

This module provides controls for calibrating mu(E) data.  Calibration
is the process of picking an edge energy and assigning a specific
value to that point.  As a consequence, calibration sets the C<bkg_e0>
and C<bkg_eshift> attributes of the data object.

=head1 CONFIGURATION

This simple tool has co configuration parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need to disable controls for chi(k) and frozen groups.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
