package Demeter::UI::Athena::Difference;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_TEXT EVT_TEXT_ENTER EVT_CHOICE EVT_CHECKBOX);
use Wx::Perl::TextValidator;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use File::Basename;
use Scalar::Util qw(looks_like_number);

use vars qw($label);
$label = "Difference spectra";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize   = [60,-1];
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);
my @forms = (qw(xmu norm der nder sec nsec)); #  chi

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{Diff} = Demeter::Diff->new;
  $this->{updatemarked} = 1;
  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  my $label = Wx::StaticText->new($this, -1, "Standard");
  $gbs->Add($label, Wx::GBPosition->new(0,0));
  $label = Wx::StaticText->new($this, -1, "Multiplier");
  $gbs->Add($label, Wx::GBPosition->new(1,0));
  $label = Wx::StaticText->new($this, -1, "Data");
  $gbs->Add($label, Wx::GBPosition->new(2,0));
  $label = Wx::StaticText->new($this, -1, "Form");
  $gbs->Add($label, Wx::GBPosition->new(3,0));
  $label = Wx::StaticText->new($this, -1, "Name template");
  $gbs->Add($label, Wx::GBPosition->new(4,0));

  $this->{standard}   = Demeter::UI::Athena::GroupList -> new($this, $app, 1);
  $this->{multiplier} = Wx::TextCtrl->new($this, -1, '1', wxDefaultPosition, [150,-1]);
  $this->{data}       = Wx::StaticText->new($this, -1, q{Group});
  $this->{form}       = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize,
					["$MU(E)", "normalized $MU(E)", "derivative $MU(E)",
					 "deriv. of normalized $MU(E)", "2nd derivative $MU(E)",
					 "2nd deriv. of normalized $MU(E)"]); # , "$CHI(k)"
  $this->{template}   = Wx::TextCtrl->new($this, -1, 'diff %d - %s', wxDefaultPosition, [150,-1]);
  $gbs->Add($this->{standard},   Wx::GBPosition->new(0,1));
  $gbs->Add($this->{multiplier}, Wx::GBPosition->new(1,1));
  $gbs->Add($this->{data},       Wx::GBPosition->new(2,1));
  $gbs->Add($this->{form},       Wx::GBPosition->new(3,1));
  $gbs->Add($this->{template},   Wx::GBPosition->new(4,1));
  $this->{form}->SetSelection(1);
  EVT_CHOICE($this, $this->{form}, \&OnChoice);
  EVT_TEXT($this, $this->{template}, sub{$this->{updatemarked} = 1});
  $this->{template}->SetFont( Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize,
					     wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" )) ;
  $::app->mouseover($this->{template}, 'TOKENS: %d=data name; %s=standard name; %f=form; %m=multiplier; %n=xmin; %x=xmax; %a=area');

  $this->{invert}  = Wx::CheckBox->new($this, -1, 'Invert difference spectrum');
  $this->{plotspectra} = Wx::CheckBox->new($this, -1, 'Plot data and standard with difference');
  $this->{make_nor} = Wx::CheckBox->new($this, -1, 'Allow difference group to be renormalized');
  $this->{do_integrate} = Wx::CheckBox->new($this, -1, 'Do integration');
  $gbs->Add($this->{invert},  Wx::GBPosition->new(5,0), Wx::GBSpan->new(1,2));
  $gbs->Add($this->{plotspectra}, Wx::GBPosition->new(6,0), Wx::GBSpan->new(1,2));
  $gbs->Add($this->{make_nor}, Wx::GBPosition->new(7,0), Wx::GBSpan->new(1,2));
  $gbs->Add($this->{do_integrate}, Wx::GBPosition->new(8,0), Wx::GBSpan->new(1,2));
  $this->{invert}->SetValue(0);
  $this->{plotspectra}->SetValue(1);
  $this->{make_nor}->SetValue(0);
  $this->{do_integrate}->SetValue(1);
  EVT_CHECKBOX($this, $this->{invert},       sub{$this->{updatemarked} = 1});
  EVT_CHECKBOX($this, $this->{make_nor},     sub{$this->{updatemarked} = 1});
  EVT_CHECKBOX($this, $this->{do_integrate}, \&ToggleIntegration);

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  $this->{xmin_label} = Wx::StaticText->new($this, -1, 'Integration range');
  $hbox->Add($this->{xmin_label}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmin} = Wx::TextCtrl->new($this, -1, $this->{Diff}->xmin, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $hbox->Add($this->{xmin}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmin_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{xmin_pluck}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 1);
  $this->{to} = Wx::StaticText->new($this, -1, 'to');
  $hbox->Add($this->{to}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmax} = Wx::TextCtrl->new($this, -1, $this->{Diff}->xmax, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $hbox->Add($this->{xmax}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{xmax_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{xmax_pluck}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 1);

  $this->{multiplier} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{xmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
  $this->{xmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
  EVT_BUTTON($this, $this->{xmin_pluck}, sub{Pluck(@_, $app, 'xmin')});
  EVT_BUTTON($this, $this->{xmax_pluck}, sub{Pluck(@_, $app, 'xmax')});
  EVT_TEXT($this, $this->{xmin},         sub{$this->{updatemarked} = 1});
  EVT_TEXT($this, $this->{xmax},         sub{$this->{updatemarked} = 1});
  EVT_TEXT_ENTER($this, $this->{xmin},   sub{$this->plot});
  EVT_TEXT_ENTER($this, $this->{xmax},   sub{$this->plot});


  $box -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{area_label} = Wx::StaticText->new($this, -1, 'Integrated area');
  $hbox->Add($this->{area_label}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $this->{area} = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $hbox->Add($this->{area}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTER, 5);
  $box -> Add($hbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $this->{plot}        = Wx::Button->new($this, -1, 'Plot difference spectrum', wxDefaultPosition, $tcsize);
  $this->{plotk}       = Wx::Button->new($this, -1, 'Plot difference spectrum in k', wxDefaultPosition, $tcsize);
  $this->{make}        = Wx::Button->new($this, -1, 'Make difference group',    wxDefaultPosition, $tcsize);
  $this->{marked}      = Wx::Button->new($this, -1, 'Plot difference spectra for all marked groups', wxDefaultPosition, $tcsize);
  $this->{markedareas} = Wx::Button->new($this, -1, 'Plot integrated areas from all marked groups', wxDefaultPosition, $tcsize);
  $this->{markedmake}  = Wx::Button->new($this, -1, 'Make difference groups from all marked groups', wxDefaultPosition, $tcsize);
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 2) foreach (qw(plot plotk make));
  $box -> Add(1,15,0);
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 2) foreach (qw(marked markedareas markedmake));
  $this->{$_}->Enable(0) foreach (qw(make marked markedareas markedmake));
  EVT_BUTTON($this, $this->{plot},        sub{$this->plot('E')});
  EVT_BUTTON($this, $this->{plotk},       sub{$this->plot('k')});
  EVT_BUTTON($this, $this->{make},        sub{$this->make});
  EVT_BUTTON($this, $this->{marked},      sub{$this->marked_spectra});
  EVT_BUTTON($this, $this->{markedareas}, sub{$this->marked_areas});
  EVT_BUTTON($this, $this->{markedmake},  sub{$this->marked_make});


  $box->Add(1,1,1);		# spacer

  $this->{document} = Wx::Button->new($this, -1, 'Document section: difference spectra');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("analysis.diff")});

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
  if ((not $was) or ($was eq 'None')) {
    $this->{standard}->SetSelection(0);
  } else {
    $this->{standard}->SetStringSelection($was);
    $this->{standard}->SetSelection(0) if not scalar $this->{standard}->GetSelection;
  };
  #($was eq 'None') ? $this->{standard}->SetSelection(0) : $this->{standard}->SetStringSelection($was);
  #$this->{standard}->SetSelection(0) if not defined($this->{standard}->GetClientData(scalar $this->{standard}->GetSelection));
  $data->po->start_plot;
  $data->po->set(emin=>$this->{Diff}->xmin-10, emax=>$this->{Diff}->xmax+20);
  $data->po->set(e_mu=>1, e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0, e_smooth=>0);
  $this->{make}->Enable(0);
  my $save = $this->{plotspectra}->GetValue;
  $this->{plotspectra}->SetValue(1);
  $this->plot if not $::app->{plotting};
  $this->{plotspectra}->SetValue($save);
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub ToggleIntegration {
  my ($this, $event) = @_;
  my $onoff = $this->{do_integrate}->GetValue;
  foreach my $w (qw(xmin_label xmin xmin_pluck to xmax xmax_pluck area area_label markedareas)) {
    $this->{$w}->Enable($onoff);
  };
  $this->{Diff}->do_integrate($onoff);
  $this->{updatemarked} = 1;
};

sub setup {
  my ($this, $data, $diff) = @_;
  $diff ||= $this->{Diff};
  foreach my $att (qw(xmin xmax invert plotspectra multiplier)) {
    next if (($att =~ m{\A(?:xm|mu)}) and (not looks_like_number($this->{$att}->GetValue)));
    $diff->$att($this->{$att}->GetValue);
  };
  my $form = $forms[$this->{form}->GetSelection];
  $diff->data($data);
  $diff->space($form);
  $diff->standard($this->{standard}->GetClientData(scalar $this->{standard}->GetSelection));
  $diff->name_template($this->{template}->GetValue);
  $diff->diff;
  Demeter->po->set(emin=>$diff->xmin-20, emax=>$diff->xmax+30, space=>'E');
  Demeter->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_i0=>0, e_signal=>0, e_smooth=>0);
  if ($this->{form}->GetSelection == 0) {			# mu(E)
    Demeter->po->set(e_norm=>0, e_der=>0, e_sec=>0,);
  } elsif ($this->{form}->GetSelection == 1) {			# norm(E)
    Demeter->po->set(e_norm=>1, e_der=>0, e_sec=>0,);
  } elsif ($this->{form}->GetSelection == 2) {			# deriv(E)
    Demeter->po->set(e_norm=>0, e_der=>1, e_sec=>0,);
  } elsif ($this->{form}->GetSelection == 3) {			# deriv(norm(E))
    Demeter->po->set(e_norm=>1, e_der=>1, e_sec=>0,);
  } elsif ($this->{form}->GetSelection == 4) {			# sec(E)
    Demeter->po->set(e_norm=>0, e_der=>0, e_sec=>1,);
  } elsif ($this->{form}->GetSelection == 5) {			# sec(norm(E))
    Demeter->po->set(e_norm=>1, e_der=>0, e_sec=>1,);
  };
};

sub plot {
  my ($this, $space) = @_;
  $this->setup($::app->current_data);
  $this->{area}->SetValue(sprintf("%.5f",$this->{Diff}->area));

  Demeter->po->start_plot;
  $this->{Diff}->is_nor(not $this->{make_nor}->GetValue);
  $this->{Diff}->plot($space);
  $::app->{lastplot} = [$space, 'single'];
  $this->{$_}->Enable(1) foreach (qw(make marked markedareas markedmake));
  $::app->heap_check(0);
};

sub OnChoice {
  my ($this, $event) = @_;
  $this->plot;
  $this->{make_nor}->SetValue($this->{form}->GetSelection == 0);
};

sub make {
  my ($this, $diff, $at_end) = @_;
  $diff   ||= $this->{Diff};
  $at_end ||= 0;

  $diff->name_template($this->{template}->GetValue);
  $diff->is_nor(not $this->{make_nor}->GetValue);
  $diff->datatype('xanes');
  $diff->datatype('xmu') if ($this->{form}->GetSelection == 0);
  my $data = $diff->make_group;
  my $index = $::app->current_index;
  if ($at_end) {
    $::app->{main}->{list}->AddData($data->name, $data);
  } elsif ($index == $::app->{main}->{list}->GetCount-1) {
    $::app->{main}->{list}->AddData($data->name, $data);
  } else {
    $::app->{main}->{list}->InsertData($data->name, $index+1, $data);
  };
  $::app->{main}->status("Made new difference group, ".$data->name);
  $::app->modified(1);
  $::app->heap_check(0);
  $data->update_norm(1);
};

sub Pluck {
  my ($this, $event, $app, $which) = @_;
  my $on_screen = lc($app->{lastplot}->[0]);
  if ($on_screen ne 'e') {
    $app->{main}->status("Cannot pluck for energy from a $on_screen plot.");
    return;
  };
  my ($ok, $x, $y) = $app->cursor;
  $app->{main}->status("Failed to pluck cursor value."), return if not $ok;
  my $data = $app->current_data;
  my $plucked = sprintf("%.3f", $x - $data->bkg_e0);
  $this->{$which}->SetValue($plucked);
  $this->plot;
  $app->{main}->status("Plucked $plucked for $which");
};

sub marked {
  my ($this) = @_;
  my $save = $this->{Diff};

  my @all = ();
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    next if (not $::app->{main}->{list}->IsChecked($i));
    my $data = $::app->{main}->{list}->GetIndexedData($i);
    $::app->{main}->status("Computing difference from ".$data->name);
    my $new = Demeter::Diff->new;
    $new->invert($save->invert);
    #$this->{Diff} = $new;
    $this->setup($data, $new);
    push @all, $new;
  };
  #$this->{Diff} = $save;
  $this->{updatemarked} = 0;
  $this->{cachemarked} = \@all;
  return @all;
};

sub marked_spectra {
  my ($this) = @_;
  my $busy = Wx::BusyCursor->new();
  my @all = ($this->{updatemarked}) ? $this->marked : @{$this->{cachemarked}};
  Demeter->po->start_plot;
  Demeter->po->title("Sequence of difference spectra");
  foreach my $d (@all) {
    $d->plotspectra(0);
    $d->plotindicators(0);
    $d->name($d->data->name);
    $d->plot;
  };
  $::app->{main}->status("Plotted sequence of difference spectra");
  undef $busy;
};
sub marked_areas {
  my ($this) = @_;
  my $busy = Wx::BusyCursor->new();
  my @all = ($this->{updatemarked}) ? $this->marked : @{$this->{cachemarked}};
  Demeter->po->start_plot;
  Demeter->po->title("Sequence of difference spectra");
  my $temp = Demeter->po->tempfile;
  open(my $O, '>', $temp);
  foreach my $i (0 .. $#all) {
    printf $O "%d  %.9f\n", $i+1, $all[$i]->area;
  };
  close $O;
  Demeter->chart('plot', 'plot_file', {file=>$temp, xmin=>1, xmax=>$#all+1, param=>'integrated area',
				       showy=>0, xlabel=>'data group', linetype=>'linespoints', title=>'areas'});

  $::app->{main}->status("Plotted sequence of difference spectra");
  undef $busy;
};

sub marked_make {
  my ($this) = @_;
  my $busy = Wx::BusyCursor->new();
  my @all = ($this->{updatemarked}) ? $this->marked : @{$this->{cachemarked}};
  foreach my $d (@all) {
    $this->make($d, 1);
  };
  $::app->{main}->status("Made difference groups from all marked groups");
  undef $busy;
};

1;


=head1 NAME

Demeter::UI::Athena::Difference - A difference spectrum tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

This module provides a tool for computing difference spectra from
normalized mu(E) data, including the calculation of integrated area
under a portion of the difference spectrum.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

plucking

=item *

Marked groups functionality

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
