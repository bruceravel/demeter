package Demeter::UI::Athena::XDI;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "XDI: File metadata";

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  ## versioning information
  my $versionbox       = Wx::StaticBox->new($this, -1, 'Versions', wxDefaultPosition, wxDefaultSize);
  my $versionboxsizer  = Wx::StaticBoxSizer->new( $versionbox, wxHORIZONTAL );
  $this->{sizer}      -> Add($versionboxsizer, 0, wxALL|wxGROW, 5);

  $this->{xdi}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [ 60,-1], wxTE_READONLY);
  $this->{apps} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [200,-1], wxTE_READONLY);
  $versionboxsizer -> Add(Wx::StaticText->new($this, -1, "XDI version"),  0, wxALL, 5);
  $versionboxsizer -> Add($this->{xdi}, 0, wxALL|wxALIGN_CENTER, 5);
  $versionboxsizer -> Add(Wx::StaticText->new($this, -1, "Applications"), 0, wxALL, 5);
  $versionboxsizer -> Add($this->{apps}, 1, wxALL|wxALIGN_CENTER, 5);

  ## Defined fields
  my $definedbox      = Wx::StaticBox->new($this, -1, 'Defined fields', wxDefaultPosition, wxDefaultSize);
  my $definedboxsizer = Wx::StaticBoxSizer->new( $definedbox, wxVERTICAL );
  $this->{sizer}     -> Add($definedboxsizer, 1, wxALL|wxGROW, 5);
  $this->{defined}    = Wx::ScrolledWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  $definedboxsizer->Add($this->{defined}, 1, wxALL|wxGROW, 5);
  my $defbox  = Wx::BoxSizer->new( wxVERTICAL );
  $this->{defined} -> SetSizer($defbox);
  $this->{defined} -> SetScrollbars(0, 20, 0, 50);

  my $gbs = Wx::GridBagSizer->new( 5, 5 );
  my $i = 0;
  foreach my $df ('applications', 'beamline', 'source', 'undulator_harmonic',
		  'ring_energy', 'ring_current', 'collimation', 'crystal',
		  'd_spacing', 'focusing', 'harmonic_rejection', 'edge_energy',
		  'start_time', 'end_time', 'abscissa', 'mu_transmission',
		  'mu_fluorescence', 'mu_reference',) {
    $gbs->Add(Wx::StaticText->new($this->{defined}, -1, ucfirst($df)), Wx::GBPosition->new($i,0));
    $this->{$df} = Wx::TextCtrl->new($this->{defined}, -1, q{}, wxDefaultPosition, [300,-1], wxTE_READONLY);
    $gbs->Add($this->{$df}, Wx::GBPosition->new($i,1));
    ++$i;
  };
  $defbox->Add($gbs, 0, wxALL, 0);

  ## extension fields
  my $extensionbox      = Wx::StaticBox->new($this, -1, 'Extension fields', wxDefaultPosition, wxDefaultSize);
  my $extensionboxsizer = Wx::StaticBoxSizer->new( $extensionbox, wxVERTICAL );
  $this->{sizer}       -> Add($extensionboxsizer, 1, wxALL|wxGROW, 5);
  $this->{extensions}   = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					     wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_READONLY);
  $extensionboxsizer->Add($this->{extensions}, 1, wxALL|wxGROW, 5);

  ## comments
  my $commentsbox      = Wx::StaticBox->new($this, -1, 'Comments', wxDefaultPosition, wxDefaultSize);
  my $commentsboxsizer = Wx::StaticBoxSizer->new( $commentsbox, wxVERTICAL );
  $this->{sizer}      -> Add($commentsboxsizer, 1, wxALL|wxGROW, 5);
  $this->{comments}    = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					    wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL);
  $commentsboxsizer->Add($this->{comments}, 1, wxALL|wxGROW, 5);

  #$box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: XDI/file metadata');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("xdi")});

  $this->SetSizerAndFit($box);
  return $this;
};

## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

## yes, there is some overlap between what push_values and mode do.
## This separation was useful in Main.pm.  Some of the other tools
## make mode a null op.

1;


=head1 NAME

Demeter::UI::Athena::____ - A ____ for Athena

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
