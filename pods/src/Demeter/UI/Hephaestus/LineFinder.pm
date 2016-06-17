package Demeter::UI::Hephaestus::LineFinder;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
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
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Xray::Absorption;
use Demeter::UI::Hephaestus::Common qw(e2l);

use Wx qw( :everything );
use Wx::Event qw(EVT_LIST_ITEM_SELECTED EVT_BUTTON EVT_KEY_DOWN);
use Wx::Perl::TextValidator;
use base 'Wx::Panel';

## snarf (quietly!) the list of energies from the list used for the
## next_energy function in Xray::Absoprtion::Elam
my $hash;
# do {
#   no warnings;
#   $hash = $$Xray::Absorption::Elam::r_elam{line_list};
# };
# my @line_list = ();
# foreach my $key (keys %$hash) {
#   next unless exists $$hash{$key}->[2];
#   next unless ($$hash{$key}->[2] > 100);
#   push @line_list, $$hash{$key};
# };
# ## and sort by increasing energy
# @line_list = sort {$a->[2] <=> $b->[2]} @line_list;

my @line_list = @{$$Xray::Absorption::Elam::r_elam{sorted}};

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->SetSizer($hbox);

  $self->{targetenergy} = Demeter->co->default(qw(hephaestus line_energy));
  $self->{echo} = $echoarea;

  ## -------- Edge energies
  $self->{linesbox} = Wx::StaticBox->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize);
  $self->{linesboxsizer} = Wx::StaticBoxSizer->new( $self->{linesbox}, wxVERTICAL );
  $self->{lines} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES|wxLC_SINGLE_SEL);
  $self->{lines}->InsertColumn( 0, "Element" );
  $self->{lines}->SetColumnWidth( 4, 60 );
  $self->{lines}->InsertColumn( 1, "Line" );
  $self->{lines}->InsertColumn( 2, "Transition" );
  $self->{lines}->InsertColumn( 3, "Energy (eV)" );
  $self->{lines}->InsertColumn( 4, "Wavelength (A)" );
  $self->{lines}->SetColumnWidth( 4, 100 );
  $self->{lines}->InsertColumn( 5, "Strength" );
  my ($i, $start) = (0, 0);
  foreach my $row (@line_list) {
    my $idx = $self->{lines}->InsertImageStringItem($i, ucfirst($row->[0]), 0);
    $self->{lines}->SetItemData($idx, $i++);
    $self->{lines}->SetItem( $idx, 1, Xray::Absorption->get_Siegbahn_full($row->[1]));
    $self->{lines}->SetItem( $idx, 2, Xray::Absorption->get_IUPAC($row->[1]));
    $self->{lines}->SetItem( $idx, 3, $row->[2]);
    $self->{lines}->SetItem( $idx, 4, sprintf("%.5f", e2l($row->[2])));
    $self->{lines}->SetItem( $idx, 5, sprintf("%.4f", Xray::Absorption->get_intensity($row->[0], $row->[1])));
    ($start = $i) if ($row->[2] < $self->{targetenergy});
  };
  $self->{lines}->SetItemState($start, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  $self->{lines}->EnsureVisible($start);
  $self->{linesboxsizer} -> Add($self->{lines}, 1, wxGROW|wxALL, 0);
  $hbox -> Add($self->{linesboxsizer}, 7, wxGROW|wxALL, 5);

  $self->{targetbox} = Wx::StaticBox->new($self, -1, 'Target energy', wxDefaultPosition, wxDefaultSize);
  $self->{targetboxsizer} = Wx::StaticBoxSizer->new( $self->{targetbox}, wxVERTICAL );
  $self->{target} = Wx::TextCtrl->new($self, -1, $self->{targetenergy}, wxDefaultPosition, wxDefaultSize, wxWANTS_CHARS);
  $self->{targetboxsizer} -> Add($self->{target}, 0, wxEXPAND|wxALL, 0);
  EVT_KEY_DOWN( $self->{target}, sub{on_key_down(@_, $self)} );

  my $numval = Wx::Perl::TextValidator -> new('\d', \($self->{data}));
  $self->{target}->SetValidator($numval);

  $self->{search} = Wx::Button->new( $self, -1, 'Search', wxDefaultPosition, wxDefaultSize );
  $self->{targetboxsizer} -> Add($self->{search}, 0, wxEXPAND|wxALL, 5);
  EVT_BUTTON( $self, $self->{search}, \&search_lines );


  $hbox -> Add($self->{targetboxsizer}, 2, wxALIGN_CENTER_VERTICAL|wxALL, 5);

  ## finish up
  $self -> SetSizerAndFit( $hbox );

  return $self;
};

sub adjust_column_width {
  my ($self) = @_;
  my $tablewidth = ($self->{lines}->GetSizeWH)[0];
  my $width0123 = $self->{lines}->GetColumnWidth(0)
    + $self->{lines}->GetColumnWidth(1)
      + $self->{lines}->GetColumnWidth(2)
	+ $self->{lines}->GetColumnWidth(3);
  $self->{lines}->SetColumnWidth(4,0.88*($tablewidth-$width0123));
};

sub on_key_down {
  my ($self, $event, $parent) = @_;
  if ($event->GetKeyCode == 13) {
    search_lines($parent, $event);
  } else {
    $event->Skip;
  };
};


sub search_lines {
  my ($self, $event) = @_;
  foreach ( 0 .. $self->{lines}->GetItemCount - 1 ) {
    $self->{lines}->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
  };
  $self->{targetenergy} = $self->{target}->GetValue;
  my $i = 0;
  foreach my $row (@line_list) {
    last if ($self->{targetenergy} < $row->[2]);
    ++$i;
  };
  $self->{lines}->SetItemState($i, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  $self->{lines}->EnsureVisible($i);
};

1;

=head1 NAME

Demeter::UI::Hephaestus:::LineFinder - Hephaestus' line finder utility

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

The contents of Hephaestus' line finder utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::LineFinder->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility presents an ordered list of fluorescence line energies
and allows the user to search for specific energy values.  This is
useful for identifying lines observed in fluorescence spectra or for
planning an experiment on the basis of the known contents of a sample.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Size of the ListView widget is not chosen optimally.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
