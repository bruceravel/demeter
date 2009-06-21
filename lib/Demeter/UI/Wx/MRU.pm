package  Demeter::UI::Wx::MRU;

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
use Wx::Event qw(EVT_CLOSE EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX);

use Demeter;

my $demeter = Demeter->new();
sub new {
  my ($class, $parent, $type, $text, $title) = @_;

  my @mrulist = $demeter->get_mru_list($type);
  return -1 if not @mrulist;

  my $dialog = $class->SUPER::new( $parent,
				   $text  || "Select a recent $type file",
				   $title || "Recent $type files",
				   \@mrulist );
  _doublewide($dialog);

  return $dialog;;
};

sub _doublewide {
  my ($dialog) = @_;
  my ($w, $h) = $dialog->GetSizeWH;
  $dialog -> SetSizeWH(2*$w, $h);
};
