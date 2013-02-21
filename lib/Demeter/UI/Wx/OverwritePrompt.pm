package Demeter::UI::Wx::OverwritePrompt;

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
use Carp;
use Wx qw( :everything );
use base qw( Exporter );
our @EXPORT = qw(overwrite_prompt);

## return true if this file should not be overwritten
## return false if writing the file is ok (does not exists or can be overwritten)
sub overwrite_prompt {
  my ($self, $file, $frame) = @_;
  $frame ||= $self;
  return 0 if (not -e $file);
  my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
					       "Overwrite existing file \"$file\"?",
					       "Overwrite file?",
					       "Overwrite"
					      ); ##Wx::GetMousePosition --  how is this done?
  my $ok = $yesno->ShowModal;
  if ($ok == wxID_NO) {
    $frame->status("Not overwriting \"$file\"");
    return 1;
  };
  return 0;
};

1;

=head1 NAME

Demeter::UI::Wx::OverwritePrompt - A prompt dialog for overwriting a file

=head1 VERSION

This documentation refers to Demeter version 0.9.15.

=head1 SYNOPSIS

After querying the user for a file using Wx::FileDialog:

  my $file = $fd->GetPath;
  return if $frame->overwrite_prompt($file);

The calling object should be a Wx::Frame in Athena or Artemis.  Those
two programs add some functionality, including this, to Wx::Frame.

If that frame does not have its own statusbar, then you must specify a
second frame which does have a statusbar in which to display any
status messages:

  my $file = $fd->GetPath;
  return if $frame->overwrite_prompt($file, $other_frame);

This is not a general purpose tool.  It has hardwired aspects that
rely upon coding conventions used in Athena and Artemis.

=head1 DESCRIPTION

The exports a method that posts a prompt about whether to overwrite a
file that exists.  It returns true if the user does not want to
overwrite and returns false either if the file is to be overwritten or
if the file does not already exist.

This should not be necessary.  It is an inelegant alternative to
specifying the C<wxFD_OVERWRITE_PROMPT> style for Wx::FileDialog.
However there exists a bug in gtk 2.20 (is that right? others?) that
leads to serious misbehaviour in certain situations.  Using that
style, it is possible to have Wx::FileDialog return the wrong file,
resulting in the incorrect file being overwritten.

Here is more information:
L<https://bugzilla.gnome.org/show_bug.cgi?id=631908> and
L<https://bugs.launchpad.net/ubuntu/+source/gtk+2.0/+bug/558674>.

Until this bug is fixed at the level of gtk, the
C<wxFD_OVERWRITE_PROMPT> style cannot be safely used.

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
