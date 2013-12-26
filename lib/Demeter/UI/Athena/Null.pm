package Demeter::UI::Athena::Null;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "---------------------------------------------------";	# used in the Choicebox and in status bar messages to identify this tool

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  return $this;
};
sub pull_values {1};
sub push_values {1};
sub mode {1};

1;


=head1 NAME

Demeter::UI::Athena::Null - Null page

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
