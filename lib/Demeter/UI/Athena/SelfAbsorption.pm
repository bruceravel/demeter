package Demeter::UI::Athena::SelfAbsorption;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Chemistry::Formula qw(parse_formula);
use Scalar::Util qw(looks_like_number);

use vars qw($label);
$label = "Self-absorption correction";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  my $top = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($top, 0, wxALIGN_CENTER_HORIZONTAL|wxTOP|wxBOTTOM, 10);

  $this->{algorithm} = Wx::RadioBox->new($this, -1, 'Algorithm', wxDefaultPosition, wxDefaultSize,
					 ["Fluo $MDASH $MU(E)", "Booth $MDASH $CHI(k)", "Troger $MDASH $CHI(k)", "Atoms $MDASH $CHI(k)"],
					 1, wxRA_SPECIFY_COLS);
  $top -> Add($this->{algorithm}, 0, wxLEFT|wxRIGHT, 5);
  $this->{algorithm}->SetSelection(0);
  EVT_RADIOBOX($this, $this->{algorithm}, sub{OnAlgorithm(@_, $app)});

  my $gbs = Wx::GridBagSizer->new( 5, 5 );
  $gbs->Add(Wx::StaticText->new($this, -1, 'Group'),        Wx::GBPosition->new(0,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Element'),      Wx::GBPosition->new(1,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Edge'),         Wx::GBPosition->new(1,2));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Formula'),      Wx::GBPosition->new(2,0));
  $this->{in_label}        = Wx::StaticText->new($this, -1, 'Angle in');
  $this->{out_label}       = Wx::StaticText->new($this, -1, 'Angle out');
  $this->{thickness_label} = Wx::StaticText->new($this, -1, 'Thickness');
  $gbs->Add($this->{in_label},        Wx::GBPosition->new(3,0));
  $gbs->Add($this->{out_label},       Wx::GBPosition->new(3,2));
  $gbs->Add($this->{thickness_label}, Wx::GBPosition->new(4,0));

  $this->{group}     = Wx::StaticText->new($this, -1, q{});
  $this->{element}   = Wx::StaticText->new($this, -1, q{});
  $this->{edge}      = Wx::StaticText->new($this, -1, q{});
  $this->{formula}   = Wx::TextCtrl->new($this, -1, q{},  wxDefaultPosition, [180, -1], wxTE_PROCESS_ENTER);
  $this->{in}        = Wx::SpinCtrl->new($this, -1, 45,   wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS|wxTE_PROCESS_ENTER, 0, 90);
  $this->{out}       = Wx::SpinCtrl->new($this, -1, 45,   wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS|wxTE_PROCESS_ENTER, 0, 90);
  $this->{thickness} = Wx::TextCtrl->new($this, -1, 1000, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);

  foreach my $x (qw(formula in out thickness)) {
    EVT_TEXT_ENTER($this, $this->{$x}, sub{$this->plot($app->current_data)});
  };
  $this->{thickness} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{thickness_label}->Enable(0);
  $this->{thickness}->Enable(0);

  $gbs->Add($this->{group},     Wx::GBPosition->new(0,1));
  $gbs->Add($this->{element},   Wx::GBPosition->new(1,1));
  $gbs->Add($this->{edge},      Wx::GBPosition->new(1,3));
  $gbs->Add($this->{formula},   Wx::GBPosition->new(2,1), Wx::GBSpan->new(1,3));
  $gbs->Add($this->{in},        Wx::GBPosition->new(3,1));
  $gbs->Add($this->{out},       Wx::GBPosition->new(3,3));
  $gbs->Add($this->{thickness}, Wx::GBPosition->new(4,1));
  $top -> Add($gbs, 0, wxLEFT|wxRIGHT, 25);


  $this->{plot}  = Wx::Button->new($this, -1, 'Plot data and correction',         wxDefaultPosition, $tcsize);
  $this->{infoe} = Wx::Button->new($this, -1, 'Plot information depth in energy', wxDefaultPosition, $tcsize);
  $this->{info}  = Wx::Button->new($this, -1, 'Plot information depth in k',      wxDefaultPosition, $tcsize);
  $this->{make}  = Wx::Button->new($this, -1, 'Make corrected data group',        wxDefaultPosition, $tcsize);
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 2) foreach (qw(plot infoe info make));
  $this->{make}->Enable(0);
  EVT_BUTTON($this, $this->{plot},    sub{$this->plot($app->current_data)});
  EVT_BUTTON($this, $this->{infoe},   sub{$this->info($app->current_data, 'E')});
  EVT_BUTTON($this, $this->{info},    sub{$this->info($app->current_data, 'k')});
  EVT_BUTTON($this, $this->{make},    sub{$this->make($app)});

  my $textbox        = Wx::StaticBox->new($this, -1, 'Feedback', wxDefaultPosition, wxDefaultSize);
  my $textboxsizer   = Wx::StaticBoxSizer->new( $textbox, wxVERTICAL );
  $box              -> Add($textboxsizer, 1, wxBOTTOM|wxGROW, 5);
  $this->{feedback}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					 wxTE_MULTILINE|wxTE_READONLY|wxTE_RICH2);
  $this->{feedback} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $textboxsizer     -> Add($this->{feedback}, 1, wxGROW|wxALL, 5);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: self absorption');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.sa")});

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
  $this->{group}  ->SetLabel($data->name);
  $this->{element}->SetLabel(ucfirst($data->bkg_z));
  $this->{edge}   ->SetLabel(ucfirst($data->fft_edge));
  $this->{make}   ->Enable(0);
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnAlgorithm {
  my ($this, $event, $app) = @_;
  if ($this->{algorithm}->GetSelection == 1) {
    $this->{$_}->Enable(1) foreach (qw(thickness thickness_label));
  } else {
    $this->{$_}->Enable(0) foreach (qw(thickness thickness_label));
  };
  if ($this->{algorithm}->GetSelection == 3) {
    $this->{$_}->Enable(0) foreach (qw(in in_label out out_label));
  } else {
    $this->{$_}->Enable(1) foreach (qw(in in_label out out_label));
  };
};

