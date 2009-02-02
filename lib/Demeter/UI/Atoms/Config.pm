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
  my ($self, $parent, $param, $value, $save) = @_;

 SWITCH: {
    ($param eq 'plotwith') and do {
      $Demeter::UI::Atoms::demeter->plot_with($value);
      last SWITCH;
    };
  };

  ($save)
    ? $self->{statusbar}->SetStatusText("Now using $value for $parent-->$param and an ini file was saved")
      : $self->{statusbar}->SetStatusText("Now using $value for $parent-->$param");

};

1;

=head1 NAME

Demeter::UI::Atoms::Config - Atoms' configuration utility

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 DESCRIPTION

This class is used to populate the Configuration tab in the Wx version of Atoms.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
