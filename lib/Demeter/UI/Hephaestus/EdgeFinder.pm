package Demeter::UI::Hephaestus::EdgeFinder;

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
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Xray::Absorption;
use Demeter::UI::Wx::SpecialCharacters qw($GAMMA $ARING);
use Demeter::UI::Hephaestus::Common qw(e2l);

use Wx qw( :everything );
use Wx::Event qw(EVT_LIST_ITEM_SELECTED EVT_BUTTON EVT_KEY_DOWN EVT_RADIOBOX);
use Wx::Perl::TextValidator;
use base 'Wx::Panel';

## snarf (quietly!) the list of energies from the list used for the
## next_energy function in Xray::Absoprtion::Elam
my $hash;
do {
  no warnings;
  $hash = $$Xray::Absorption::Elam::r_elam{energy_list};
};
my @edge_list;
foreach my $key (keys %$hash) {
  next unless exists $$hash{$key}->[2];
  next if ($$hash{$key}->[2] < 100);
  push @edge_list, $$hash{$key};
};
@edge_list = sort {$a->[2] <=> $b->[2]} @edge_list;

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->SetSizer($hbox);

  $self->{targetenergy} = Demeter->co->default(qw(hephaestus find_energy));
  $self->{echo} = $echoarea;

  ## -------- Edge energies
  $self->{edgesbox} = Wx::StaticBox->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize);
  $self->{edgesboxsizer} = Wx::StaticBoxSizer->new( $self->{edgesbox}, wxVERTICAL );
  $self->{edges} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES|wxLC_SINGLE_SEL);
  $self->{edges}->InsertColumn( 0, "Element" );
  $self->{edges}->InsertColumn( 1, "Edge" );
  $self->{edges}->InsertColumn( 2, "Energy (eV)" );
  $self->{edges}->InsertColumn( 3, "Wavelength (A)" );
  $self->{edges}->SetColumnWidth( 3, 120 );
  $self->{edges}->InsertColumn( 4, "$GAMMA(ch) (eV)" );
  my ($i, $start) = (0, 0);
  foreach my $row (@edge_list) {
    my $idx = $self->{edges}->InsertImageStringItem($i, ucfirst($row->[0]), 0);
    $self->{edges}->SetItemData($idx, $i++);
    $self->{edges}->SetItem( $idx, 1, ucfirst($row->[1]));
    $self->{edges}->SetItem( $idx, 2, $row->[2]);
    $self->{edges}->SetItem( $idx, 3, sprintf("%.5f", e2l($row->[2])));
    $self->{edges}->SetItem( $idx, 4, sprintf("%.2f", Xray::Absorption->get_gamma($row->[0], $row->[1])));
    ($start = $i) if ($row->[2] <= $self->{targetenergy});
  };
  $self->{edges}->SetItemState($start, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  $self->{edges}->EnsureVisible($start);
  $self->{edgesboxsizer} -> Add($self->{edges}, 1, wxGROW|wxALL, 0);
  $hbox -> Add($self->{edgesboxsizer}, 5, wxGROW|wxALL, 5);

  $self->{targetbox} = Wx::StaticBox->new($self, -1, 'Target energy', wxDefaultPosition, wxDefaultSize);
  $self->{targetboxsizer} = Wx::StaticBoxSizer->new( $self->{targetbox}, wxVERTICAL );
  $self->{target} = Wx::TextCtrl->new($self, -1, $self->{targetenergy}, wxDefaultPosition, wxDefaultSize, wxWANTS_CHARS);
  $self->{targetboxsizer} -> Add($self->{target}, 0, wxEXPAND|wxALL, 0);
  EVT_KEY_DOWN( $self->{target}, sub{on_key_down(@_, $self)} );

  my $numval = Wx::Perl::TextValidator -> new('\d', \($self->{data}));
  $self->{target}->SetValidator($numval);

  $self->{search} = Wx::Button->new( $self, -1, 'Search', wxDefaultPosition, wxDefaultSize );
  $self->{targetboxsizer} -> Add($self->{search}, 0, wxEXPAND|wxALL, 5);
  EVT_BUTTON( $self, $self->{search}, \&search_edges );

  #my $panel = Wx::Panel->new($self, -1);
  #my $panelsizer = Wx::BoxSizer->new( wxVERTICAL );
  #$self->{targetboxsizer} -> Add($panelsizer, 0, wxEXPAND|wxALL, 5);
  $self->{harmonic} = 'Fundamental';
  $self->{harmonics} = Wx::RadioBox->new( $self, -1, 'Harmonic', wxDefaultPosition, wxDefaultSize,
					  ['Fundamental', 'Second', 'Third'], 1, wxRA_SPECIFY_COLS);
  EVT_RADIOBOX( $self, $self->{harmonics}, \&search_edges );
  $self->{targetboxsizer} -> Add($self->{harmonics}, 0, wxEXPAND|wxALL, 10);
  $self->{harmonicenergy} = Wx::StaticText->new($self, -1, q{});
  $self->{targetboxsizer} -> Add($self->{harmonicenergy}, 0, wxEXPAND|wxALL, 10);
  #$panel -> SetSizerAndFit( $panelsizer );
  $self->{harmonics}->SetSelection(Demeter->co->default(qw(hephaestus find_harmonic)) - 1);
  if (Demeter->co->default(qw(hephaestus find_harmonic)) > 1) {
    $self->search_edges;
  };


  $hbox -> Add($self->{targetboxsizer}, 2, wxALIGN_CENTER_VERTICAL|wxALL, 5);

  ## finish up
  $self -> SetSizerAndFit( $hbox );
  #EVT_LIST_ITEM_SELECTED($self->{edges}, $self->{edges}, sub{select_edge(@_, $self)});

  return $self;
};

