package Demeter::UI::Athena::Dispersive;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHECKBOX EVT_FILEPICKER_CHANGED);

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Cwd;

use vars qw($label);
$label = "Calibrate dispersive XAS data";

my $tcsize = [120,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  $this->{pixel} = q{};
  $this->{yaml} = File::Spec->catfile(Demeter->dot_folder, 'athena.dxas');

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  if (not Demeter->co->default('athena', 'show_dispersive')) {
    $box->Add(Wx::StaticText->new($this, -1, "Dispersive data calibration is disabled at this time."),
	      0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
    $box->Add(1,1,1);
  } else {

    ################################################################################
    ## show calibration standard
    my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
    $hbox -> Add(Wx::StaticText->new($this, -1, 'Calibration standard: '), 0, wxALL, 3);
    $this->{group}   = Wx::StaticText->new($this, -1, q{});
    $hbox -> Add($this->{group}, 0, wxGROW|wxALL, 3);
    $box -> Add($hbox, 0, wxGROW|wxALL, 5);


    $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
    $box -> Add($hbox, 0, wxGROW|wxALL, 5);
    my $leftbox = Wx::BoxSizer->new( wxVERTICAL);
    $hbox -> Add($leftbox, 0, wxGROW|wxALL, 5);

    $this->{beamline} = Wx::RadioBox->new($this, -1, 'Beamline', wxDefaultPosition, wxDefaultSize,
					  ['SLRI BL5', 'ESRF ID24',], 1, wxRA_SPECIFY_COLS);
    $leftbox->Add($this->{beamline}, 0, wxGROW|wxALL, 5);

    my $rightbox = Wx::BoxSizer->new( wxVERTICAL);
    $hbox -> Add($rightbox, 1, wxGROW|wxALL, 5);

    ################################################################################
    ## control for importing dispersive standard
    my $dispbox       = Wx::StaticBox->new($this, -1, 'Import dispersive standard', wxDefaultPosition, wxDefaultSize);
    my $dispboxsizer  = Wx::StaticBoxSizer->new( $dispbox, wxVERTICAL );
    ##$dispbox         -> SetFont( Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );

    $this->{import}  = Wx::FilePickerCtrl->new($this, -1, cwd, 'Select a file', "*",
					       wxDefaultPosition, wxDefaultSize,
					       wxFLP_OPEN|wxFLP_FILE_MUST_EXIST|wxFLP_USE_TEXTCTRL|wxFLP_CHANGE_DIR);
    $dispboxsizer -> Add($this->{import}, 1, wxGROW|wxALL, 5);
    $rightbox -> Add($dispboxsizer, 0, wxGROW|wxALL, 5);


    ################################################################################
    ## controls for calibration parameters
    my $gbs = Wx::GridBagSizer->new( 5, 5 );

    $gbs->Add(Wx::StaticText->new($this, -1, 'Offset'),    Wx::GBPosition->new(0,0));
    $gbs->Add(Wx::StaticText->new($this, -1, 'Linear'),    Wx::GBPosition->new(1,0));
    $gbs->Add(Wx::StaticText->new($this, -1, 'Quadratic'), Wx::GBPosition->new(2,0));

    $this->{offset}    = Wx::TextCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
    $this->{linear}    = Wx::TextCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
    $this->{quadratic} = Wx::TextCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
    $this->{constrain} = Wx::CheckBox->new($this, -1, "Constrain offset to linear term",);
    $this->{reset}     = Wx::Button  ->new($this, -1, "Reset parameters",);


    $gbs->Add($this->{offset},    Wx::GBPosition->new(0,1));
    $gbs->Add($this->{linear},    Wx::GBPosition->new(1,1));
    $gbs->Add($this->{quadratic}, Wx::GBPosition->new(2,1));
    #$gbs->Add($this->{constrain}, Wx::GBPosition->new(0,2));
    $gbs->Add($this->{reset},     Wx::GBPosition->new(1,2));

    $rightbox -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);


    ################################################################################
    ## actions
    $this->{refine} = Wx::Button->new($this, -1, 'Refine calibration parameters', wxDefaultPosition, $tcsize);
    $this->{replot} = Wx::Button->new($this, -1, 'Replot calibration data',       wxDefaultPosition, $tcsize);
    $this->{make}   = Wx::Button->new($this, -1, 'Make data group',               wxDefaultPosition, $tcsize);
    $box -> Add($this->{$_}, 0, wxGROW|wxALL, 5) foreach (qw(refine replot make));

    EVT_BUTTON  ($this, $this->{reset},     \&Reset);
    EVT_BUTTON  ($this, $this->{refine},    \&refine);
    EVT_BUTTON  ($this, $this->{replot},    \&replot);
    EVT_BUTTON  ($this, $this->{make},      \&make);
    EVT_CHECKBOX($this, $this->{constrain}, \&constrain);
    EVT_FILEPICKER_CHANGED($this, $this->{import}, \&set);
    map {$this->{$_}->Enable(0)} qw(reset refine replot make constrain);
    $this->{constrain}->Show(0);


    $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example
  };

  $this->{document} = Wx::Button->new($this, -1, 'Document section: Dispersive XAS');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.pixel")});

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
  return if not Demeter->co->default('athena', 'show_dispersive');
  $this->{group}->SetLabel($data->name);
  my $onoff = ($this->filecheck(1)) ? 1 : 0;
  map {$this->{$_}->Enable($onoff)} qw(reset refine replot make constrain);
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

## yes, there is some overlap between what push_values and mode do.
## This separation was useful in Main.pm.  Some of the other tools
## make mode a null op.

sub filecheck {
  my ($this, $quiet) = @_;
  $quiet ||= 0;
  my $file = $this->{import}->GetPath;
  if (($file =~ m{\A\s*\z}) or (-d $file)) {
    $::app->{main}->status("You have not yet specified a dispersive standard", 'error|nobuffer') if not $quiet;
    return 0;
  };
  if (not -e $file) {
    $::app->{main}->status("The specified dispersive standard does not exist", 'error|nobuffer') if not $quiet;
    return 0;
  };
  if (not -r $file) {
    $::app->{main}->status("The specified dispersive standard cannot be read", 'error|nobuffer') if not $quiet;
    return 0;
  };
  return $file;
};


sub set {
  my ($this, $event) = @_;

  my $file = $this->filecheck;
  return 0 if not $file;
  my $busy = Wx::BusyCursor->new();
  $::app->{main}->status("Processing calibration and dispersive standards and setting initial parameter guesses");
  my $nor2 = Demeter->co->default("dispersive", "bkg_nor2") || 1000;

  my @columns;
  if ($this->{beamline}->GetStringSelection =~ m{SLRI}) {
    @columns = (energy=>'$1', numerator=>'$2', denominator=>'$3', ln=>1);
  } elsif ($this->{beamline}->GetStringSelection =~ m{ESRF}) {
    @columns = (energy=>'$1', numerator=>'$2', denominator=>1, ln=>1);
  };

  $this->{pixel}      = Demeter::Data::Pixel->new(file=>$file, bkg_nor2=>$nor2, @columns);
  $this->{pixel}     -> standard($::app->current_data);
  $this->{pixel}     -> guess;
  $this->{offset}    -> SetValue(sprintf("%.6f", $this->{pixel}->offset));
  $this->{linear}    -> SetValue(sprintf("%.6f", $this->{pixel}->linear));
  $this->{quadratic} -> SetValue(sprintf("%.9f", $this->{pixel}->quadratic));
  map {$this->{$_}->Enable(1)} qw(reset refine replot make constrain);
  undef $busy;
  $this->replot(0);
};

sub Reset {
  my ($this, $event) = @_;
  $this->{pixel}->DEMOLISH;
  $this->set;
};

sub refine {
  my ($this, $event) = @_;
  my $file = $this->filecheck;
  return 0 if not $file;
  my $busy = Wx::BusyCursor->new();
  $::app->{main}->status("Refining dispersive calibration parameters");
  $this->{pixel}->file($file);
  $this->{pixel}->standard($::app->current_data);
  $this->{pixel}->offset($this->{offset} -> GetValue);
  $this->{pixel}->linear($this->{linear} -> GetValue);
  $this->{pixel}->quadratic($this->{quadratic} -> GetValue);
  $this->{pixel}->pixel;
  $this->{offset}    -> SetValue(sprintf("%.6f", $this->{pixel}->offset));
  $this->{linear}    -> SetValue(sprintf("%.6f", $this->{pixel}->linear));
  $this->{quadratic} -> SetValue(sprintf("%.9f", $this->{pixel}->quadratic));
  undef $busy;
  $this->replot(0);
};

sub replot {
  my ($this, $event) = @_;
  my $busy = Wx::BusyCursor->new();
  if ($event) {
    $this->{pixel}->offset($this->{offset} -> GetValue);
    $this->{pixel}->linear($this->{linear} -> GetValue);
    $this->{pixel}->quadratic($this->{quadratic} -> GetValue);
  };
  my $temp = $this->{pixel} -> apply;
  $this -> {pixel} -> standard -> po -> start_plot;
  $this -> {pixel} -> standard -> po -> set(e_mu=>1, e_norm=>1,
					    emin=>Demeter->co->default("dispersive", "emin"),
					    emax=>Demeter->co->default("dispersive", "emax"),
					    e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_der=>0, e_sec=>0);
  $this -> {pixel} -> standard -> plot('E');
  $temp -> plot('E');
  $temp -> DEMOLISH;
  my $hash = {offset    => $this->{pixel}->offset,
	      linear    => $this->{pixel}->linear,
	      quadratic => $this->{pixel}->quadratic};
  my $string .= YAML::Tiny::Dump($hash);
  open(my $PERSIST, '>', $this->{yaml});
  print $PERSIST $string;
  close $PERSIST;

  $::app->{main}->status("Plotted calibration and dispersive standards");
  undef $busy;
};

sub make {
  my ($this, $event) = @_;

  if ($event) {
    $this->{pixel}->offset($this->{offset} -> GetValue);
    $this->{pixel}->linear($this->{linear} -> GetValue);
    $this->{pixel}->quadratic($this->{quadratic} -> GetValue);
  };
  my $dxas = $this->{pixel} -> apply;

  my $index = $::app->current_index;
  if ($index == $::app->{main}->{list}->GetCount-1) {
    $::app->{main}->{list}->AddData($dxas->name, $dxas);
  } else {
    $::app->{main}->{list}->InsertData($dxas->name, $index+1, $dxas);
  };
  $::app->{main}->status("Did dispersion correction for " . $dxas->name." and made a new data group");
  $::app->modified(1);
  $::app->heap_check(0);
};

sub constrain {
  my ($this, $event) = @_;
  $::app->{main}->status("Nothing... (constrain)");
};


1;


=head1 NAME

Demeter::UI::Athena::Dispersive - A tool for calibrating dispersive XAFS data

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

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
