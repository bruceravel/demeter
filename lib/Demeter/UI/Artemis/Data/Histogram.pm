package  Demeter::UI::Artemis::Data::Histogram;

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

use Demeter::ScatteringPath::Histogram::DL_POLY;

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_BUTTON);

my @PosSize = (wxDefaultPosition, [60,-1]);

sub new {
  my ($class, $parent, $how) = @_;

  my $data = $parent->{data};
  my $sp = $parent->{pathlist}->GetPageText($parent->{pathlist}->GetSelection);
  my $this = $class->SUPER::new($parent, -1, "Artemis: Make histogram",
				Wx::GetMousePosition, [600, -1],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $outerbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $label = Wx::StaticText->new($this, -1, "Make a histogram using \"$sp\"");
  $outerbox -> Add($label, 0, wxGROW|wxALL, 5);
  $label->SetFont( Wx::Font->new( 12, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{label} = Wx::StaticText->new($this, -1, " ");
  $outerbox -> Add($this->{label}, 0, wxGROW|wxALL, 5);

  $outerbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);
  $this->{box} = $outerbox;

  $this->{DLPOLY} = q{};
  if ($how =~ m{column}) {
    $this->from_file($data);
  } elsif ($how =~ m{gamma}i) {
    $this->gamma($data);
  } elsif ($how =~ m{dl_?poly}i) {
    $this->dlpoly($data);
  };

  ## -------- controls
  $outerbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);

  $this->{ok} = Wx::Button->new($this, wxID_OK, "Make histogram", wxDefaultPosition, wxDefaultSize, 0, );
  $outerbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $outerbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);

  $this -> SetSizerAndFit( $outerbox );
  return $this;
};


