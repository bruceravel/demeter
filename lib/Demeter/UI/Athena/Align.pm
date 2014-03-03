package Demeter::UI::Athena::Align;
use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHOICE EVT_COMBOBOX EVT_TEXT EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;
use Scalar::Util qw(looks_like_number);


use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Align data";

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );
  $this->{sizer}  = $box;

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  my $label = Wx::StaticText->new($this, -1, "Aligning");
  $gbs->Add($label, Wx::GBPosition->new(0,0));
  $label = Wx::StaticText->new($this, -1, "Standard");
  $gbs->Add($label, Wx::GBPosition->new(1,0));
  $label = Wx::StaticText->new($this, -1, "Plot as");
  $gbs->Add($label, Wx::GBPosition->new(2,0));
  $label = Wx::StaticText->new($this, -1, "Fit as");
  $gbs->Add($label, Wx::GBPosition->new(3,0));

  $this->{this}     = Wx::StaticText->new($this, -1, q{Group});
  $this->{standard} = Demeter::UI::Athena::GroupList -> new($this, $app, 1);
  #$this->{standard} = Wx::ComboBox->new($this, -1, q{}, wxDefaultPosition, [165,-1], [], wxCB_READONLY);
  $this->{plotas}   = Wx::Choice->new($this, -1, wxDefaultPosition, [165,-1],
				      ["$MU(E)", 'norm(E)', 'deriv(E)', 'smoothed deriv(E)']);
  $this->{fitas}    = Wx::Choice->new($this, -1, wxDefaultPosition, [165,-1],
				      ['deriv(E)', 'smoothed deriv(E)']);

  $this->{plotas} -> SetSelection(3);
  $this->{fitas}  -> SetSelection(1);

  $gbs->Add($this->{this},     Wx::GBPosition->new(0,1));
  $gbs->Add($this->{standard}, Wx::GBPosition->new(1,1));
  $gbs->Add($this->{plotas},   Wx::GBPosition->new(2,1));
  $gbs->Add($this->{fitas},    Wx::GBPosition->new(3,1));

  EVT_CHOICE($this, $this->{plotas}, sub{$this->plot($app->current_data)});
  EVT_COMBOBOX($this, $this->{standard}, sub{$this->plot($app->current_data)});

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10);

  my @ps  = (wxDefaultPosition, [80, -1]);
  my @ps2 = (wxDefaultPosition, [165,-1]);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10);
  $this->{shiftlabel} = Wx::StaticText->new($this, -1, "Shift by");
  $this->{shift}      = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{units}      = Wx::StaticText->new($this, -1, "eV     ");
  $this->{errorlabel} = Wx::StaticText->new($this, -1, "Uncertainty");
  $this->{error}      = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, $tcsize, wxTE_READONLY);
  $hbox->Add($this->{shiftlabel}, 0, wxALL,          4);
  $hbox->Add($this->{shift},      0, wxLEFT|wxRIGHT, 2);
  $hbox->Add($this->{units},      0, wxALL,          4);
  $hbox->Add($this->{errorlabel}, 0, wxALL,          4);
  $hbox->Add($this->{error},      0, wxLEFT|wxRIGHT, 2);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 0);
  $this->{replot}     = Wx::Button->new($this, -1, "Replot", @ps2);
  $hbox->Add($this->{replot},     0, wxALL,         3);


  $this->{shift} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
  EVT_TEXT($this, $this->{shift}, sub{OnShift(@_, $app->current_data)});
  EVT_TEXT_ENTER($this, $this->{shift}, sub{$this->plot($app->current_data)});
  EVT_BUTTON($this, $this->{replot}, sub{$this->plot($app->current_data)});

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{auto}   = Wx::Button->new($this, -1, "Auto align", @ps2);
  $this->{marked} = Wx::Button->new($this, -1, "Align marked groups", @ps2);
  $this->{m5}     = Wx::Button->new($this, -1, "-5",     @ps);
  $this->{p5}     = Wx::Button->new($this, -1, "+5",     @ps);
  $this->{m1}     = Wx::Button->new($this, -1, "-1",     @ps);
  $this->{p1}     = Wx::Button->new($this, -1, "+1",     @ps);
  $this->{mhalf}  = Wx::Button->new($this, -1, "-0.5",   @ps);
  $this->{phalf}  = Wx::Button->new($this, -1, "+0.5",   @ps);
  $this->{mtenth} = Wx::Button->new($this, -1, "-0.1",   @ps);
  $this->{ptenth} = Wx::Button->new($this, -1, "+0.1",   @ps);

  $gbs->Add($this->{auto},   Wx::GBPosition->new(0,0), Wx::GBSpan->new(1,2));
  $gbs->Add($this->{marked}, Wx::GBPosition->new(0,2));
  $gbs->Add($this->{m5},     Wx::GBPosition->new(1,0));
  $gbs->Add($this->{p5},     Wx::GBPosition->new(1,1));
  $gbs->Add($this->{m1},     Wx::GBPosition->new(2,0));
  $gbs->Add($this->{p1},     Wx::GBPosition->new(2,1));
  $gbs->Add($this->{mhalf},  Wx::GBPosition->new(3,0));
  $gbs->Add($this->{phalf},  Wx::GBPosition->new(3,1));
  $gbs->Add($this->{mtenth}, Wx::GBPosition->new(4,0));
  $gbs->Add($this->{ptenth}, Wx::GBPosition->new(4,1));

  EVT_BUTTON($this, $this->{auto},   sub{$this->autoalign($app->current_data, 'this')});
  EVT_BUTTON($this, $this->{marked}, sub{$this->autoalign($app->current_data, 'marked')});
  EVT_BUTTON($this, $this->{m5},     sub{$this->add($app->current_data, -5  )});
  EVT_BUTTON($this, $this->{p5},     sub{$this->add($app->current_data,  5  )});
  EVT_BUTTON($this, $this->{m1},     sub{$this->add($app->current_data, -1  )});
  EVT_BUTTON($this, $this->{p1},     sub{$this->add($app->current_data,  1  )});
  EVT_BUTTON($this, $this->{mhalf},  sub{$this->add($app->current_data, -0.5)});
  EVT_BUTTON($this, $this->{phalf},  sub{$this->add($app->current_data,  0.5)});
  EVT_BUTTON($this, $this->{mtenth}, sub{$this->add($app->current_data, -0.1)});
  EVT_BUTTON($this, $this->{ptenth}, sub{$this->add($app->current_data,  0.1)});

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10);

  $box->Add(1,1,1);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: alignment');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.align")});

  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  1;
};
sub push_values {
  my ($this, $data) = @_;
  $this->{this}  -> SetLabel($data->name);
  ##$this->{shiftlabel} -> SetLabel("Shift " . $data->name . " by");
  $this->{shift} -> SetValue($data->bkg_eshift);
  $this->{error} -> SetEditable(1);
  $this->{error} -> SetValue($data->bkg_delta_eshift);
  $this->{error} -> SetEditable(0);
  my $count = 0;
  foreach my $i (0 .. $::app->{main}->{list}->GetCount - 1) {
    my $data = $::app->{main}->{list}->GetIndexedData($i);
    ++$count if $data->datatype ne 'chi';
  };
  $this->Enable(1);
  if ($count < 2) {
    $this->Enable(0);
    return;
  };
  if ($data->datatype eq 'chi') {
    $this->Enable(0);
    return;
  };
  my $was = $this->{standard}->GetStringSelection;
  $this->{standard}->fill($::app, 1, 1);
  ((not $was) or ($was eq 'None')) ? $this->{standard}->SetSelection(0) : $this->{standard}->SetStringSelection($was);
  $this->{standard}->SetSelection(0) if not defined($this->{standard}->GetClientData($this->{standard}->GetSelection));
  return if $::app->{plotting};
  return if ($this->{standard}->GetStringSelection eq 'None');
  my $stan = $this->{standard}->GetClientData($this->{standard}->GetSelection);
  if (not defined($stan) or ($stan->group eq $data->group)) {
    $::app->{main}->status("Not plotting -- the data and standard are the same!", 'error|nobuffer');
    return;
  } else {
    $this->plot($data);
  };
};
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnShift {
  my ($this, $event, $data) = @_;
  return if not looks_like_number($this->{shift}->GetValue);
  $data->bkg_eshift($this->{shift}->GetValue);
};
sub add {
  my ($this, $data, $amount) = @_;
  my $shift = $this->{shift}->GetValue;
  $this->{shift}->SetValue($shift+$amount);
  $this->{error}->SetValue(0);
  $data->bkg_delta_eshift(0);
  $this->plot($data);
  $::app->modified(1);
};

