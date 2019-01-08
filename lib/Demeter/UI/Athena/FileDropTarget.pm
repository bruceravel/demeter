package Demeter::UI::Athena::FileDropTarget;

use Wx::DND;
use base qw(Wx::FileDropTarget);
use List::MoreUtils qw(any);

sub new {
  my $class = shift;
  my $box = shift;
  my $this = $class->SUPER::new( @_ );
  return $this;
};

sub OnDropFiles {
  my( $this, $x, $y, $files ) = @_;
  #$::app->{main}->status( "Dropped ".join(", ", @$files)." at ($x, $y)" );
  if (any {-d $_} @$files) {
    $::app->{main}->status("You cannot drop folders onto Athena group list", 'alert');
    return 0;
  };
  $::app->Import($files);
  $::app->{main}->{list}->Update;
  return 1;
};

1;


=head1 NAME

Demeter::UI::Athena::FileDropTarget - A file drop target for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This module provides a way to process drag-n-drop events from the
computer's file manager.  File dropped will be imported using the
normal data import method.  Folders (directories) will not be
processed.

=head1 DEPENDENCIES

Wx::DND.

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2019 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
