package Demeter::UI::Athena::Smooth;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHOICE);

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Smooth data";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{data} = q{};

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $hbox -> Add(Wx::StaticText->new($this, -1, 'Algorithm'), 0, wxALL, 5);
  my $first = (Demeter->is_ifeffit) ? 'Three-point smoothing' : 'Savitzky-Golay';
  $this->{choice} = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize,
				    [$first, 'Boxcar average', 'Gaussian Filter']);
  $hbox -> Add($this->{choice}, 1, wxGROW|wxALL, 2);
  $box  -> Add($hbox, 0, wxGROW|wxALL, 5);
  $this->{choice}->SetSelection(1);
  EVT_CHOICE($this, $this->{choice}, \&OnChoice);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $this->{widthlabel} = Wx::StaticText->new($this, -1, 'Kernel size  ');
  $hbox -> Add($this->{widthlabel}, 0, wxALL, 5);
  $this->{width} = Wx::SpinCtrl -> new($this, -1, 11, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER|wxSP_ARROW_KEYS, 1, 20);
  $hbox -> Add($this->{width}, 1, wxGROW|wxALL, 2);
  $this->{devlabel} = Wx::StaticText->new($this, -1, 'Width');
  $hbox -> Add($this->{devlabel}, 0, wxALL, 5);
  $this->{dev} = Wx::SpinCtrl -> new($this, -1, 4, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER|wxSP_ARROW_KEYS, 1, 10);
  $hbox -> Add($this->{dev}, 1, wxGROW|wxALL, 2);
  $box  -> Add($hbox, 0, wxGROW|wxALL, 5);
  $this->{devlabel}->Enable(0);
  $this->{dev}->Enable(0);
  #$::app->mouseover($this->{width}, "The kernel size must be odd -- if you choose an even number, one will be added to it");

  $this->{plot} = Wx::Button->new($this, -1, 'Plot data and smoothed');
  $box->Add($this->{plot},0, wxGROW|wxALL, 2);
  $this->{save} = Wx::Button->new($this, -1, 'Make smoothed group');
  $box->Add($this->{save},0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{plot}, sub{$this->plot($app->current_data)});
  EVT_BUTTON($this, $this->{save}, sub{$this->save($app)});
  $this->{save}->Enable(0);

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: smoothing');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.smooth")});

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
  return if $::app->{plotting};
  $this->plot($data);
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnChoice {
  my ($this, $event) = @_;
  if ($this->{choice}->GetStringSelection eq 'Three-point smoothing') {
    $this->{widthlabel}->SetLabel("Repetitions");
    $this->{widthlabel}->Enable(1);
    $this->{width}->Enable(1);
    $this->{devlabel}->Enable(0);
    $this->{dev}->Enable(0);
    #$::app->mouseover($this->{width}, "The number of repititions of the the three-point smoothing");
  } elsif ($this->{choice}->GetStringSelection eq 'Savitzky-Golay') {
    $this->{widthlabel}->SetLabel("Size");
    $this->{widthlabel}->Enable(0);
    $this->{width}->Enable(0);
    $this->{devlabel}->Enable(0);
    $this->{dev}->Enable(0);
    #$::app->mouseover($this->{width}, "The number of repititions of the the three-point smoothing");
  } elsif ($this->{choice}->GetStringSelection eq 'Boxcar average') {
    $this->{widthlabel}->SetLabel("Kernel size");
    $this->{widthlabel}->Enable(1);
    $this->{width}->Enable(1);
    $this->{devlabel}->Enable(0);
    $this->{dev}->Enable(0);
    #$::app->mouseover($this->{width}, "The kernel size must be odd -- if you choose an even number, one will be added to it");
  } elsif ($this->{choice}->GetStringSelection eq 'Gaussian Filter') {
    $this->{widthlabel}->SetLabel("Kernel size");
    $this->{widthlabel}->Enable(1);
    $this->{width}->Enable(1);
    $this->{devlabel}->Enable(1);
    $this->{dev}->Enable(1);
    #$::app->mouseover($this->{width}, "The kernel size must be odd -- if you choose an even number, one will be added to it");
  };
  $this->{save}->Enable(0);
};

