package Demeter::UI::Athena::Watcher;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);
use Wx::Perl::TextValidator;

use Demeter::UI::Athena::Timer;
use File::Monitor::Lite;
use Scalar::Util qw(looks_like_number);
use YAML::Tiny;

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

  if (not exists $INC{'File/Monitor/Lite.pm'}) {
    $box->Add(Wx::StaticText->new($this, -1, "The data watcher is not enabled on this computer.\nThe most likely reason is that the perl module File::Monitor::Lite not available."), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
    $box->Add(1,1,1);
  } else {

    my $yaml;
    my $persist = File::Spec->catfile(Demeter->dot_folder, "athena.watcher");
    if (not -e $persist) {
      $yaml->{cwd}       = cwd;
      $yaml->{pattern}   = 0;
      $yaml->{base}      = q{};
      $yaml->{interval}  = 120;
      $yaml->{plot}      = 1;
      $yaml->{mark}      = 1;
      $yaml->{align}     = 1;
      $yaml->{set}       = 1;
      $yaml->{stopafter} = 0;
      my $string .= YAML::Tiny::Dump($yaml);
      open(my $P, '>'.$persist);
      print $P $string;
      close $P;
    };
    $yaml = YAML::Tiny::Load(Demeter->slurp($persist));

    $this->{count} = 0;

    ## folder
    my $dirbox       = Wx::StaticBox->new($this, -1, 'Folder to watch', wxDefaultPosition, wxDefaultSize);
    my $dirboxsizer  = Wx::StaticBoxSizer->new( $dirbox, wxVERTICAL );
    $box->Add($dirboxsizer, 0, wxGROW|wxALL, 5);

    $this->{dir} = Wx::DirPickerCtrl->new($this, -1, $yaml->{cwd}||cwd, "Select as folder",
					  wxDefaultPosition, wxDefaultSize,
					  wxDIRP_DIR_MUST_EXIST|wxDIRP_CHANGE_DIR|wxDIRP_USE_TEXTCTRL);
    $dirboxsizer -> Add($this->{dir}, 1, wxGROW|wxALL, 0);

    ## pattern
    my $patternbox       = Wx::StaticBox->new($this, -1, 'File pattern to watch for', wxDefaultPosition, wxDefaultSize);
    my $patternboxsizer  = Wx::StaticBoxSizer->new( $patternbox, wxHORIZONTAL );
    $box->Add($patternboxsizer, 0, wxGROW|wxALL, 5);

    $this->{pattern} = Wx::RadioBox->new($this, -1, q{Pattern type}, wxDefaultPosition, wxDefaultSize,
					 ["File basename", "Wildcard", "Regular expression"], 1, wxRA_SPECIFY_COLS);
    $patternboxsizer->Add($this->{pattern}, 1, wxALL, 5);
    $this->{pattern}->SetSelection($yaml->{pattern});
    my $vbox = Wx::BoxSizer->new(wxVERTICAL);
    $patternboxsizer->Add($vbox, 1, wxLEFT|wxRIGHT, 3);

    $vbox->Add(Wx::StaticText->new($this, -1, "File pattern"), 0, wxALL, 5);
    $this->{base} = Wx::TextCtrl->new($this, -1, $yaml->{base}||q{});
    $vbox->Add($this->{base}, 1, wxGROW|wxLEFT|wxRIGHT, 5);
    $this->{explain} = Wx::Button->new($this, -1, "Explain pattern types");
    $vbox->Add($this->{explain}, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);

    ## folder
    my $paramsbox       = Wx::StaticBox->new($this, -1, 'Parameters', wxDefaultPosition, wxDefaultSize);
    my $paramsboxsizer  = Wx::StaticBoxSizer->new( $paramsbox, wxVERTICAL );
    $box->Add($paramsboxsizer, 0, wxGROW|wxALL, 5);

    my $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
    $paramsboxsizer->Add($hbox, 0, wxGROW|wxALL, 3);
    $hbox->Add(Wx::StaticText->new($this, -1, "Interval"), 0, wxLEFT|wxRIGHT|wxTOP, 3);
    $this->{interval} = Wx::TextCtrl->new($this, -1, $yaml->{interval}||Demeter->co->default(qw(watcher interval)), wxDefaultPosition, [60,-1]);
    $hbox->Add($this->{interval}, 0, wxLEFT|wxRIGHT, 3);
    $hbox->Add(Wx::StaticText->new($this, -1, "seconds"), 0, wxLEFT|wxRIGHT|wxTOP, 3);
    $this->{interval} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9]) ) );

    $hbox -> Add(1,1,1);

    $hbox->Add(Wx::StaticText->new($this, -1, "Stop after"), 0, wxLEFT|wxRIGHT|wxTOP, 3);
    $this->{stopafter} = Wx::TextCtrl->new($this, -1, $yaml->{stopafter}||0, wxDefaultPosition, [60,-1]);
    $hbox->Add($this->{stopafter}, 0, wxLEFT|wxRIGHT, 3);
    $hbox->Add(Wx::StaticText->new($this, -1, "scans"), 0, wxLEFT|wxRIGHT|wxTOP, 3);
    $this->{stopafter} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9]) ) );



    $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
    $paramsboxsizer->Add($hbox, 0, wxGROW|wxALL, 5);
    $this->{mark}  = Wx::CheckBox->new($this, -1, "Mark each group");
    $hbox->Add($this->{mark}, 1, wxLEFT|wxRIGHT, 3);
    $this->{align} = Wx::CheckBox->new($this, -1, "Align each group");
    $hbox->Add($this->{align}, 1, wxLEFT|wxRIGHT, 3);
    $this->{set}   = Wx::CheckBox->new($this, -1, "Constrain parameters");
    $hbox->Add($this->{set}, 1, wxLEFT|wxRIGHT, 3);

    $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
    $paramsboxsizer->Add($hbox, 0, wxGROW|wxALL, 5);
    $this->{plot} = Wx::CheckBox->new($this, -1, "Plot marked data each time a file is imported");
    $hbox->Add($this->{plot}, 1, wxLEFT|wxRIGHT, 3);

    $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
    $box->Add($hbox, 0, wxGROW|wxALL, 3);
    $this->{standard} = Wx::Button->new($this, -1, "Import the first file");
    $hbox->Add($this->{standard}, 1, wxLEFT|wxRIGHT, 3);



    $this->{$_}->SetValue($yaml->{$_}) foreach (qw(plot mark align set));

    $hbox = Wx::BoxSizer->new(wxHORIZONTAL);
    $box->Add($hbox, 0, wxGROW|wxALL, 3);
    $this->{start} = Wx::Button->new($this, wxID_APPLY, "Start");
    $hbox->Add($this->{start}, 1, wxLEFT|wxRIGHT, 3);
    $this->{stop} = Wx::Button->new($this, wxID_STOP, "Stop");
    $hbox->Add($this->{stop}, 1, wxLEFT|wxRIGHT, 3);
    $this->{start}->Enable(0);
    $this->{stop}->Enable(0);

    $this->{timer} = Demeter::UI::Athena::Timer->new();
    $this->{timer}->{fname} = q{};
    $this->{timer}->{prev}  = q{};
    EVT_BUTTON($this, $this->{explain},  sub{$this->explain_patterns});
    EVT_BUTTON($this, $this->{standard}, sub{$this->standard});
    EVT_BUTTON($this, $this->{start},    sub{$this->start});
    EVT_BUTTON($this, $this->{stop},     sub{$this->stop(0)});

    $app -> mouseover(($this->{dir}->GetChildren)[0], "Choose the folder to watch for new scans.");
    #$app -> mouseover(($this->{dir}->GetChildren)[1], "Choose the folder to watch for new scans.");
    #$app -> mouseover($this->{pattern},   "Choose the kind of filename matching pattern.");
    $app -> mouseover($this->{base},      "Provide the pattern for the names of files to be watched.");
    $app -> mouseover($this->{interval},  "Specify the time interval in seconds between checks on the watched folder.");
    $app -> mouseover($this->{stopafter}, "Stop watching after a specified number of scans have been imported.");
    $app -> mouseover($this->{mark},      "Mark each scan as it is imported.");
    $app -> mouseover($this->{align},     "Align each scan to the first scan.");
    $app -> mouseover($this->{set},       "Constrain all parameters for each scan to those of the first scan.");
    $app -> mouseover($this->{plot},      "Plot marked groups in energy as each scan is imported.");
    $app -> mouseover($this->{standard},  "Import the initial scan, which is the one against which all subsequent scans will be aligned and constrained.");
    $app -> mouseover($this->{start},     "Start watching for new scans.");
    $app -> mouseover($this->{stop},      "Stop watching for new scans");

    $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example
  };

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
  my $busy = Wx::BusyCursor->new();
  $::app -> Import(q{}, no_main=>1);
  $this->{yaml} = Demeter->slurp(File::Spec->catfile(Demeter->dot_folder, "athena.column_selection"));
  $this->{standard_group} = $::app->{most_recent};
  my ($name, $group) = ($::app->{most_recent}->name, $::app->{most_recent}->group);
  $this->{yaml} =~ s{preproc_standard: .*}{preproc_standard: $name};
  $this->{yaml} =~ s{preproc_stgroup: .*}{preproc_stgroup: $group};
  my $mark  = ($this->{mark} ->GetValue) ? 1 : 0;
  my $align = ($this->{align}->GetValue) ? 1 : 0;
  my $set   = ($this->{set}  ->GetValue) ? 1 : 0;
  $this->{yaml} =~ s{preproc_mark: .*}{preproc_mark: $mark};
  $this->{yaml} =~ s{preproc_align: .*}{preproc_align: $align};
  $this->{yaml} =~ s{preproc_set: .*}{preproc_set: $set};
  $this->{yaml} =~ s{datatype: xanes}{datatype: xmu};

  $this->{standard}->Enable(0);
  $this->{start}   ->Enable(1);
  $this->{stop}    ->Enable(0);
  $::app->{main}->status("Set " . $this->{standard_group}->name . " as the file watcher standard");
  undef $busy;
};

