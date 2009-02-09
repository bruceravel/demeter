package  Demeter::UI::Artemis::History;

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
use base qw(Wx::Frame);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new($_[0], -1, "Artemis: Fit history",
				wxDefaultPosition, wxDefaultSize,
				wxDEFAULT_FRAME_STYLE);



};

1;
