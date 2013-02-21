package  Demeter::UI::Wx::MRU;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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
use Wx::Event qw(EVT_CLOSE EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX);

use List::MoreUtils qw(any);

use Demeter qw(:none);

## type is either a scalar containing a string or an array reference
## pointing to an array of strings
sub new {
  my ($class, $parent, $type, $text, $title) = @_;

  my @types = (ref($type) =~ m{ARRAY}) ? @$type : ($type);

  my @list = Demeter->get_mru_list(@types);
  unshift(@list, ["Open a blank Atoms window", '-----']) if any {$_ eq 'atoms'} @types;
  return -1 if not @list;

  my @mrulist = (ref($type) =~ m{ARRAY})
    ? map { sprintf "[ %s ]  %s", $_->[1], $_->[0] } @list
      : map { $_->[0] } @list;
#  my @toss;
#  $#toss = $#mrulist;

  my $dialog = $class->SUPER::new( $parent,
				   $text  || "Select a recent $type file",
				   $title || "Recent $type files",
				   \@mrulist);
#				   \@toss,
#				   wxDEFAULT_DIALOG_STYLE | wxRESIZE_BORDER | wxOK | wxCANCEL | wxCENTRE,
#				   Wx::GetMousePosition);
  _doublewide($dialog);

  return $dialog;
};

sub _doublewide {
  my ($dialog) = @_;
  my ($w, $h) = $dialog->GetSizeWH;
  $dialog -> SetSizeWH(2*$w, $h);
};

sub _pad {
  my ($string, $width) = @_;
  $width ||= 10;
  my $len = length $string;
  return $string if ($len >= 10);
  my $left = int($len/2);
  my $right = $len - $left;
  return " " x $left . $string . " " x $right;
};

1;

package Wx::SingleChoiceDialog;
sub GetMruSelection {
  my ($self) = @_;
  my $file = $self->GetStringSelection;
  $file =~ s{\A\[.+\]\s+}{}; # this will simply not match if the filename is not preceded by its type
  return $file;
};

1;

=head1 NAME

Demeter::UI::Wx::MRU - A Wx dialog for selecting from Demeter's most recently used files

=head1 VERSION

This documentation refers to Demeter version 0.9.15.

=head1 SYNOPSIS

This provides a dialog for selecting from one or more of Demeter's
most recently used files.

  use Demeter::UI::Wx::MRU;
  $dialog = Demeter::UI::Wx::MRU->new($self, $type,
                                      "Select a recent $type file",
                                      "Recent $type files");
  $file = $dialog->GetMruSelection if ( $dialog->ShowModal != wxID_CANCEL );

C<$type> is one the strings recognized by L<Demeter::MRU>.  C<$file>
is a fully resolve file path.

=head1 DESCRIPTION

This posts a Wx
L<SingleChoiceDialog|http://docs.wxwidgets.org/2.8.4/wx_wxsinglechoicedialog.html#wxsinglechoicedialog>
instrumented to display and selection from one of Demeter's lists of
recently used files.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