sub plot {
  my ($this, $data) = @_;
  my $width = $this->{width}->GetValue;
  my $text = "Plotted \"".$data->name."\" with its ";
  $data->standard;
  if ($this->{choice}->GetStringSelection eq 'Three-point smoothing') {
    $this->{data}  = $data->Clone(name=>$data->name." smoothed $width times");
    $this->{data} -> smooth($width);
    ## XDI data not preserved!  :FIXME:
    $text .= "smoothed data, three-point smoothed $width times";
  } elsif ($this->{choice}->GetStringSelection eq 'Savitzky-Golay') {
    $this->{data}  = $data->Clone(name=>$data->name." Savitzky-Golay");
    $this->{data} -> smooth(1);
    $text .= "smoothed data, Savitzky-Golay";
  } elsif ($this->{choice}->GetStringSelection eq 'Boxcar average') {
    $this->{data} = $data->boxcar($width);
    $text .= "boxcar averaged data, kernel size $width";
  } elsif ($this->{choice}->GetStringSelection eq 'Gaussian Filter') {
    my $sd        = $this->{dev}->GetValue;
    $this->{data} = $data->gaussian_filter($width, $sd);
    $text .= "Gaussian filtered data, size $width width $sd";
  };
  $::app->{main}->{PlotE}->pull_single_values;
  Demeter->po->set(e_norm=>0, e_bkg=>0, e_markers=>0, e_der=>0, e_sec=>0, e_pre=>0, e_post=>0);
  Demeter->po->start_plot;
  $data->plot('E');
  $this->{data}->plot('E');
  $this->{save}->Enable(1);
  $::app->{main}->status($text);;
  $data->unset_standard;
  $this->{data}->DEMOLISH;
};

sub save {
  my ($this, $app) = @_;
  my $width = $this->{width}->GetValue;
  my $text = " \"" . $app->current_data->name."\" and made a new data group";
  $app->current_data->standard;
  if ($this->{choice}->GetStringSelection eq 'Three-point smoothing') {
    $this->{data}  = $app->current_data->Clone(name=>$app->current_data->name." smoothed $width times");
    $this->{data} -> source("Smoothed ".$app->current_data->name.", $width times");
    $this->{data} -> smooth($width);
    $text = "Smoothed" . $text;
  } elsif ($this->{choice}->GetStringSelection eq 'Savitzky-Golay') {
    $this->{data}  = $app->current_data->Clone(name=>$app->current_data->name." Savitzky-Golay");
    $this->{data} -> source("Smoothed ".$app->current_data->name.", Savitzky-Golay");
    $this->{data} -> smooth(1);
    $text = "SG" . $text;
  } elsif ($this->{choice}->GetStringSelection eq 'Boxcar average') {
    $this->{data} = $app->current_data->boxcar($width);
    $this->{data} -> source("Boxcar average of ".$app->current_data->name.", kernel size $width");
    $text = "Boxcar averaged" . $text;
  } elsif ($this->{choice}->GetStringSelection eq 'Gaussian Filter') {
    my $sd = $this->{dev}->GetValue;
    $this->{data} = $app->current_data->gaussian_filter($width, $sd);
    $this->{data} -> source("Gaussian filter of ".$app->current_data->name.", $width, $sd");
    $text = "Gaussian filter of" . $text;
  };
  $app->current_data->unset_standard;
  $this->{data} ->_update('fft');
  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->AddData($this->{data}->name, $this->{data});
  } else {
    $app->{main}->{list}->InsertData($this->{data}->name, $index+1, $this->{data});
  };
  $app->{main}->status($text);
  $app->modified(1);
  $app->heap_check(0);
};


1;


=head1 NAME

Demeter::UI::Athena::Smooth - A smoothing tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

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

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
