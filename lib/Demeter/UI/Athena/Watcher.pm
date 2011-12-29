package Demeter::UI::Athena::Watcher;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);
use Demeter::UI::Athena::Timer;
use Wx::Perl::TextValidator;
use Scalar::Util qw(looks_like_number);
use File::Monitor::Lite;

use Cwd;

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Data watcher";

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer} = $box;

  my $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
  $box->Add($hbox, 0, wxGROW|wxALL, 3);
  $this->{dir} = Wx::DirPickerCtrl->new($this, -1, cwd, "Select as folder",
					wxDefaultPosition, wxDefaultSize,
					wxDIRP_DIR_MUST_EXIST|wxDIRP_CHANGE_DIR|wxDIRP_USE_TEXTCTRL);
  $hbox -> Add($this->{dir}, 1, wxGROW|wxALL, 0);

  $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
  $box->Add($hbox, 0, wxGROW|wxALL, 3);
  $hbox->Add(Wx::StaticText->new($this, -1, "File basename"), 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $this->{base} = Wx::TextCtrl->new($this, -1, q{});
  $hbox->Add($this->{base}, 1, wxLEFT|wxRIGHT, 3);

  $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
  $box->Add($hbox, 0, wxGROW|wxALL, 3);
  $hbox->Add(Wx::StaticText->new($this, -1, "Interval"), 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $this->{interval} = Wx::TextCtrl->new($this, -1, Demeter->co->default(qw(watcher interval)), wxDefaultPosition, [120,-1]);
  $hbox->Add($this->{interval}, 0, wxLEFT|wxRIGHT, 3);
  $hbox->Add(Wx::StaticText->new($this, -1, "seconds"), 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $this->{interval} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9]) ) );

  $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
  $box->Add($hbox, 0, wxGROW|wxALL, 3);
  $this->{standard} = Wx::Button->new($this, -1, "Import the first file");
  $hbox->Add($this->{standard}, 1, wxLEFT|wxRIGHT, 3);

  $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
  $box->Add($hbox, 0, wxGROW|wxALL, 3);
  $this->{start} = Wx::Button->new($this, wxID_APPLY, "");
  $hbox->Add($this->{start}, 1, wxLEFT|wxRIGHT, 3);
  $this->{stop} = Wx::Button->new($this, wxID_STOP, "Stop");
  $hbox->Add($this->{stop}, 1, wxLEFT|wxRIGHT, 3);
  $this->{start}->Enable(0);
  $this->{stop}->Enable(0);

  $this->{timer} = Demeter::UI::Athena::Timer->new();
  EVT_BUTTON($this, $this->{standard}, sub{$this->standard});
  EVT_BUTTON($this, $this->{start},    sub{$this->start});
  EVT_BUTTON($this, $this->{stop},     sub{$this->stop});

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: Data watcher');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("watcher")});

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

sub standard {
  my ($this)   = @_;
  $this->{standard}->Enable(1);
  $this->{start}   ->Enable(1);
  $this->{stop}    ->Enable(0);
};

sub start {
  my ($this)   = @_;
  my $base     = $this->{base}->GetValue;
  my $dir      = $this->{dir}->GetPath;
  my $interval = $this->{interval}->GetValue;
  if ($base =~ m{\A\s*\z}) {
    $::app->{main}->status("You did not provide a filename to watch", 'error');
    return;
  };
  if (not -d $dir) {
    $::app->{main}->status("Your directory does not exist", 'error');
    return;
  };
  if (not looks_like_number($interval)) {
    $::app->{main}->status("The timer interval must be a positive integer", 'error');
    return;
  };
  if ($interval <= 0) {
    $::app->{main}->status("The timer interval must be a positive integer", 'error');
    return;
  };
  $this->{timer}->{dir}  = $dir;
  $this->{timer}->{base} = $base;
  $this->{timer}->{size} = 0;
  $this->{dir}  ->Enable(0);
  $this->{base} ->Enable(0);
  $this->{interval}->Enable(0);
  $this->{standard}->Enable(0);
  $this->{start}->Enable(0);
  $this->{stop} ->Enable(1);
  $this->{monitor} = File::Monitor::Lite->new (in => $dir,
					       name => $base.'.*',
					      );
  $this->{monitor}->check;
  $this->{timer}->Start($interval*1000);
  $::app->{main}->status("Started watching for $base in $dir (checking every $interval seconds)");
};

sub stop {
  my ($this) = @_;
  $this->{dir}  ->Enable(1);
  $this->{base} ->Enable(1);
  $this->{interval}->Enable(1);
  $this->{standard}->Enable(1);
  $this->{start}->Enable(0);
  $this->{stop} ->Enable(0);
  $this->{timer}->Stop;
  my $base = $this->{base}->GetValue;
  my $dir  = $this->{dir}->GetPath;
  $::app->{main}->status("Stopped watching for $base in $dir");
};


1;


=head1 NAME

Demeter::UI::Athena::Watcher - A data watcher for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 SYNOPSIS

This module provides an Athena tool for watching data arrive to disk.
As scans finish, they are imported in the current Athena project.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Toggles for pre-processing

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
