package Demeter::UI::Athena::Smooth;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);

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

  my $thptbox       = Wx::StaticBox->new($this, -1, 'Three-point smoothing', wxDefaultPosition, wxDefaultSize);
  my $thptboxsizer  = Wx::StaticBoxSizer->new( $thptbox, wxVERTICAL );
  $hbox -> Add($thptboxsizer, 1, wxGROW|wxALL, 2);
  my $nbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $thptboxsizer->Add($nbox,1, wxGROW|wxALL, 2);
  $nbox -> Add(Wx::StaticText->new($this, -1, 'Repetitions'), 0, wxALL, 5);
  $this->{nsmooth} = Wx::SpinCtrl   -> new($this, -1, 3, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER|wxSP_ARROW_KEYS, 1, 20);
  $nbox -> Add($this->{nsmooth}, 1, wxGROW|wxALL, 5);
  $this->{plotsmooth} = Wx::Button->new($this, -1, 'Plot data and smoothed');
  $thptboxsizer->Add($this->{plotsmooth},1, wxGROW|wxALL, 2);
  $this->{savesmooth} = Wx::Button->new($this, -1, 'Make smoothed group');
  $thptboxsizer->Add($this->{savesmooth},1, wxGROW|wxALL, 2);
  $this->{savesmooth}->Enable(0);
  EVT_BUTTON($this, $this->{plotsmooth}, sub{$this->plot_smooth($app->current_data)});
  EVT_BUTTON($this, $this->{savesmooth}, sub{$this->save_smooth($app)});


  my $boxcarbox       = Wx::StaticBox->new($this, -1, 'Boxcar average', wxDefaultPosition, wxDefaultSize);
  my $boxcarboxsizer  = Wx::StaticBoxSizer->new( $boxcarbox, wxVERTICAL );
  $hbox -> Add($boxcarboxsizer, 1, wxGROW|wxALL, 2);
  $nbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $boxcarboxsizer->Add($nbox,1, wxGROW|wxALL, 2);
  $nbox -> Add(Wx::StaticText->new($this, -1, 'Boxcar width'), 0, wxALL, 5);
  $this->{nbox} = Wx::SpinCtrl   -> new($this, -1, 11, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER|wxSP_ARROW_KEYS, 1, 30);
  $nbox -> Add($this->{nbox}, 1, wxGROW|wxALL, 5);
  $this->{plotboxcar} = Wx::Button->new($this, -1, 'Plot data and boxcar');
  $boxcarboxsizer->Add($this->{plotboxcar},1, wxGROW|wxALL, 2);
  $this->{saveboxcar} = Wx::Button->new($this, -1, 'Make boxcar group');
  $boxcarboxsizer->Add($this->{saveboxcar},1, wxGROW|wxALL, 2);
  $this->{saveboxcar}->Enable(0);
  EVT_BUTTON($this, $this->{plotboxcar}, sub{$this->plot_boxcar($app->current_data)});
  EVT_BUTTON($this, $this->{saveboxcar}, sub{$this->save_boxcar($app)});

  $box->Add($hbox, 0, wxGROW|wxALL, 0);
  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: smoothing');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("smooth")});

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
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};


sub plot_smooth {
  my ($this, $data) = @_;
  my $reps = $this->{nsmooth}->GetValue;
  $this->{data} = $data->clone(name=>$data->name." smoothed $reps times");
  $this->{data}->smooth($reps);
  $::app->{main}->{PlotE}->pull_single_values;
  Demeter->po->set(e_norm=>0, e_markers=>0, e_der=>0, e_sec=>0, e_pre=>0, e_post=>0);
  Demeter->po->start_plot;
  $data->plot('E');
  $this->{data}->plot('E');
  $this->{savesmooth}->Enable(1);
  $this->{saveboxcar}->Enable(0);
  $::app->{main}->status("Plotted ".$data->name." with its smoothed data, three-point smoothed $reps times");
  $this->{data}->DEMOLISH;
};

sub plot_boxcar {
  my ($this, $data) = @_;
  my $width = $this->{nbox}->GetValue;
  $this->{data} = $data->boxcar($width);
  $::app->{main}->{PlotE}->pull_single_values;
  Demeter->po->set(e_norm=>0, e_markers=>0, e_der=>0, e_sec=>0, e_pre=>0, e_post=>0);
  Demeter->po->start_plot;
  $data->plot('E');
  $this->{data}->plot('E');
  $this->{savesmooth}->Enable(0);
  $this->{saveboxcar}->Enable(1);
  $::app->{main}->status("Plotted ".$data->name." with its boxcar averaged data, kernel width $width");
  $this->{data}->DEMOLISH;
};

sub save_smooth {
  my ($this, $app) = @_;
  my $reps = $this->{nsmooth}->GetValue;
  $this->{data} = $app->current_data->clone(name=>$app->current_data->name." smoothed $reps times");
  $this->{data} -> source("Smoothed ".$app->current_data->name.", $reps times");
  $this->{data}->smooth($reps);


  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->AddData($this->{data}->name, $this->{data});
  } else {
    $app->{main}->{list}->InsertData($this->{data}->name, $index+1, $this->{data});
  };
  $app->{main}->status("Smoothed " . $app->current_data->name." and made a new data group");
  $app->modified(1);
  $app->heap_check(0);
};

sub save_boxcar {
  my ($this, $app) = @_;
  my $width = $this->{nbox}->GetValue;
  $this->{data} = $app->current_data->boxcar($width);
  $this->{data} -> source("Boxcar average of ".$app->current_data->name.", kernel width $width");
  $this->{data}->_update('fft');
  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->AddData($this->{data}->name, $this->{data});
  } else {
    $app->{main}->{list}->InsertData($this->{data}->name, $index+1, $this->{data});
  };
  $app->{main}->status("Boxcar averaged " . $app->current_data->name." and made a new data group");
  $app->modified(1);
  $app->heap_check(0);
};

1;


=head1 NAME

Demeter::UI::Athena::Smooth - A smoothing tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.14.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
