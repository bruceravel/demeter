package Demeter::UI::Athena::Difference;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);
use Wx::Perl::TextValidator;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use File::Basename;
use Scalar::Util qw(looks_like_number);

use vars qw($label);
$label = "Difference spectra of normalized $MU(E)";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize   = [60,-1];
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{Diff} = Demeter::Diff->new;
  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  my $label = Wx::StaticText->new($this, -1, "Standard");
  $gbs->Add($label, Wx::GBPosition->new(0,0));
  $label = Wx::StaticText->new($this, -1, "Data");
  $gbs->Add($label, Wx::GBPosition->new(1,0));

  $this->{standard} = Demeter::UI::Athena::GroupList -> new($this, $app, 1);
  $this->{data}     = Wx::StaticText->new($this, -1, q{Group});
  $gbs->Add($this->{standard}, Wx::GBPosition->new(0,1));
  $gbs->Add($this->{data},     Wx::GBPosition->new(1,1));

  $this->{invert}  = Wx::CheckBox->new($this, -1, 'Invert difference spectrum');
  $this->{plotspectra} = Wx::CheckBox->new($this, -1, 'Plot data and standard with difference');
  $gbs->Add($this->{invert},  Wx::GBPosition->new(2,0), Wx::GBSpan->new(1,2));
  $gbs->Add($this->{plotspectra}, Wx::GBPosition->new(3,0), Wx::GBSpan->new(1,2));

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  $hbox->Add(Wx::StaticText->new($this, -1, 'Integration range'), 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmin} = Wx::TextCtrl->new($this, -1, $this->{Diff}->xmin);
  $hbox->Add($this->{xmin}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmin_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{xmin_pluck}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 1);
  $hbox->Add(Wx::StaticText->new($this, -1, 'to'), 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmax} = Wx::TextCtrl->new($this, -1, $this->{Diff}->xmax);
  $hbox->Add($this->{xmax}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmax_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{xmax_pluck}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 1);

  $this->{xmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
  $this->{xmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );

  $box -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox->Add(Wx::StaticText->new($this, -1, 'Integrated area'), 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{area} = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $hbox->Add($this->{area}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $box -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $this->{plot}        = Wx::Button->new($this, -1, 'Plot difference spectrum', wxDefaultPosition, $tcsize);
  $this->{make}        = Wx::Button->new($this, -1, 'Make difference group',    wxDefaultPosition, $tcsize);
  $this->{marked}      = Wx::Button->new($this, -1, 'Plot difference spectra for all marked groups', wxDefaultPosition, $tcsize);
  $this->{markedareas} = Wx::Button->new($this, -1, 'Plot integrated areas from all marked groups', wxDefaultPosition, $tcsize);
  $this->{markedmake}  = Wx::Button->new($this, -1, 'Make difference groups from all marked groups', wxDefaultPosition, $tcsize);
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 2) foreach (qw(plot make marked markedareas markedmake));
  $this->{$_}->Enable(0) foreach (qw(make marked markedareas markedmake));
  EVT_BUTTON($this, $this->{plot},    sub{$this->plot});

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: difference spectra');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("diff")});

  $this->SetSizerAndFit($box);
  return $this;
};

## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  $this->{data}  -> SetLabel($data->name);
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
  ($was eq 'None') ? $this->{standard}->SetSelection(0) : $this->{standard}->SetStringSelection($was);
  $this->{standard}->SetSelection(0) if not defined($this->{standard}->GetClientData($this->{standard}->GetSelection));
  $data->po->start_plot;
  $data->po->set(emin=>$this->{Diff}->xmin-10, emax=>$this->{Diff}->xmax+20);
  $data->po->set(e_mu=>1, e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0, e_smooth=>0);
  $this->{make}->Enable(0);
  my $save = $this->{plotspectra}->GetValue;
  $this->{plotspectra}->SetValue(1);
  $this->plot;
  $this->{plotspectra}->SetValue($save);
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub plot {
  my ($this) = @_;
  foreach my $att (qw(xmin xmax invert plotspectra)) {
    next if (($att =~ m{\Axm}) and (not looks_like_number($this->{$att}->GetValue)));
    $this->{Diff}->$att($this->{$att}->GetValue);
  };
  $this->{Diff}->data($::app->current_data);
  $this->{Diff}->standard($this->{standard}->GetClientData($this->{standard}->GetSelection));
  $this->{Diff}->diff;
  $this->{area}->SetValue(sprintf("%.5f",$this->{Diff}->area));
  $this->{Diff}->po->set(emin=>$this->{Diff}->xmin-10, emax=>$this->{Diff}->xmax+20, space=>'E');
  $this->{Diff}->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0, e_smooth=>0);
  $this->{Diff}->po->start_plot;
  $this->{Diff}->plot;
  $this->{make}->Enable(1);
};

1;


=head1 NAME

Demeter::UI::Athena::Difference - A difference spectrum tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

This module provides a tool for computing difference spectra from
normalized mu(E) data, including the calculation of integrated area
under a portion of the difference spectrum.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

plucking

=item *

Marked groups functionality

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
