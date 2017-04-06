package  Demeter::UI::Artemis::Journal;

=for Copyright
 .
 Copyright (c) 2006-2017 Bruce Ravel (http://bruceravel.github.io/home).
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
use Wx::Event qw(EVT_CLOSE EVT_ICONIZE EVT_BUTTON);
use base qw(Wx::Frame);

use Demeter::UI::Artemis::Close;
##use Demeter::UI::Wx::Printing;
use Demeter::UI::Wx::Colours;

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [Journal]",
				wxDefaultPosition, wxDefaultSize, wxDEFAULT_FRAME_STYLE);
  $this -> SetBackgroundColour( $wxBGC );
  EVT_CLOSE($this, \&on_close);
  EVT_ICONIZE($this, \&on_close);
  #_doublewide($this);

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $this->{journal} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [550,350],
				       wxTE_MULTILINE|wxTE_RICH2|wxTE_WORDWRAP|wxTE_AUTO_URL);
  $this->{journal} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $vbox -> Add($this->{journal}, 1, wxGROW|wxALL, 5);


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{save} = Wx::Button->new($this, wxID_SAVE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{save}, 1, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  EVT_BUTTON($this, $this->{save}, \&on_save);

  # $this->{preview} = Wx::Button->new($this, wxID_PREVIEW, q{}, wxDefaultPosition, wxDefaultSize);
  # $hbox -> Add($this->{preview}, 1, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  # EVT_BUTTON($this, $this->{preview}, sub{on_preview(@_, 'journal')});

  # $this->{print} = Wx::Button->new($this, wxID_PRINT, q{}, wxDefaultPosition, wxDefaultSize);
  # $hbox -> Add($this->{print}, 1, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  # EVT_BUTTON($this, $this->{print}, sub{on_print(@_, 'journal')});

  $this->{doc} = Wx::Button->new($this, wxID_ABOUT, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{doc}, 1, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  EVT_BUTTON($this, $this->{doc}, sub{$::app->document('logjournal', 'thejournalwindow')});

  $this->{close} = Wx::Button->new($this, wxID_CLOSE, q{}, wxDefaultPosition, wxDefaultSize);
  $hbox -> Add($this->{close}, 1, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);
  EVT_BUTTON($this, $this->{close}, \&on_close);
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  $this->SetSizerAndFit($vbox);
  return $this;
};


sub _doublewide {
  my ($dialog) = @_;
  my ($w, $h) = $dialog->GetSizeWH;
  $dialog -> SetSizeWH(2*$w, $h);
};

sub on_save {
  my ($self) = @_;

  my $fd = Wx::FileDialog->new( $self, "Save journal", cwd,
				$::app->{main}->{projectname}.q{.txt},
				"Text files (*.txt)|*.txt",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Not saving journal.");
    return;
  };
  my $fname = $fd->GetPath;
  #return if $self->overwrite_prompt($fname, $::app->{main}); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $self->save_journal($fname);
};

sub save_journal {
  my ($self, $fname) = @_;
  open (my $LOG, '>',$fname);
  print $LOG $self->{journal}->GetValue;
  close $LOG;
  $::app->{main}->status("Wrote journal to '$fname'.") if ($fname !~ m{_dem_});
};


1;


=head1 NAME

Demeter::UI::Artemis::Journal - A fit journal interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS


=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2017 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
