package  Demeter::UI::Artemis::Journal;

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

use Cwd;

use Wx qw( :everything );
use Wx::Event qw(EVT_CLOSE EVT_BUTTON);
use base qw(Wx::Frame);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Journal]",
				wxDefaultPosition, wxDefaultSize, wxDEFAULT_FRAME_STYLE);
  EVT_CLOSE($this, \&on_close);
  #_doublewide($this);

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $this->{journal} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxTE_RICH2|wxTE_WORDWRAP|wxTE_AUTO_URL);
  $this->{journal} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $vbox -> Add($this->{journal}, 1, wxGROW|wxALL, 5);


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{save} = Wx::Button->new($this, wxID_SAVE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{save}, 1, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  EVT_BUTTON($this, $this->{save}, \&on_save);
  $this->{close} = Wx::Button->new($this, wxID_CLOSE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{close}, 1, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  EVT_BUTTON($this, $this->{close}, \&on_close);
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  $this->SetSizer($vbox);
  return $this;
};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
  $self->GetParent->{toolbar}->ToggleTool(4, 0);
};

sub _doublewide {
  my ($dialog) = @_;
  my ($w, $h) = $dialog->GetSizeWH;
  $dialog -> SetSizeWH(2*$w, $h);
};

sub on_save {
  my ($self) = @_;

  my $fd = Wx::FileDialog->new( $self, "Save journal", cwd,
				$Demeter::UI::Artemis::frames{main}->{projectname}.q{.txt},
				"Text files (*.txt)|*.txt",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $Demeter::UI::Artemis::frames{main}->{statusbar}->SetStatusText("Not saving journal.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  $self->save_journal($fname);
};

sub save_journal {
  my ($self, $fname) = @_;
  open (my $LOG, '>',$fname);
  print $LOG $self->{text}->GetValue;
  close $LOG;
  $Demeter::UI::Artemis::frames{main}->{statusbar}->SetStatusText("Wrote journal to '$fname'.");
};


1;


=head1 NAME

Demeter::UI::Artemis::Journal - A fit journal interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS


=head1 CONFIGURATION


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