sub start {
  my ($this)   = @_;
  my $base     = $this->{base}->GetValue;
  my $dir      = $this->{dir}->GetPath;
  my $interval = $this->{interval}->GetValue;
  if ($base =~ m{\A\s*\z}) {
    $::app->{main}->status("You did not provide a filename pattern to watch", 'error');
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

  ## need a check that standard is set and has a file associated....

  $this->{timer}->{dir}  = $dir;
  $this->{timer}->{base} = $base;
  $this->{count} = 0;

  my $pattern = ($this->{pattern}->GetSelection == 0) ? $base.'.*'
              : ($this->{pattern}->GetSelection == 1) ? $base
              : ($this->{pattern}->GetSelection == 2) ? $base
	      :                                         $base.'.*';
  $this->{match} = $pattern;
  if ($this->{pattern}->GetSelection == 2) {
    my $re;
    my $is_ok = eval 'local $SIG{__DIE__}=q{}; $re = qr/$pattern/i';
    if ($is_ok) {
      $pattern = $re;
      $this->{match} = '/'.$this->{match}.'/';
    } else {
      my $message = $@;
      $message =~ s{at\s+\(.*}{};
      $::app->{main}->status("/$pattern/ is not a valid regular expression: $message", 'error');
      return;
    };
  };
  $this->{timer}->{size} = -s $this->{standard_group}->file;
  $this->{$_}   -> Enable(0) foreach (qw(dir pattern base interval standard start mark align set));
  $this->{stop} -> Enable(1);

  my $persist = File::Spec->catfile(Demeter->dot_folder, "athena.watcher");
  my $yaml;
  $yaml->{cwd}	     = $dir;
  $yaml->{base}	     = $base;
  $yaml->{pattern}   = $this->{pattern}->GetSelection;
  $yaml->{interval}  = $interval;
  $yaml->{plot}	     = $this->{plot} ->GetValue;
  $yaml->{mark}	     = $this->{mark} ->GetValue;
  $yaml->{align}     = $this->{align}->GetValue;
  $yaml->{set}	     = $this->{set}  ->GetValue;
  $yaml->{stopafter} = $this->{stopafter} ->GetValue;
  my $string .= YAML::Tiny::Dump($yaml);
  open(my $P, '>'.$persist);
  print $P $string;
  close $P;

  $this->{monitor}  = File::Monitor::Lite->new (in => $dir, name => $pattern, );
  $this->{monitor} -> check;
  $this->{timer}   -> Start($interval*1000);

  $::app->{main}->status(sprintf("Started watching for %s in %s (checking every %d seconds)", $this->{match}, $dir, $interval));
};

sub stop {
  my ($this, $noimport) = @_;

  if ($this->{timer}->{fname} and (-e $this->{timer}->{fname}) and (not $noimport)) {
    $::app->{main}->status("Importing watched file " . $this->{timer}->{fname});
    open(my $Y, '>', File::Spec->catfile(Demeter->dot_folder, "athena.column_selection"));
    print $Y $this->{yaml};
    close $Y;

    $::app->Import($this->{timer}->{fname}, no_main=>1, no_interactive=>1);
    $::app->plot(q{}, q{}, 'E', 'marked') if $this->{plot}->GetValue;
  };
  $this->{timer}->{fname} = q{};
  $this->{timer}->{prev}  = q{};

  $this->{$_}   -> Enable(1) foreach (qw(dir pattern base interval standard start mark align set));
  $this->{stop} -> Enable(0);
  $this->{timer}->Stop;
  my $base = $this->{base}->GetValue;
  my $dir  = $this->{dir}->GetPath;
  if ($noimport) {
    $::app->{main}->status(sprintf("Stopped watching for %s in %s after %d scans", $this->{match}, $dir, $this->{count}));
  } else {
    $::app->{main}->status(sprintf("Stopped watching for %s in %s", $this->{match}, $dir));
  };
  $this->{count} = 0;
};

sub explain_patterns {
  my ($this) = @_;
  my $text   = Demeter->dd->template("report", "file_patterns");
  my $dialog = Demeter::UI::Artemis::ShowText->new($::app->{main}, $text, 'Data watcher patterns') -> Show;
};


1;


=head1 NAME

Demeter::UI::Athena::Watcher - A data watcher for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.14.

=head1 SYNOPSIS

This module provides an Athena tool for watching data arrive to disk.
As scans finish, they are imported in the current Athena project.

=head1 CONFIGURATION

The data watcher is disabled by default.  It is enabled via the
C<athena--E<gt>show_watcher> parameter.

Some defaults are set from the C<watcher> configuration group.

Persitance is handled via F<athena.watcher>, a YAML file, in the dot
folder.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

What about short files (due to a dump or lost lock)

=item *

Using a XANES scan as standard for EXAFS data makes preproc_set
confusing

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
