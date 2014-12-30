package  Demeter::UI::Artemis::Data::Quickfs;

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

use Chemistry::Elements qw(get_Z);

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX EVT_CHOICE);
use Demeter::UI::Wx::PeriodicTableDialog;

sub new {
  my ($class, $parent) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Set up a quick first shell path",
				Wx::GetMousePosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $gbs = Wx::GridBagSizer->new( 6, 10 );
  $vbox -> Add($gbs, 0, wxGROW|wxALL, 5);

  $gbs -> Add( Wx::StaticText -> new($this, -1, 'Absorber:'),  Wx::GBPosition->new(0,0));
  $gbs -> Add( Wx::StaticText -> new($this, -1, 'Scatterer:'), Wx::GBPosition->new(0,3));
  $gbs -> Add( Wx::StaticText -> new($this, -1, 'Edge:'),      Wx::GBPosition->new(1,0));
  $gbs -> Add( Wx::StaticText -> new($this, -1, 'Distance:'),  Wx::GBPosition->new(1,3));

  my $abs = $parent->{data}->bkg_z;
  $abs = 'Fe' if ($abs eq 'He');
  my $z = get_Z( $abs );
  my $edge = ($z > 57) ? 'L3' : 'K';

  $this->{abs}      = Wx::TextCtrl -> new($this, -1, $abs,  wxDefaultPosition, [60, -1]);
  $this->{scat}     = Wx::TextCtrl -> new($this, -1, 'O',   wxDefaultPosition, [60, -1]);
  $this->{distance} = Wx::TextCtrl -> new($this, -1, '2.1', wxDefaultPosition, [60, -1]);
  $this->{edge}     = Wx::Choice   -> new($this, -1,      , wxDefaultPosition, wxDefaultSize, [qw(K L1 L2 L3)]);
  $this->{edge}    -> SetStringSelection($edge);

  $this->{abspt}  = Wx::BitmapButton->new($this, -1, Demeter::UI::Artemis::icon("orbits"), wxDefaultPosition, wxDefaultSize);
  $this->{scatpt} = Wx::BitmapButton->new($this, -1, Demeter::UI::Artemis::icon("orbits"), wxDefaultPosition, wxDefaultSize);
  EVT_BUTTON($this, $this->{abspt},  sub{$this->{which}='abs',  use_element(@_, $this)} );
  EVT_BUTTON($this, $this->{scatpt}, sub{$this->{which}='scat', use_element(@_, $this)} );

  $this->{make}   = Wx::CheckBox->new($this, -1, "Auto-generate guess parameters");
  $this->{make}->SetValue(Demeter->co->default("fspath", "make_gds"));

  $gbs -> Add( $this->{abs},      Wx::GBPosition->new(0,1));
  $gbs -> Add( $this->{abspt},    Wx::GBPosition->new(0,2));
  $gbs -> Add( $this->{scat},     Wx::GBPosition->new(0,4));
  $gbs -> Add( $this->{scatpt},   Wx::GBPosition->new(0,5));
  $gbs -> Add( $this->{edge},     Wx::GBPosition->new(1,1));
  $gbs -> Add( $this->{distance}, Wx::GBPosition->new(1,4));
  $gbs -> Add( $this->{make},     Wx::GBPosition->new(2,0), Wx::GBSpan->new(1,4));

  $this->{ok} = Wx::Button->new($this, wxID_OK, q{}, wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);

  ## --- document button
  $this->{doc} = Wx::Button->new($this, -1, q{Docmentation: QFS}, wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{doc}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{doc}, sub{$::app->document('extended.qfs')});
  $this->{cancel} = Wx::Button->new($this, wxID_CANCEL, q{}, wxDefaultPosition, wxDefaultSize);
  $vbox -> Add($this->{cancel}, 0, wxGROW|wxALL, 5);

  $this -> SetSizerAndFit( $vbox );
  return $this;
};


sub use_element {
  my ($self, $event, $parent) = @_;
  my $how = ($parent->{which} eq 'abs') ? 'an absorber' : 'a scatterer';
  $parent->{popup}  = Demeter::UI::Wx::PeriodicTableDialog->new($self, -1, "Select $how element", sub{$self->put_element($_[0])});
  $parent->{popup} -> ShowModal;
};

sub put_element {
  my ($self, $el) = @_;
  $self->{popup}->Destroy;
  my $which = $self->{which};
  $self->{$which}->SetValue($el);
};


sub ShouldPreventAppExit {
  0
};

1;



=head1 NAME

Demeter::UI::Artemis::Data::Quickfs - Dialog to set up a quick first shell fit

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module provides a dialog for setting up a quick first shell fit.

=head1 CONFIGURATION


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

Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
