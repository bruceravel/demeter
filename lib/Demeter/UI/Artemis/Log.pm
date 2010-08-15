package  Demeter::UI::Artemis::Log;

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
use Wx::Event qw(EVT_CLOSE EVT_BUTTON);
use base qw(Wx::Frame);
use Demeter::UI::Artemis::LogText;

use Cwd;

my @font      = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" );
my @bold      = (9, wxTELETYPE, wxNORMAL,   wxBOLD, 0, "" );
my @underline = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 1, "" );

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Log]",
				wxDefaultPosition, [550,650],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  EVT_CLOSE($this, \&on_close);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $this->{name} = q{};
  $this->{text} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
				    wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL);
  $this->{text} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );

  $vbox -> Add($this->{text}, 1, wxGROW, 0);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);

  $this->{save} = Wx::Button->new($this, wxID_SAVE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{save}, 1, wxGROW|wxRIGHT, 2);
  EVT_BUTTON($this, $this->{save}, \&on_save);
  $this->{save}->Enable(0);
  $this->{close} = Wx::Button->new($this, wxID_CLOSE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{close}, 1, wxGROW|wxLEFT, 2);
  EVT_BUTTON($this, $this->{close}, \&on_close);

  $this -> SetSizer($vbox);
  return $this;
};

sub put_log {
  my ($self, $fit) = @_;
  Demeter::UI::Artemis::LogText -> make_text($self->{text}, $fit);
  $self->{save}->Enable(1);
};


sub on_save {
  my ($self) = @_;

  (my $pref = $self->{name}) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $self, "Save log file", cwd, $pref.q{.log},
				"Log files (*.log)|*.log",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $Demeter::UI::Artemis::frames{main}->status("Not saving log file.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  $self->save_log($fname);
};

sub save_log {
  my ($self, $fname) = @_;
  open (my $LOG, '>',$fname);
  print $LOG $self->{text}->GetValue;
  close $LOG;
  $Demeter::UI::Artemis::frames{main}->status("Wrote log file to '$fname'.");
};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
  $self->GetParent->{log_toggle}->SetValue(0);
};

1;

=head1 NAME

Demeter::UI::Artemis::Log - A log file display interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

Examine the log file from the most current fit.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

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
