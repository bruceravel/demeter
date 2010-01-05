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

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_RADIOBUTTON);

sub new {
  my ($class, $parent) = @_;

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
  $outerbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);



  my @PosSize = (wxDefaultPosition, [60,-1]);

  ## -------- from file
  $this->{filesel} = Wx::RadioButton->new($this, -1, 'Read histogram from a file', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $outerbox -> Add($this->{filesel}, 0, wxGROW|wxALL, 5);
  EVT_RADIOBUTTON($this, $this->{filesel}, \&OnChoice);

  $this->{filepicker} = Wx::FilePickerCtrl->new( $this, -1, "", "Choose a File", "All files|*",
				    [-1, -1], [-1, -1], wxFLP_DEFAULT_STYLE|wxFLP_USE_TEXTCTRL );
  $outerbox -> Add($this->{filepicker}, 0, wxGROW|wxLEFT|wxRIGHT, 25);

  my $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $outerbox -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

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
  $outerbox -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);
  $this -> {fileamplab} = Wx::StaticText -> new($this, -1, "Amplitude parameter");
  $this -> {fileamp}    = Wx::TextCtrl   -> new($this, -1, q{amp}, wxDefaultPosition, [120,-1],);
  $vbox -> Add($this->{fileamplab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{fileamp},    0, wxGROW|wxALL, 5);

  $this -> {filescalelab} = Wx::StaticText -> new($this, -1, "Isotropic scaling parameter");
  $this -> {filescale}    = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [120,-1],);
  $vbox -> Add($this->{filescalelab}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($this->{filescale},    0, wxGROW|wxALL, 5);



  ## -------- from Gamma function
  $this->{gammasel} = Wx::RadioButton->new($this, -1, 'Create histogram from a Gamma-like function', wxDefaultPosition, wxDefaultSize);
  $outerbox -> Add($this->{gammasel}, 0, wxGROW|wxALL, 5);
  EVT_RADIOBUTTON($this, $this->{gammasel}, \&OnChoice);

  $vbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $outerbox -> Add($vbox, 0, wxGROW|wxLEFT|wxRIGHT, 25);

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

  $this->{$_}->Enable(0) foreach qw(gammarminlab gammarmin gammarmaxlab gammarmax gammargridlab gammargrid);



  ## -------- controls
  $outerbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);

  $this->{ok} = Wx::Button->new($this, wxID_OK, "Make histogram", wxDefaultPosition, wxDefaultSize, 0, );
  $outerbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $outerbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);

  $this -> SetSizerAndFit( $outerbox );
  return $this;
};

sub OnChoice {
  my ($parent, $event) = @_;
  my $is_file  = $parent->{filesel} ->GetValue;
  my $is_gamma = $parent->{gammasel}->GetValue;
  $parent->{$_}->Enable($is_file)  foreach qw(filepicker filerminlab filermin filermaxlab filermax
					      filexcollab filexcol fileycollab fileycol
					      fileamplab fileamp filescalelab filescale);
  $parent->{$_}->Enable($is_gamma) foreach qw(gammarminlab gammarmin gammarmaxlab gammarmax gammargridlab gammargrid);
};

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
