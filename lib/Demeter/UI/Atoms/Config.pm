package Demeter::UI::Atoms::Config;

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

use strict;
use warnings;
use Carp;

use Xray::Absorption;

use Wx qw( :everything );

use base 'Demeter::UI::Wx::Config';

sub new {
  my ($class, $page, $parent, $statusbar) = @_;
  my $self = $class->SUPER::new($page, \&target);
  $self->{parent}    = $parent;
  $self->{statusbar} = $statusbar;
  $self->populate(['atoms', 'feff', 'pathfinder']);

  return $self;
};

sub target {

};

1;
