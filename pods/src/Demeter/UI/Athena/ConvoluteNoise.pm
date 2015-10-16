package Demeter::UI::Athena::ConvoluteNoise;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHAR EVT_CHOICE EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;
use Scalar::Util qw(looks_like_number);

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Convolute and add noise to data";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $gbs->Add(Wx::StaticText->new($this, -1, 'Group'),                         Wx::GBPosition->new(0,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Convolution function'),          Wx::GBPosition->new(1,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Convolution width'),             Wx::GBPosition->new(2,0));
  $gbs->Add(Wx::StaticText->new($this, -1, 'Noise (fraction of edge step)'), Wx::GBPosition->new(3,0));

  $this->{group}    = Wx::StaticText->new($this, -1, q{});
  $this->{function} = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize,
				      ["Gaussian", 'Lorentzian']);
  $this->{width}    = Wx::TextCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{noise}    = Wx::TextCtrl->new($this, -1, 0,  wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);

  $gbs->Add($this->{group},    Wx::GBPosition->new(0,1));
  $gbs->Add($this->{function}, Wx::GBPosition->new(1,1));
  $gbs->Add($this->{width},    Wx::GBPosition->new(2,1));
  $gbs->Add($this->{noise},    Wx::GBPosition->new(3,1));
  $this->{width} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{noise} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  EVT_CHOICE($this, $this->{function}, sub{ $this->{make}->Enable(0) });
  EVT_CHAR($this->{width}, sub{ $this->{make}->Enable(0); $_[1]->Skip(1) });
  EVT_CHAR($this->{noise}, sub{ $this->{make}->Enable(0); $_[1]->Skip(1) });
  EVT_TEXT_ENTER($this, $this->{width}, sub{$this->plot($app->current_data)});
  EVT_TEXT_ENTER($this, $this->{noise}, sub{$this->plot($app->current_data)});
  $this->{function}->SetSelection(0);

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $this->{convolute} = Wx::Button->new($this, -1, 'Plot data and data with convolution and/or noise');
  $this->{make}      = Wx::Button->new($this, -1, 'Make data group');
  $box->Add($this->{convolute}, 0, wxALL|wxGROW, 5);
  $box->Add($this->{make},      0, wxALL|wxGROW, 5);
  EVT_BUTTON($this, $this->{convolute}, sub{$this->plot($app->current_data)});
  EVT_BUTTON($this, $this->{make},      sub{$this->make($app)});
  $this->{make}->Enable(0);

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: convolution and noise');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.conv")});

  $this->{processed} = q{};

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
  $this->{group}->SetLabel($data->name);
  $this->Enable(1);
  $this->{make}->Enable(0);
  if ($data->datatype eq 'chi') {
    $this->{function}->Enable(0);
    $this->{width}->Enable(0);
    return;
  };
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub get_values {
  my ($this) = @_;
  my $function = ($this->{function}->GetSelection) ? 'lorentzian' : 'gaussian';
  my $width    = $this->{width}->GetValue || 0;
  my $noise    = $this->{noise}->GetValue || 0;

  if (not looks_like_number($width)) {
    $::app->{main}->status("Not plotting -- your value for the width is not a number!", 'error|nobuffer');
    return ($function, $width, $noise, 0);
  };
  if ($width < 0) {
    $this->{width}->SetValue(0);
    $width = 0;
  };
  if (not looks_like_number($noise)) {
    $::app->{main}->status("Not plotting -- your value for the noise is not a number!", 'error|nobuffer');
    return ($function, $width, $noise, 0);
  };
  if ($noise < 0) {
    $this->{noise}->SetValue(0);
    $noise = 0;
  };
  return ($function, $width, $noise, 1);
};

sub plot {
  my ($this, $data) = @_;
  my $busy = Wx::BusyCursor->new();
  $::app->{main}->{PlotE}->pull_single_values;
  $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  my ($function, $width, $noise, $ok) = $this->get_values($data);
  return if not $ok;
  $data->po->start_plot;
  $data -> plot('E');
  $this->{processed}  = $data -> Clone(name=>sprintf("%s: %.2f eV %s, %.3f noise", $data->name, $width, ucfirst($function), $noise));
  $this->{processed} -> convolve(width=>$width, type=>$function) if ($width > 0);
  $this->{processed} -> noise(noise=>$noise, which=>'xmu') if ($noise > 0);
  $this->{processed} -> plot('E');
  $this->{make}->Enable(1);
  $::app->{main}->status(sprintf("Plotted %s with convolution and/or added noise", $data->name));
  $::app->heap_check(0);
  undef $busy;
};

sub make {
  my ($this, $app) = @_;

  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->AddData($this->{processed}->name, $this->{processed});
  } else {
    $app->{main}->{list}->InsertData($this->{processed}->name, $index+1, $this->{processed});
  };
  $app->{main}->status(sprintf("Convolved and/or added noise to %s and made a new data group", $app->current_data->name));
  $app->modified(1);
  $app->heap_check(0);
};

1;


=head1 NAME

Demeter::UI::Athena::ConvoluteNoise - A convolution and artficial noise tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.23.

=head1 SYNOPSIS

This module provides a tool for convolving mu(E) data and adding
artifical noise to mu(E) or chi(k) data.

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
