package Demeter::UI::Wx::AutoSave;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Wx qw( :everything );
use base qw(Wx::SingleChoiceDialog);

use Demeter;

my $demeter = Demeter->new();
sub new {
  my ($class, $parent, $text, $title) = @_;

  opendir(my $stash, $demeter->stash_folder);
  my @list = grep {$_ =~ m{autosave\z}} readdir $stash;
  close $stash;
  return -1 if not @list;
  my @toss = @list;

  my $dialog = $class->SUPER::new( $parent,
				   $text  || "Select an autosave file",
				   $title || "Select an autosave file",
				   \@list,
				   \@toss,
				   wxSTAY_ON_TOP|wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxOK|wxCANCEL|wxCENTRE,
				   Wx::GetMousePosition
				 );
  _doublewide($dialog);

  return $dialog;;
};

sub _doublewide {
  my ($dialog) = @_;
  my ($w, $h) = $dialog->GetSizeWH;
  $dialog -> SetSizeWH(2*$w, $h);
};

1;
