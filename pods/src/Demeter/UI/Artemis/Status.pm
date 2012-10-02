package  Demeter::UI::Artemis::Status;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

use Cwd;
use List::Util qw(max);

my @font = (9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" );

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Status buffer]",
				wxDefaultPosition, [650,400],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  EVT_CLOSE($this, \&on_close);
  $this -> SetBackgroundColour( wxNullColour );
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $this->{name} = q{};
  my $id = q{}; #sprintf("[%s] %s (%s)\n", DateTime->now, 'Starting Artemis', Demeter->identify);
  $this->{text} = Wx::TextCtrl->new($this, -1, $id, wxDefaultPosition, wxDefaultSize,
				    wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL|wxTE_RICH2);
  $this->{text} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );

  $this->{normal} = Wx::TextAttr->new(Wx::Colour->new('#000000'), wxNullColour, Wx::Font->new( @font ) );
  $this->{date}   = Wx::TextAttr->new(Wx::Colour->new('#acacac'), wxNullColour, Wx::Font->new( @font ) );
  $this->{wait}   = Wx::TextAttr->new(Wx::Colour->new('#008800'), wxNullColour, Wx::Font->new( @font ) );
  $this->{error}  = Wx::TextAttr->new(Wx::Colour->new("#aa0000"), wxNullColour, Wx::Font->new( @font ) );
  $this->{alert}  = Wx::TextAttr->new(Wx::Colour->new("#d9bf89"), wxNullColour, Wx::Font->new( @font ) );

  $vbox -> Add($this->{text}, 1, wxGROW, 0);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);

  $this->{save} = Wx::Button->new($this, wxID_SAVE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{save}, 1, wxGROW|wxRIGHT, 2);
  EVT_BUTTON($this, $this->{save}, \&on_save);
  $this->{close} = Wx::Button->new($this, wxID_CLOSE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{close}, 1, wxGROW|wxLEFT, 2);
  EVT_BUTTON($this, $this->{close}, \&on_close);

  $this -> SetSizer($vbox);
  return $this;
};



sub on_save {
  my ($self) = @_;

  (my $pref = $self->{name}) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $self, "Save status buffer", cwd, q{echo.log},
				"Log files (*.log)|*.log",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Not saving status buffer to log file.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  return if $self->overwrite_prompt($fname, $::app->{main});
  $self->save_log($fname);
};


sub save_log {
  my ($self, $fname) = @_;
  open (my $LOG, '>',$fname);
  print $LOG $self->{text}->GetValue;
  close $LOG;
  $Demeter::UI::Artemis::frames{main}->status("Wrote status log file to '$fname'.");
};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
};

sub put_text {
  my ($self, $text, $type) = @_;
  return if ($text =~ m{\A\s*\z});

  my $was = $self -> {text} -> GetInsertionPoint;
  $self->{text}->AppendText(sprintf "[%s]", DateTime->now);
  my $is = $self -> {text} -> GetInsertionPoint;
  $self->{text}->SetStyle($was, $is, $self->{date});

  $was = $self -> {text} -> GetInsertionPoint;
  $self->{text}->AppendText(sprintf " %s\n", $text);
  $is = $self -> {text} -> GetInsertionPoint;
  $self->{text}->SetStyle($was, $is, $self->{$type});
};

1;


=head1 NAME

Demeter::UI::Artemis::Status - A statusbar message buffer for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.13.

=head1 SYNOPSIS

This module provides a window for logging and colorizing statusbar
messages.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

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
