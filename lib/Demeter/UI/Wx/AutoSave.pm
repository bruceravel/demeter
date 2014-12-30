package Demeter::UI::Wx::AutoSave;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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
use base qw(Wx::SingleChoiceDialog);

use Demeter qw(:none);

sub new {
  my ($class, $parent, $text, $title) = @_;

  opendir(my $stash, Demeter->stash_folder);
  ##                                         vvvvvv this is an icky kludge!
  my @list = grep {$_ =~ m{autosave\z} and $_ !~ m{\AAthena}} readdir $stash;
  closedir $stash;
  return -1 if not @list;
  my @toss = @list;

  my $dialog = $class->SUPER::new( $parent,
				   $text  || "Restore from an autosave file",
				   $title || "Restore from an autosave file",
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
  $dialog -> SetSizeWH(2*$w, $h/2);
};

1;

=head1 NAME

Demeter::UI::Wx::AutoSave - A Wx dialog for restoring an autosave file

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This provides a dialog for selecting from one or more of Demeter's
most recently used files.

  use Demeter::UI::Wx::AutoSave;
  $dialog = Demeter::UI::Wx::AutoSave->new($self);
  if ( $dialog->ShowModal != wxID_CANCEL ) {
     $project = File::Spec->catfile($autosave_path, $dialog->GetString);
  };

The returned string is not a fully resolve file path.

=head1 DESCRIPTION

This posts a Wx
L<SingleChoiceDialog|http://docs.wxwidgets.org/2.8.4/wx_wxsinglechoicedialog.html#wxsinglechoicedialog>
showing all possible autosave files found in Demeter's stash folder.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
