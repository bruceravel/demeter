package Demeter::UI::Artemis::ShowText;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LEFT_DCLICK EVT_BUTTON);
use Demeter::UI::Wx::OverwritePrompt;

my $aleft = Wx::TextAttr->new();
$aleft->SetAlignment(wxTEXT_ALIGNMENT_LEFT);

sub new {
  my ($class, $parent, $content, $title) = @_;

  my $this = $class->SUPER::new($parent, -1, $title,
				Wx::GetMousePosition, [475,400],
				wxMINIMIZE_BOX|wxCLOSE_BOX|wxCAPTION|wxSYSTEM_MENU|wxRESIZE_BORDER
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $text = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
			       wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxTE_RICH2);
  $this->{text} = $text;
  $text -> SetDefaultStyle($aleft);
  $text -> SetFont(Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $text -> SetValue($content);
  $text -> ShowPosition(1);
  $vbox -> Add($text, 1, wxGROW|wxALL, 5);
  my $save = Wx::Button->new($this, wxID_SAVE, q{}, wxDefaultPosition, wxDefaultSize, 0,);
  $vbox -> Add($save, 0, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);
  my $button = Wx::Button->new($this, wxID_OK, q{Close}, wxDefaultPosition, wxDefaultSize, 0,);
  $vbox -> Add($button, 0, wxGROW|wxLEFT|wxRIGHT|wxBOTTOM, 5);

  EVT_BUTTON($this, $save, sub{OnSave(@_)});
  EVT_LEFT_DCLICK($text, sub{OnLeftDclick(@_)}); # if $title =~ m{Overview of this instance};

  $this -> SetSizer( $vbox );
  return $this;
};

sub OnLeftDclick {
  my ($text, $event) = @_;
  #print join("|", $event, $text->HitTest($event->GetPosition)), $/;
  my ($x, $col, $row) = $text->HitTest($event->GetPosition);
  $event->Skip(0);
  my $object;
  my $kind;
  my @line = split(" ", $text->GetLineText($row));
  return if not @line;
 SWITCH: {
    ## a YAML is displayed
    ($line[0] =~ m{\A(sp|parent|data)group:}) and do {
      $kind = ($1 eq 'sp')        ? 'ScatteringPath'
	    : ($1 eq 'data')      ? 'Data'
	    : ($1 eq 'reference') ? 'Data'
	    : ($1 eq 'parent')    ? 'Feff'
	    :                       q{};
      return if not $kind;
      $object = Demeter->mo->fetch($kind, $line[1]);
      last SWITCH;
    };
    ## a Fit YAML is displayed, this is the top part of the display
    ## (ok, lots of other lines will start with a dash, but few will
    ## actually return something from fetch)
    ($line[0] eq '-') and do {
      foreach my $type (qw(GDS Data Path Feff VPath LineShape)) {
	$kind = $type;
	$object = Demeter->mo->fetch($type, $line[1]);
	last SWITCH if $object;
      };
      last SWITCH;
    };
    ## this is the Demeter mode display
    ($line[0] eq 'Mode') and do {
      $kind = "Mode";
      $object = Demeter->mo;
      last SWITCH;
    };
    ($line[2] and (length($line[2]) > 5)) and do {
      $kind = $line[0];
      $object = Demeter->mo->fetch($kind, substr($line[2], 1, -1));
      last SWITCH;
    }
  };
  return if not $object;
  my $str = sprintf("YAML of %s object <%s> (%s)", $kind, $object->name, $object->group);
  Demeter::UI::Artemis::ShowText->new($Demeter::UI::Artemis::frames{main},
				      $object->serialization,
				      $str)
      -> Show;
};

sub OnSave {
  my ($this, $event) = @_;
  my $fd = Wx::FileDialog->new( $this, "Save contents", cwd,
				q{contents.txt},
				"Text files (*.txt)|*.txt",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Not saving contents.");
    return;
  };
  my $fname = $fd->GetPath;
  return if $this->overwrite_prompt($fname, $::app->{main}); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  open (my $C, '>',$fname);
  print $C $this->{text}->GetValue;
  close $C;
  $::app->{main}->status("Wrote contents to '$fname'.");

};

sub ShouldPreventAppExit {
  0
};

1;

=head1 NAME

Demeter::UI::Artemis::ShowText - A text display dialog for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This module provides a text display dialog for Artemis.  It is
instrumented to provide some hyertext like capabilities on the double
click for displays of Demeter object serialization.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