sub autoalign {
  my ($this, $data, $how) = @_;
  my $busy = Wx::BusyCursor->new();
  my $save = $data->po->e_smooth;
  my $stan = $this->{standard}->GetClientData($this->{standard}->GetSelection);

  if (($how eq 'this') and ($data eq $stan)) {
    $::app->{main}->status("Not aligning -- the data and standard are the same!", 'error|nobuffer');
    return;
  };

  if (not looks_like_number($this->{shift}->GetValue)) {
    $::app->{main}->status("Not aligning -- your shift value cannot be interpreted as a number", 'error|nobuffer');
    return;
  };

  my @all = ($data);
  if ($how eq 'marked') {
    @all = ();
    foreach my $i (0 .. $::app->{main}->{list}->GetCount - 1) {
      next if ($::app->{main}->{list}->GetIndexedData($i) eq $stan);
      push(@all, $::app->{main}->{list}->GetIndexedData($i))
	if $::app->{main}->{list}->IsChecked($i);
    };
    $stan->sentinal(sub{$this->alignment_sentinal});
  };
  $data->po->set(e_smooth=>0);
  $data->po->set(e_smooth=>3) if ($this->{fitas}->GetSelection == 1);
  $stan->align(@all);
  undef $busy;
  $this->{shift}->SetValue($data->bkg_eshift);
  $this->{error}->SetEditable(1);
  $this->{error}->SetValue($data->bkg_delta_eshift);
  $this->{error}->SetEditable(0);
  $this->plot($data);
  $data->po->e_smooth($save);
  $::app->modified(1);
};

