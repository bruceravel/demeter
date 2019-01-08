package Demeter::UI::Athena::SpecifyConfig;

=for Copyright
 .
 Copyright (c) 2006-2019 Bruce Ravel (http://bruceravel.github.io/home).
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
use Wx::Event qw(EVT_CLOSE EVT_BUTTON);
use base qw(Wx::Dialog);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Specify element and edge",
				wxDefaultPosition, [300,270],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  #$this -> SetBackgroundColour( $wxBGC );
  EVT_CLOSE($this, \&on_close);

  my $box = Wx::BoxSizer->new( wxVERTICAL );
  my $gbs = Wx::GridBagSizer->new( 5,5 );
  $box->Add($gbs, 0, wxALL, 5);
  $gbs -> Add(Wx::StaticText->new($this, -1, "Element"), Wx::GBPosition->new(0,0));
  $this->{elem} = Wx::TextCtrl->new($this, -1, $::app->{is_z}, wxDefaultPosition, [100,-1]);
  $gbs -> Add($this->{elem}, Wx::GBPosition->new(0,1));

  $gbs -> Add(Wx::StaticText->new($this, -1, "Edge"), Wx::GBPosition->new(1,0));
  $this->{edge} = Wx::TextCtrl->new($this, -1, $::app->{is_edge}, wxDefaultPosition, [100,-1]);
  $gbs -> Add($this->{edge}, Wx::GBPosition->new(1,1));

  $gbs -> Add(Wx::StaticText->new($this, -1, "Margin"), Wx::GBPosition->new(2,0));
  $this->{margin} = Wx::TextCtrl->new($this, -1, $::app->{is_edge_margin}||q{15}, wxDefaultPosition, [100,-1]);
  $gbs -> Add($this->{margin}, Wx::GBPosition->new(2,1));


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxGROW|wxALL, 5);
  my $ok = Wx::Button->new($this, wxID_OK, q{});
  my $close = Wx::Button->new($this, wxID_CANCEL, q{});
  $hbox->Add($ok, 1, wxGROW|wxALL, 5);
  $hbox->Add($close, 1, wxGROW|wxALL, 5);
  #EVT_BUTTON($this, $close, \&on_close);

  $this->SetSizerAndFit($box);
  return $this;
};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
};

1;

=head1 NAME

Demeter::UI::Athena::SpecifyConfig - A tool for enforcing element and edge for imported data

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This provides a simple form for specifying the element and edge that
should be enforced when importing data.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>) and Shelly Kelly

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2019 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
