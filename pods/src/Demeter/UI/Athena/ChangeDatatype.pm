package  Demeter::UI::Athena::ChangeDatatype;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

use Wx qw( :everything);
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_RADIOBUTTON EVT_CHECKBOX EVT_CHOICE EVT_BUTTON);
use Wx::Perl::Carp;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

sub new {
  my ($class, $parent, $app) = @_;

  my $this = $class->SUPER::new($parent, -1, "Athena: Change datatype",
				wxDefaultPosition, [-1,-1],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP);

  my $box  = Wx::BoxSizer->new( wxVERTICAL );

  $this->{how} = Wx::RadioBox->new($this, -1, "Change datatype for...", wxDefaultPosition, wxDefaultSize,
				   ["current group", "all marked groups", "all groups"], 1, wxRA_SPECIFY_ROWS);
  $box -> Add($this->{how}, 0, wxALL, 5);


  $this->{to} = Wx::RadioBox->new($this, -1, "Change datatype to...", wxDefaultPosition, wxDefaultSize,
				  ["$MU(E)", "xanes", "norm(E)"], 1, wxRA_SPECIFY_ROWS); #, "$CHI(k)", "Feff's xmu.dat"
  $box->Add($this->{to},  0, wxALL, 5);

  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 0, wxGROW|wxALL, 5);
  $this->{ok}     = Wx::Button->new($this, wxID_OK, "OK", wxDefaultPosition, wxDefaultSize, 0, );
  $this->{close}  = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $hbox->Add($this->{ok},    1, wxGROW|wxALL, 5);
  $hbox->Add($this->{close}, 1, wxGROW|wxALL, 5);

  $this -> SetSizerAndFit($box);
  return $this;
};

1;

=head1 NAME

Demeter::UI::Athena::ChangeDatatype - A dialog for changing data type in Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module provides a dialog for changing data type for one or more
data groups in Athena.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
