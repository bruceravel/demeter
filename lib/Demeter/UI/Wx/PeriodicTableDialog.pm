package Demeter::UI::Wx::PeriodicTableDialog;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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
use Wx::Event qw(EVT_CLOSE);
use Demeter::UI::Wx::PeriodicTable;

use base 'Wx::Dialog';


sub new {
  my ($class, $parent, $id, $title, $command) = @_;
  $title ||= 'Periodic Table';

  my $this = $class->SUPER::new($parent, $id, $title, Wx::GetMousePosition, wxDefaultSize,
				wxCLOSE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  EVT_CLOSE($this, \&on_close);
  my $sb = Wx::StatusBar->new($this, 1);
  $sb -> PushStatusText(q{});
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  my $pt   = Demeter::UI::Wx::PeriodicTable->new($this, $command, $sb);

  $vbox   -> Add($pt, 0, wxALL, 2);
  $vbox   -> Add($sb, 0, wxALL, 2);
  $this   -> SetSizerAndFit( $vbox );
  return $this;
};

sub on_close {
  my ($self) = @_;
  $self->Destroy;
};

sub ShouldPreventAppExit {
  0
};

1;

=head1 NAME

Demeter::UI::Wx::PeriodicTableDialog - A periodic table dialog

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

A periodic table dialog can be used in a Wx application:

  my $pt = Demeter::UI::Wx::PeriodicTableDialog
             -> new($parent, $id, $title, $command);
  $pt -> ShowModal;

=head1 DESCRIPTION

This is a periodic table dialog which can be used to call a callback
with the element selected.  Selecting an element will also destroy the
dialog.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

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