sub from_file {
  my ($this, $data) = @_;
  ## -------- from file
  $this->{label}->SetLabel("Build histogram from a column data file");
  #$this->{filesel} = Wx::RadioButton->new($this, -1, 'Read histogram from a file', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  #$this->{box} -> Add($this->{filesel}, 0, wxGROW|wxALL, 5);
  #EVT_RADIOBUTTON($this, $this->{filesel}, \&OnChoice);

  $this->{filepicker} = Wx::FilePickerCtrl->new( $this, -1, "", "Choose a File", "All files|*",
				    [-1, -1], [-1, -1], wxFLP_DEFAULT_STYLE|wxFLP_USE_TEXTCTRL );
  $this->{box} -> Add($this->{filepicker}, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  my $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{box} -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  $this -> {filerminlab} = Wx::StaticText -> new($this, -1, "Rmin");
  $this -> {filermin}    = Wx::TextCtrl   -> new($this, -1, $data->co->default(qw(histogram rmin)), @PosSize,);
  $vbox -> Add($this->{filerminlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{filermin},    0, wxGROW|wxALL, 5);

  $this -> {filermaxlab} = Wx::StaticText -> new($this, -1, "Rmax");
  $this -> {filermax}    = Wx::TextCtrl   -> new($this, -1, $data->co->default(qw(histogram rmax)), @PosSize,);
  $vbox -> Add($this->{filermaxlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{filermax},    0, wxGROW|wxALL, 5);

  $this -> {filexcollab} = Wx::StaticText -> new($this, -1, "x-axis column");
  $this -> {filexcol}    = Wx::SpinCtrl   -> new($this, -1, $data->co->default(qw(histogram xcol)), @PosSize,);
  $this -> {filexcol}   -> SetRange(1,1000);
  $vbox -> Add($this->{filexcollab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{filexcol},    0, wxGROW|wxALL, 5);

  $this -> {fileycollab} = Wx::StaticText -> new($this, -1, "y-axis column");
  $this -> {fileycol}    = Wx::SpinCtrl   -> new($this, -1, $data->co->default(qw(histogram ycol)), @PosSize,);
  $this -> {fileycol}   -> SetRange(1,1000);
  $vbox -> Add($this->{fileycollab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{fileycol},    0, wxGROW|wxALL, 5);

  $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{box} -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);
  $this -> {fileamplab} = Wx::StaticText -> new($this, -1, "Amplitude parameter");
  $this -> {fileamp}    = Wx::TextCtrl   -> new($this, -1, q{amp}, wxDefaultPosition, [120,-1],);
  $vbox -> Add($this->{fileamplab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{fileamp},    0, wxGROW|wxALL, 5);

  $this -> {filescalelab} = Wx::StaticText -> new($this, -1, "Isotropic scaling parameter");
  $this -> {filescale}    = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [120,-1],);
  $vbox -> Add($this->{filescalelab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{filescale},    0, wxGROW|wxALL, 5);

  return $this;
};

sub gamma {
  my ($this, $data) = @_;
  $this->{label}->SetLabel("Build histogram from a Gamma-Like function");
  #$this->{gammasel} = Wx::RadioButton->new($this, -1, 'Create histogram from a Gamma-like function', wxDefaultPosition, wxDefaultSize);
  #$this->{box} -> Add($this->{gammasel}, 0, wxGROW|wxALL, 5);
  #EVT_RADIOBUTTON($this, $this->{gammasel}, \&OnChoice);

  my $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{box} -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  $this -> {gammarminlab} = Wx::StaticText -> new($this, -1, "Rmin");
  $this -> {gammarmin}    = Wx::TextCtrl   -> new($this, -1, $data->co->default(qw(histogram rmin)), @PosSize,);
  $vbox -> Add($this->{gammarminlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{gammarmin},    0, wxGROW|wxALL, 5);

  $this -> {gammarmaxlab} = Wx::StaticText -> new($this, -1, "Rmax");
  $this -> {gammarmax}    = Wx::TextCtrl   -> new($this, -1, $data->co->default(qw(histogram rmax)), @PosSize,);
  $vbox -> Add($this->{gammarmaxlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{gammarmax},    0, wxGROW|wxALL, 5);


  $this -> {gammargridlab} = Wx::StaticText -> new($this, -1, "Rgrid");
  $this -> {gammargrid}    = Wx::TextCtrl   -> new($this, -1, $data->co->default(qw(histogram rgrid)), @PosSize,);
  $vbox -> Add($this->{gammargridlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{gammargrid},    0, wxGROW|wxALL, 5);

  return $this;
};


sub dlpoly {
  my ($this, $data) = @_;
  $this->{label}->SetLabel("Build histogram from a DL_POLY history file");

  $this->{dlfile} = Wx::FilePickerCtrl->new( $this, -1, "", "Choose a HISTORY File", "All files|*",
					     [-1, -1], [-1, -1], wxFLP_DEFAULT_STYLE|wxFLP_USE_TEXTCTRL );
  $this->{box} -> Add($this->{dlfile}, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  my $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{box} -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  ##$data->co->default(qw(histogram rmin))
  $this -> {dlrminlab} = Wx::StaticText -> new($this, -1, "Rmin");
  $this -> {dlrmin}    = Wx::TextCtrl   -> new($this, -1, 1.0, @PosSize,);
  $vbox -> Add($this->{dlrminlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{dlrmin},    0, wxGROW|wxALL, 5);

  ## $data->co->default(qw(histogram rmax))
  $this -> {dlrmaxlab} = Wx::StaticText -> new($this, -1, "Rmax");
  $this -> {dlrmax}    = Wx::TextCtrl   -> new($this, -1, 3.5, @PosSize,);
  $vbox -> Add($this->{dlrmaxlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{dlrmax},    0, wxGROW|wxALL, 5);

  $this -> {dlbinlab} = Wx::StaticText -> new($this, -1, "Bin size");
  $this -> {dlbin}    = Wx::TextCtrl   -> new($this, -1, 0.005, @PosSize,);
  $vbox -> Add($this->{dlbinlab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{dlbin},    0, wxGROW|wxALL, 5);

  $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{box} -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  $this -> {dltypelab} = Wx::StaticText -> new($this, -1, "Path type:");
  $this -> {dltype}    = Wx::TextCtrl -> new($this, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $vbox -> Add($this->{dltypelab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{dltype},    0, wxGROW|wxALL, 5);

  $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{box} -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  $this -> {dlplot} = Wx::Button -> new($this, -1, "Plot RDF");
  $vbox -> Add($this->{dlplot},    1, wxGROW|wxALL, 5);
  $this->EVT_BUTTON($this->{dlplot}, sub{ dlplot(@_) });

  return $this;
};

sub dlplot {
  my ($this, $event) = @_;
  my $file = $this->{dlfile}->GetTextCtrl->GetValue;
  my $rmin = $this->{dlrmin}->GetValue;
  my $rmax = $this->{dlrmax}->GetValue;
  my $bin  = $this->{dlbin}->GetValue;

  if ((not $file) or (not -e $file) or (not -r $file)) {
    $this->GetParent->status("You did not specify a file or your file cannot be read.");
    return;
  };

  my $dlp = Demeter::ScatteringPath::Histogram::DL_POLY->new(rmin=>$rmin, rmax=>$rmax, bin=>$bin);
  $this->{DLPOLY} = $dlp;
  $dlp->sentinal(sub{$this->dlpoly_sentinal});

  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );
  $dlp->file($file);
  $dlp->rebin;
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = sprintf("Plotting histogram from %d timesteps (%d minutes, %d seconds)", $dlp->nsteps, $dur->minutes, $dur->seconds);
  $this->GetParent->status($finishtext);
  $dlp->plot;
  undef $busy;
};

sub dlpoly_sentinal {
  my ($this) = @_;
  my $text = $this->{DLPOLY}->timestep_count . " of " . $this->{DLPOLY}->{nsteps} . " timesteps";
  #print $text, $/;
  $this->GetParent->status($text, 'wait|nobuffer') if not $this->{DLPOLY}->timestep_count % 5;
};


# sub OnChoice {
#   my ($parent, $event) = @_;
#   my $is_file  = $parent->{filesel} ->GetValue;
#   my $is_gamma = $parent->{gammasel}->GetValue;
#   $parent->{$_}->Enable($is_file)  foreach qw(filepicker filerminlab filermin filermaxlab filermax
# 					      filexcollab filexcol fileycollab fileycol
# 					      fileamplab fileamp filescalelab filescale);
#   $parent->{$_}->Enable($is_gamma) foreach qw(gammarminlab gammarmin gammarmaxlab gammarmax gammargridlab gammargrid);
# };

sub ShouldPreventAppExit {
  0
};

1;

=head1 NAME

Demeter::UI::Artemis::Data::Histogram - Histogram editing widget

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

This module provides a dialog for editing histogram generation
parameters.

=head1 CONFIGURATION

See the histogram group of configuration parameters,
L<Demeter::Config>, and L<Demeter::UI::Wx::Config>.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
