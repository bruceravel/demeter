package  Demeter::UI::Artemis::GDS::Restraint;

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

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX);

use Demeter::Constants qw($NUMBER);

sub new {
  my ($class, $parent, $name) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Build a restraint",
				wxDefaultPosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );
  $vbox -> Add(Wx::StaticText->new($this, -1, "Create a restraint for the parameter $name"), 0, wxALL, 5);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);
  $hbox -> Add(Wx::StaticText->new($this, -1, "Scale by"), 0, wxALL, 5);
  $this->{scale} = Wx::TextCtrl->new($this, -1, 1000);
  $hbox->Add($this->{scale}, 1, wxGROW|wxALL, 2);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);
  $hbox -> Add(Wx::StaticText->new($this, -1, "Lower bound"), 0, wxALL, 5);
  $this->{low} = Wx::TextCtrl->new($this, -1, 0);
  $hbox->Add($this->{low}, 1, wxGROW|wxALL, 2);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);
  $hbox -> Add(Wx::StaticText->new($this, -1, "Upper bound"), 0, wxALL, 5);
  $this->{high} = Wx::TextCtrl->new($this, -1, 4);
  $hbox->Add($this->{high}, 1, wxGROW|wxALL, 2);


  $this->{ok} = Wx::Button->new($this, wxID_OK, "Make restraint", wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $vbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);


  my $gds = $parent->{grid}->{$name};
  if (ref($gds) =~ m{GDS}) {
    my $bestfit = $gds->bestfit || $gds->mathexp;
    ($bestfit = 1) if ($bestfit !~ m{\A$NUMBER\z});
    my ($lo, $hi) = sort {$a <=> $b} ($bestfit/2, $bestfit*2);
    $lo = (abs($lo) < 0.01) ? sprintf("%.6f", $lo) : sprintf("%.3f", $lo);
    $hi = (abs($hi) < 0.01) ? sprintf("%.6f", $hi) : sprintf("%.3f", $hi);
    $this->{low} ->SetValue($lo);
    $this->{high}->SetValue($hi);
  };


  $this -> SetSizerAndFit( $vbox );
  return $this;
};

sub ShouldPreventAppExit {
  0
};

1;

=head1 NAME

Demeter::UI::Artemis::GDS::Restraint - a restraint creation dialog

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 SYNOPSIS

This module provides a dialog for creating a restraint based on an
existing GDS parameter in Artemis

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
