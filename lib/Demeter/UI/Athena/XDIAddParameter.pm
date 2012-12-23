package Demeter::UI::Athena::XDIAddParameter;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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
  my ($class, $parent, $data, $namespace) = @_;
  my $this = $class->SUPER::new($parent, -1, "Add metadata to ".$data->name,
				wxDefaultPosition, [300,125],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxRESIZE_BORDER);
  $this -> SetBackgroundColour( wxNullColour );
  EVT_CLOSE($this, \&on_close);

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxALL|wxGROW, 5);
  $hbox->Add(Wx::StaticText->new($this, -1, "Parameter name"), 0, wxTOP|wxLEFT, 5);
  $this->{param} = Wx::TextCtrl->new($this, -1, q{});
  $hbox->Add($this->{param}, 1, wxALL|wxGROW, 3);


  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxALL|wxGROW, 5);
  $hbox->Add(Wx::StaticText->new($this, -1, "Parameter value"), 0, wxTOP|wxLEFT, 5);
  $this->{value} = Wx::TextCtrl->new($this, -1, q{});
  $hbox->Add($this->{value}, 1, wxALL|wxGROW, 3);



  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxALL|wxGROW, 5);

  my $close = Wx::Button->new($this, wxID_CANCEL, q{});
  $hbox->Add($close, 1, wxGROW|wxALL, 2);
  my $ok = Wx::Button->new($this, wxID_OK, q{});
  $hbox->Add($ok, 1, wxGROW|wxALL, 2);

  $this->SetSizer($box);
  return $this;
};

sub on_close {
  my ($self) = @_;
  $self->Show(0);
};

1;

=head1 NAME

Demeter::UI::Athena::XDIAddParameter - A dialog for adding and editing XDI parameters in Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.14.

=head1 SYNOPSIS

This module provides a dialog for adding and editing XDI parameters in
Athena

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
