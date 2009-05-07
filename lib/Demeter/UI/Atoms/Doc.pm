package  Demeter::UI::Atoms::Doc;

use Cwd;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);


sub new {
  my ($class, $page, $parent) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $parent->{statusbar};
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{docbox}       = Wx::StaticBox->new($self, -1, 'Document', wxDefaultPosition, wxDefaultSize);
  $self->{docboxsizer}  = Wx::StaticBoxSizer->new( $self->{docbox}, wxVERTICAL );
  $self->{doc} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				   wxTE_MULTILINE|wxHSCROLL|wxALWAYS_SHOW_SB_READONLY);
  $self->{doc}->SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{docboxsizer} -> Add($self->{doc}, 1, wxEXPAND|wxALL, 0);

  $self->{doc}->SetEditable(1);
  $self->{doc}->SetValue("Nothing yet...");
  $self->{doc}->SetEditable(0);

  $vbox -> Add($self->{docboxsizer}, 1, wxEXPAND|wxALL, 5);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

1;

=head1 NAME

Demeter::UI::Atoms::Doc - Atoms' documentation utility

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 DESCRIPTION

This class is used to populate the Documentation tab in the Wx version of Atoms.

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