sub alignment_sentinal {
  $::app->{main}->status("Aligning " . $::app->current_data->mo->current->name, 'nobuffer');
};

sub plot {
  my ($this, $data) = @_;
  my $busy = Wx::BusyCursor->new();
  my @sg = ($data->co->default("smooth", "sg_size"), $data->co->default("smooth", "sg_order"));
  $data->co->set_default("smooth", "sg_size", 21);
  $data->co->set_default("smooth", "sg_order", 4);

  my $save = $data->po->e_smooth;
  my $stan = $this->{standard}->GetClientData($this->{standard}->GetSelection);
  if (not defined($stan) or ($stan->group eq $data->group)) {
    $::app->{main}->status("Not plotting -- the data and standard are the same!", 'error|nobuffer');
    return;
  };

  if (not looks_like_number($this->{shift}->GetValue)) {
    $::app->{main}->status("Not plotting -- your shift value cannot be interpreted as a number", 'error|nobuffer');
    return;
  };

  $data->po->set(emin=>-30, emax=>50);
  $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0, e_smooth=>0);
  $data->po->e_norm(1) if ($this->{plotas}->GetSelection == 1);
  $data->po->e_der(1)  if ($this->{plotas}->GetSelection == 2);
  $data->po->set(e_der=>1, e_smooth=>3)  if ($this->{plotas}->GetSelection == 3);
  $data->po->start_plot;
  $_->plot('e') foreach ($stan, $data);

  $data->co->set_default("smooth", "sg_size",  $sg[0]);
  $data->co->set_default("smooth", "sg_order", $sg[1]);
  $data->po->e_smooth($save);
  $::app->{main}->status("Plotted ".$stan->name." and ".$data->name, 'nobuffer');
  undef $busy;
};

1;


=head1 NAME

Demeter::UI::Athena::Align - An alignment tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

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
