package Demeter::UI::Artemis::DataDropTarget;

use Wx::DND;
use base qw(Wx::FileDropTarget);
use Demeter::UI::Artemis::Import;

sub new {
  my $class = shift;
  my $box = shift;
  my $this = $class->SUPER::new( @_ );
  return $this;
};

sub OnDropFiles {
  my( $this, $x, $y, $files ) = @_;
  #$::app->{main}->status( "Dropped ".join(", ", @$files)." at ($x, $y)" );
  if ($#{$files} > 0) {
    $::app->{main}->status("You can only drop one file at a time onto Artemis' data box", 'alert');
    return 0;
  };
  if (-d $files->[0]) {
    $::app->{main}->status("You cannot drop a folder onto Artemis' data box", 'alert');
    return 0;
  };
  if (Demeter->is_zipproj($files->[0],0,'fpj')) {
    Import('fpj', $files->[0]);
    return 1;
  };
  if (not Demeter->is_prj($files->[0])) {
    $::app->{main}->status($files->[0]." is not an Athena project file", 'alert');
    return 0;
  };
  Import('prj', $files->[0]);
  #$::app->{main}->{list}->Update;
  return 1;
};

1;


=head1 NAME

Demeter::UI::Artemis::FileDropTarget - An Athena project file  drop target for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This module provides a way to process drag-n-drop events from the
computer's file manager.  Files dropped will be imported using the
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

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
