package Demeter::UI::Athena::LogRatio;

use strict;
use warnings;
use Cwd;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Log-ratio/phase-difference analysis";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  $this->{LR} = Demeter::LogRatio->new;

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  my $label = Wx::StaticText->new($this, -1, "Standard");
  $gbs->Add($label, Wx::GBPosition->new(0,0));
  $label = Wx::StaticText->new($this, -1, "Unknown");
  $gbs->Add($label, Wx::GBPosition->new(1,0));


  $this->{standard} = Demeter::UI::Athena::GroupList -> new($this, $app, 1);
  $this->{this}     = Wx::StaticText->new($this, -1, q{Group});
  $gbs->Add($this->{standard}, Wx::GBPosition->new(0,1));
  $gbs->Add($this->{this},     Wx::GBPosition->new(1,1));

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10);

  my $fitbox       = Wx::StaticBox->new($this, -1, 'Fitting range', wxDefaultPosition, wxDefaultSize);
  my $fitboxsizer  = Wx::StaticBoxSizer->new( $fitbox, wxHORIZONTAL );
  $box            -> Add($fitboxsizer, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $fitboxsizer->Add(Wx::StaticText->new($this, -1, q{q-range}), 0, wxALL, 5);
  $this->{qmin} = Wx::TextCtrl->new($this, -1, 3, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $fitboxsizer->Add($this->{qmin}, 0, wxALL, 5);
  $fitboxsizer->Add(Wx::StaticText->new($this, -1, q{to}), 0, wxALL, 5);
  $this->{qmax} = Wx::TextCtrl->new($this, -1, 12, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $fitboxsizer->Add($this->{qmax}, 0, wxALL, 5);
  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) ) foreach (qw(qmin qmax));
  $fitboxsizer->Add(Wx::StaticText->new($this, -1, "2$PI jumps"), 0, wxALL, 5);
  $this->{twopi} = Wx::SpinCtrl->new($this, -1, 0, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS|wxTE_PROCESS_ENTER, -5, 5);
  $fitboxsizer->Add($this->{twopi}, 0, wxALL, 5);

  $this->{fit} = Wx::Button->new($this, -1, 'Fit');
  $box -> Add($this->{fit}, 0, wxGROW|wxALL, 2);

  $this->{result} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
				      wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL|wxTE_RICH2);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize - 1;
  $this->{result}->SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $box->Add($this->{result}, 1, wxGROW|wxALL, 5);

  $this->{lr}   = Wx::Button->new($this, -1, 'Plot log-ratio + fit');
  $this->{pd}   = Wx::Button->new($this, -1, 'Plot phase-difference + fit');
  $box -> Add($this->{lr}, 0, wxGROW|wxALL, 2);
  $box -> Add($this->{pd}, 0, wxGROW|wxALL, 2);
  $this->{lr}->Enable(0);
  $this->{pd}->Enable(0);

  my $plotbox       = Wx::StaticBox->new($this, -1, 'Plot standard and unkown in', wxDefaultPosition, wxDefaultSize);
  my $plotboxsizer  = Wx::StaticBoxSizer->new( $plotbox, wxHORIZONTAL );
  $box            -> Add($plotboxsizer, 0, wxGROW|wxALL, 2);
  $this->{k}   = Wx::Button->new($this, -1, 'k');
  $this->{r}   = Wx::Button->new($this, -1, 'R');
  $this->{q}   = Wx::Button->new($this, -1, 'q');
  $plotboxsizer -> Add($this->{$_}, 1, wxGROW|wxALL, 2) foreach (qw(k r q));

  $this->{save} = Wx::Button->new($this, -1, 'Save results of fit');
  $box -> Add($this->{save}, 0, wxGROW|wxALL, 2);
  $this->{save}->Enable(0);

  foreach my $x (qw(qmin qmax twopi)) {
    EVT_TEXT_ENTER($this, $this->{$x}, sub{fit(@_)});
  };
  EVT_BUTTON($this, $this->{fit},  sub{fit(@_)});
  EVT_BUTTON($this, $this->{lr},   sub{plot(@_, 'even')});
  EVT_BUTTON($this, $this->{pd},   sub{plot(@_, 'odd')});
  EVT_BUTTON($this, $this->{k},    sub{plot(@_, 'k')});
  EVT_BUTTON($this, $this->{r},    sub{plot(@_, 'r')});
  EVT_BUTTON($this, $this->{q},    sub{plot(@_, 'q')});
  EVT_BUTTON($this, $this->{save}, sub{save(@_, 'save')});


  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: log-ratio/phase-difference');
  $box -> Add($this->{document}, 0, wxGROW|wxLEFT|wxRIGHT, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("analysis.lr")});

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
  $this->{this}  -> SetLabel($data->name);
  my $was = $this->{standard}->GetStringSelection;
  $this->{standard}->fill($::app, 1, 1);
  #($was eq 'None') ? $this->{standard}->SetSelection(0) : $this->{standard}->SetStringSelection($was);
  #$this->{standard}->SetSelection(0) if not defined($this->{standard}->GetClientData(scalar $this->{standard}->GetSelection));
  if ((not $was) or ($was eq 'None')) {
    $this->{standard}->SetSelection(0);
  } else {
    $this->{standard}->SetStringSelection($was);
    $this->{standard}->SetSelection(0) if not scalar $this->{standard}->GetSelection;
  };

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
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub fit {
  my ($this, $event) = @_;
  $this->{LR}->data($::app->current_data);
  $this->{LR}->standard($this->{standard}->GetClientData(scalar $this->{standard}->GetSelection));
  $this->{LR}->twopi($this->{twopi}->GetValue);
  my ($qmin, $qmax) = sort {$a <=> $b} ($this->{qmin}->GetValue, $this->{qmax}->GetValue);
  $this->{LR}->qmin($qmin);
  $this->{LR}->qmax($qmax);
  $this->{LR}->fit;
  $this->{result}->SetValue($this->{LR}->report);
  $this->{LR}->po->start_plot;
  $this->{LR}->plot_even;
  $this->{lr}->Enable(1);
  $this->{pd}->Enable(1);
  $this->{save}->Enable(1);
  $::app->{main}->status(sprintf("Made a log-ratio/phase-difference fit of %s to %s",
				 $this->{LR}->data->name,
				 $this->{LR}->standard->name));
};

sub plot {
  my ($this, $event, $how) = @_;
  $this->{LR}->po->start_plot;
  if ($how eq 'even') {
    $this->{LR}->plot_even;
  } elsif ($how eq 'odd') {
    $this->{LR}->plot_odd;
  } elsif ($how =~ m{\A[kqr]\z}i) {
    $this->{LR}->data($::app->current_data);
    $this->{LR}->standard($this->{standard}->GetClientData(scalar $this->{standard}->GetSelection));
    $this->{LR}->standard->plot($how);
    $this->{LR}->data->plot($how);
  };
  $::app->heap_check(0);
};

sub save {
  my ($this, $event) = @_;
  (my $name = $this->{LR}->data->name) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save log-ratio fit to a file", cwd, $name.".lrpd",
				"Log-ratio/phase-difference (*.lrpd)|*.lrpd|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving log-ratio results to a file has been canceled.");
    return 0;
  };
  my $fname = $fd->GetPath;
  #return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $this->{LR}->save($fname);
  $::app->{main}->status("Saved log-ratio/phase-difference results to $fname");
};

1;


=head1 NAME

Demeter::UI::Athena::LogRatio - A log-ratio/phase-difference analysis for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

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