sub plot {
  my ($this, $data) = @_;
  my $busy = Wx::BusyCursor->new();
  my @algs = (qw(fluo booth troger atoms));
  my $algorithm = $algs[$this->{algorithm}->GetSelection];
  my $space = ($algorithm eq 'fluo') ? 'E' : 'k';
  my $formula   = $this->{formula}   -> GetValue;
  my $in        = $this->{in}        -> GetValue;
  my $out       = $this->{out}       -> GetValue;
  my $thickness = $this->{thickness} -> GetValue;
  if (not looks_like_number($thickness)) {
    $::app->{main}->status("Not doing self absorption correction -- your value for thickness is not a number!", 'error|nobuffer');
    return;
  };

  if ($formula =~ m{\A\s*\z}) {
    $this->{feedback}->SetValue("You did not provide a formula.");
    $::app->{main}->status("You did not provide a formula.", 'error');
    return;
  };
  my %count = ();
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    $this->{feedback}->SetValue($count{error});
    $::app->{main}->status("The formula \"$formula\" could not be parsed.", 'error');
    return;
  };
  if (not exists($count{ucfirst($data->bkg_z)})) {
    $this->{feedback}->SetValue("Your formula does not contain the absorber.");
    $::app->{main}->status("Your formula does not contain the absorber.", 'error');
    return;
  };

  $::app->{main}->{PlotE}->pull_single_values;
  $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0) if $space eq 'E';
  $data->po->start_plot;
  $data->plot($space);

  my $text = q{};
  ($this->{sadata}, $text) = $data->sa($algorithm, formula=>$formula, in=>$in, out=>$out, thickness=>$thickness);
  $this->{feedback}->Clear;
  $this->{feedback}->SetValue($text);
  $this->{sadata}->plot($space);

  $this->{make}->Enable(1);
  $::app->{main}->status("Plotted data using " . ucfirst($algorithm) . " algorithm.");
  $::app->heap_check(0);

  undef $busy;
};

sub make {
  my ($this, $app) = @_;

  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->AddData($this->{sadata}->name, $this->{sadata});
  } else {
    $app->{main}->{list}->InsertData($this->{sadata}->name, $index+1, $this->{sadata});
  };
  $app->{main}->status("Made self-absorption corrected group from " . $app->current_data->name);
  $app->modified(1);
  $app->heap_check(0);
};

sub info {
  my ($this, $data, $space) = @_;
  my $formula   = $this->{formula}   -> GetValue;
  my $in        = $this->{in}        -> GetValue;
  my $out       = $this->{out}       -> GetValue;
  if ($formula =~ m{\A\s*\z}) {
    $this->{feedback}->SetValue("You did not provide a formula.");
    $::app->{main}->status("You did not provide a formula.", 'error');
    return;
  };
  my %count = ();
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    $this->{feedback}->SetValue($count{error});
    $::app->{main}->status("The formula \"$formula\" could not be parsed.", 'error');
    return;
  };
  if (not exists($count{ucfirst($data->bkg_z)})) {
    $this->{feedback}->SetValue("Your formula does not contain the absorber.");
    $::app->{main}->status("Your formula does not contain the absorber.", 'error');
    return;
  };

  $::app->{main}->{PlotK}->pull_single_values;

  $data->po->start_plot;
  my ($x, $y) = $data->info_depth($formula, $in, $out, $space);
  my $tempfile = $data->po->tempfile;
  open my $T, '>'.$tempfile;
  foreach my $i (0 .. $#{$x}) {
    print $T $x->[$i], "  ", $y->[$i], 0, $/;
  };
  close $T;

  if (lc($space) eq 'e') {
    $data -> chart('plot', 'plot_info_depth_e', {file  => $tempfile});
  } else {
    $data -> chart('plot', 'plot_info_depth',   {file  => $tempfile});
  };
};


1;


=head1 NAME

Demeter::UI::Athena::SelfAbsorption - A self-absorption correction tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

This module provides a tool for computing self absorption corrections using
L<Data::Demeter::SelfAbsorption>.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

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