sub adjust_column_width {
  my ($self) = @_;
  my $tablewidth = ($self->{edges}->GetSizeWH)[0];
  my $width01 = $self->{edges}->GetColumnWidth(0) + $self->{edges}->GetColumnWidth(1);
  $self->{edges}->SetColumnWidth(2,0.92*($tablewidth-$width01));
};

sub on_key_down {
  my ($self, $event, $parent) = @_;
  if ($event->GetKeyCode == 13) {
    search_edges($parent, $event);
  } else {
    $event->Skip;
  };
};

sub select_edge {
  my ($self, $event, $parent) = @_;
  my $index = $event->GetIndex;
  $parent->{targetenergy}  = $parent->{edges}->GetItem($index,2)->GetText;
  $parent->{targetenergy} -= 1;
  my $hh = ($parent->{harmonic} eq 'Fundamental') ? 1
         : ($parent->{harmonic} eq 'Second')      ? 2
	 :                                          3;
  $parent->{target}->SetValue(sprintf("%.1f", $parent->{targetenergy}/$hh));
};

sub search_edges {
  my ($self, $event) = @_;
  foreach ( 0 .. $self->{edges}->GetItemCount - 1 ) {
    $self->{edges}->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
  };
  $self->{harmonic} = $self->{harmonics}->GetStringSelection;
  my $hh = ($self->{harmonic} eq 'Fundamental') ? 1
         : ($self->{harmonic} eq 'Second')      ? 2
	 :                                        3;
  $self->{targetenergy} = $self->{target}->GetValue * $hh;
  my $labtext = ($hh > 1) ? sprintf("Harmonic at %.1f eV", $self->{targetenergy}) : q{};
  $self->{harmonicenergy} -> SetLabel( $labtext );
  my $i = 0;
  foreach my $row (@edge_list) {
    last if ($self->{targetenergy} < $row->[2]);
    ++$i;
  };
  $self->{edges}->SetItemState($i, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  $self->{edges}->EnsureVisible($i);
};


1;


=head1 NAME

Demeter::UI::Hephaestus::EdgeFinder - Hephaestus' edge finder utility

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

The contents of Hephaestus' edge finder utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::EdgeFinder->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility presents an ordered list of absorption edge energies and
allows the user to search for specific energy values as well as for
second and third harmonics of the energy.  This is useful for
identifying edges observed in measured data or for planning an
experiment on the basis of the known contents of a sample.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Size of the ListView widget is not chosen optimally.

=item *

Double clicking on the ListView could select that energy, allowing the
user to examine harmonics or the fundamental of that energy.

=back

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
