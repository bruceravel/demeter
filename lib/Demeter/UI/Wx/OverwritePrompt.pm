package Demeter::UI::Wx::OverwritePrompt;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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
  my $yesno = Wx::MessageDialog->new($self,
				     "Overwrite existing file \"$file\"?",
				     "Overwrite file?",
				     wxYES_NO|wxYES_DEFAULT|wxICON_QUESTION,
				    );
                                    ##Wx::GetMousePosition  how is this done?
  my $ok = $yesno->ShowModal;
  if ($ok == wxID_NO) {
    $frame->status("Not overwriting \"$file\"");
    return 1;
  };
  return 0;
};

1;
