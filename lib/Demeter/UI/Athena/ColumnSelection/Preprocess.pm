package Demeter::UI::Athena::ColumnSelection::Preprocess;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON);
use Wx::Perl::TextValidator;

use strict;
use warnings;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::UI::Athena::Replot;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add(Wx::StaticText->new($this, -1, "Standard"), 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{standard} = Demeter::UI::Athena::GroupList -> new($this, $app, 1, 0);
  $hbox -> Add($this->{standard}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{standard}->{callback} = \&OnSelect;

  $box -> Add($hbox, 0, wxALL, 5);

  $this->{mark}  = Wx::CheckBox->new($this, -1, 'Mark group as it is imported');
  $this->{align} = Wx::CheckBox->new($this, -1, 'Align to the standard');
  $this->{set}   = Wx::CheckBox->new($this, -1, 'Set parameters to the standard');
  $box -> Add($this->{mark},  0, wxALL, 5);
  $box -> Add($this->{align}, 0, wxALL, 5);
  $box -> Add($this->{set},   0, wxALL, 5);

  $this->SetSizerAndFit($box);
  return $this;

};

sub OnSelect {
  my ($this, $event) = @_;
  if ($this->{standard}->GetStringSelection =~ m{\A(?:None|)\z}) {
    $this->{align} -> SetValue(0);
    $this->{align} -> Enable(0);
    $this->{set}   -> SetValue(0);
    $this->{set}   -> Enable(0);
  } else {
    $this->{align} -> Enable(1);
    $this->{set}   -> Enable(1);
  };
};

1;

=head1 NAME

Demeter::UI::Athena::ColumnSelection::Preprocess - column selection preprocessing controls

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This module provides controls for handling preprocessing in Athena's
column selection dialog

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

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
