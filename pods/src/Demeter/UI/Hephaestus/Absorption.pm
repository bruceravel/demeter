package Demeter::UI::Hephaestus::Absorption;

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
use Carp;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Xray::Absorption;
Xray::Absorption->load('elam');
use Demeter::UI::Wx::PeriodicTable;
use Demeter::UI::Hephaestus::Common qw(e2l);
use Demeter::UI::Wx::SpecialCharacters qw($GAMMA $ARING);
use Demeter::Constants qw($PI $HBAR);

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_LIST_ITEM_FOCUSED EVT_BUTTON  EVT_KEY_DOWN);

my $hash;
do {
  no warnings;
  $hash = $$Xray::Absorption::Elam::r_elam{energy_list};
};
use vars qw(@k_list);
@k_list = ();
foreach my $key (keys %$hash) {
  next unless exists $$hash{$key}->[2];
  next unless (lc($$hash{$key}->[1]) eq 'k');
  push @k_list, $$hash{$key};
};
## and sort by increasing energy
@k_list = sort {$a->[2] <=> $b->[2]} @k_list;


my @LINELIST = qw(Ka1 Ka2 Ka3 Kb1 Kb2 Kb3 Kb4 Kb5
		  La1 La2 Lb1 Lb2 Lb3 Lb4 Lb5 Lb6
		  Lg1 Lg2 Lg3 Lg6 Ll Ln Ma Mb Mg Mz);
my @EDGELIST = qw(K L1 L2 L3 M1 M2 M3 M4 M5 N1 N2 N3 N4 N5 N6 N7 O1 O2 O3 O4 O5 P1 P2 P3);


sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{echo} = $echoarea;

  my $pt = Demeter::UI::Wx::PeriodicTable->new($self, sub{$self->abs_get_data($_[0])}, $echoarea);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
#  $self->SetSizer($vbox);
  $vbox -> Add($pt, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $vbox -> Add( 20, 10, 0, wxGROW );

  ## horizontal box for containing the tables of element data
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  ## -------- Element data
  $self->{databox} = Wx::StaticBox->new($self, -1, 'Element data', wxDefaultPosition, wxDefaultSize);
  $self->{databoxsizer} = Wx::StaticBoxSizer->new( $self->{databox}, wxVERTICAL );
  $self->{data} = Wx::ListCtrl->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES||wxLC_SINGLE_SEL);
  $self->{data}->InsertColumn( 0, "Property", wxLIST_FORMAT_LEFT, 65 );
  $self->{data}->InsertColumn( 1, "Value", wxLIST_FORMAT_LEFT, 98  );
  my $i = 0;
  foreach my $row (qw(Name Number Weight Density)) {
    my $idx = $self->{data}->InsertImageStringItem($i, $row, 0);
    $self->{data}->SetItemData($idx, $i++);
    $self->{data}->SetItem( $idx, 1, q{} );
    ##$self->{data}->SetItemFont( $idx, 0, Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };
  $self->{databoxsizer} -> Add($self->{data}, 1, wxGROW|wxALL, 0);
  EVT_LIST_ITEM_SELECTED($self->{data}, $self->{data}, sub{unselect_data(@_, $self)});


  my $filterbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{databoxsizer} -> Add($filterbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 0);
  my $label = Wx::StaticText->new($self, -1, 'Filter');
  $filterbox -> Add($label, 0, wxALL, 5);
  $self->{filterelement} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [35,-1], wxWANTS_CHARS);
  $filterbox -> Add($self->{filterelement}, 0, wxEXPAND|wxALL, 5);
  EVT_KEY_DOWN( $self->{filterelement}, sub{on_key_down(@_, $self)} );


  $self->{filter} = Wx::Button->new( $self, -1, 'Plot filter', wxDefaultPosition, wxDefaultSize );
  $self->{databoxsizer} -> Add($self->{filter}, 0, wxEXPAND|wxBOTTOM, 50);
  EVT_BUTTON( $self, $self->{filter}, \&filter_plot );
  $self->{filter}->Enable(0);

  $hbox -> Add($self->{databoxsizer}, 11, wxGROW|wxALL, 5);

  ## -------- Edge energies
  $self->{edgebox} = Wx::StaticBox->new($self, -1, 'Absorption edges', wxDefaultPosition, wxDefaultSize);
  $self->{edgeboxsizer} = Wx::StaticBoxSizer->new( $self->{edgebox}, wxVERTICAL );
  $self->{edge} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES|wxLC_SINGLE_SEL);
  $self->{edge}->InsertColumn( 0, "Edge", wxLIST_FORMAT_LEFT, 55 );
  $self->{edge}->InsertColumn( 1, "Energy", wxLIST_FORMAT_RIGHT, 70  );
  $self->{edge}->InsertColumn( 2, "$GAMMA(ch)", wxLIST_FORMAT_RIGHT, 55  );
  $i = 0;
  foreach my $row (@EDGELIST) {
    my $idx = $self->{edge}->InsertImageStringItem($i, $row, 0);
    $self->{edge}->SetItemData($idx, $i++);
    $self->{edge}->SetItem( $idx, 1, q{} );
  };
  EVT_LIST_ITEM_SELECTED($self->{edge}, $self->{edge}, sub{select_edge(@_, $self)});
  EVT_LIST_ITEM_ACTIVATED($self->{edge}, $self->{edge}, sub{highlight_lines(@_, $self)});
  $self->{edgeboxsizer} -> Add($self->{edge}, 1, wxGROW|wxALL, 0);
  $hbox -> Add($self->{edgeboxsizer}, 13, wxGROW|wxALL, 5);

  ## -------- Line energies
  $self->{linebox} = Wx::StaticBox->new($self, -1, 'Fluorescence lines', wxDefaultPosition, wxDefaultSize);
  $self->{lineboxsizer} = Wx::StaticBoxSizer->new( $self->{linebox}, wxVERTICAL );
  $self->{line} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES);
  $self->{line}->InsertColumn( 0, "Line", wxLIST_FORMAT_LEFT, 50 );
  $self->{line}->InsertColumn( 1, "Transition" );
  $self->{line}->InsertColumn( 2, "Energy", wxLIST_FORMAT_RIGHT, 70 );
  $self->{line}->InsertColumn( 3, "Strength", wxLIST_FORMAT_RIGHT );
  $i = 0;
  foreach my $row (@LINELIST) {
    my $idx = $self->{line}->InsertImageStringItem($i, $row, 0);
    $self->{line}->SetItemData($idx, $i++);
    $self->{line}->SetItem($idx, 1, Xray::Absorption->get_IUPAC($row));
  };
  EVT_LIST_ITEM_SELECTED($self->{line}, $self->{line}, sub{select_line(@_, $self)});
  EVT_LIST_ITEM_ACTIVATED($self->{line}, $self->{line}, sub{highlight_edge(@_, $self)});
  $self->{lineboxsizer} -> Add($self->{line}, 2, wxGROW|wxALL, 0);
  $hbox -> Add($self->{lineboxsizer}, 18, wxGROW|wxALL, 5);


#  $vbox -> Add( 100, 10, 0, wxGROW );

  ## finish up
  $vbox -> Add($hbox, 1, wxGROW|wxALL);
  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub abs_get_data {
  my ($self, $el) = @_;
  $self->deselect_all($_) foreach qw(data edge line);
  my $z = get_Z($el);
  $self->{data}->SetItem( 0, 1, get_name($el));
  $self->{data}->SetItem( 1, 1, $z);
  my $ww = Xray::Absorption->get_atomic_weight($el);
  my $www = ($ww) ? $ww . ' amu' : q{};
  $self->{data}->SetItem( 2, 1, $www);
  my $dd = Xray::Absorption->get_density($el);
  my $ddd = ($dd) ? $dd . ' g/cm^3' : q{};
  $self->{data}->SetItem( 3, 1, $ddd);
  my $filter = ($z <  24) ? q{}
             : ($z == 37) ? 35     ## Kr is a stupid filter material
             : ($z <  39) ? $z - 1 ## Z-1 for V - Y
             : ($z == 45) ? 44     ## Tc is a stupid filter material
             : ($z == 56) ? 53     ## Xe is a stupid filter material
             : ($z <  57) ? $z - 2 ## Z-2 for Zr - Ba
	     : l_filter($el);	   ## K filter for heavy elements
  $filter = get_symbol($filter) if $filter;
  $self->{filterelement}->SetValue($filter);

  $self->{element} = $el;
  $self->{filtermaterial} = $filter;
  $self->{filter}->Enable(0);
  $self->{filter}->Enable(1) if $filter;

  my $i = 0;
  my $do_wavelengh = 0;
  #$self->{edge}->SetText(
  foreach my $edge (@EDGELIST) {
    my $energy = Xray::Absorption->get_energy($el, $edge);
    my $out = $energy;
    my $gammaval = ($energy) ? Xray::Absorption->get_gamma($el, $edge) : 0;
    my $gamma = (not $gammaval)   ? q{}
              : ($gammaval > 100) ? sprintf("%.2f", $gammaval)
	      :                     sprintf("%.2f", $gammaval);
    if (not $energy) {
      $out = q{};
    } elsif ($do_wavelengh) {
      $out = sprintf("%.5f", e2l($energy));
    };
    $self->{edge}->SetItem($i, 1, $out);
    $self->{edge}->SetItem($i, 2, $gamma);
    ++$i;
  };

  $i = 0;
  foreach my $line (@LINELIST) {
    my $energy = Xray::Absorption->get_energy($el, $line);
    my $out = $energy;
    if (not $energy) {
      $out = q{};
    } elsif ($do_wavelengh) {
      $out = sprintf("%.5f", e2l($energy));
    };
    $self->{line}->SetItem($i,   2, $out);
    my $strength = Xray::Absorption->get_intensity($el, $line);
    $strength = ($strength) ? sprintf("%.4f", $strength) : q{};
    $self->{line}->SetItem($i++, 3, $strength);
  };

  $self->{echo}->SetStatusText(q{});
};

sub l_filter {
  my $elem = $_[0];
  return q{} if (get_Z($elem) > 98);
  my $en = Xray::Absorption -> get_energy($elem, 'la1') + Demeter->co->default(qw(hephaestus filter_offset)) * Demeter->co->default(qw(hephaestus filter_width));
  my $filter = q{};
  foreach (@k_list) {
    $filter = $_->[0];
    last if ($_->[2] >= $en);
  };
  my $result = get_Z($filter);
  ++$result if ($result == 36);
  return $result;
}

sub deselect_all {
  my ($self, $which) = @_;
  my $listctrl = $self->{$which};
  foreach ( 0 .. $listctrl->GetItemCount - 1 ) {
    $listctrl->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
  };
};

sub highlight_lines {
  my ($self, $event, $parent) = @_;
  #local $| = 1;
  #print join("|", @_),$/;
  my $index = $event->GetIndex;
  my $edge = $EDGELIST[$index];
  $parent->deselect_all('line');
  my $ll = -1;
  EVT_LIST_ITEM_SELECTED($parent->{line}, $parent->{line}, sub{1;});
  foreach my $line (@LINELIST) {
    my $transition = Xray::Absorption->get_IUPAC($line);
    ++$ll;
    next if ($transition !~ m{\A$edge});
    $parent->{line}->SetItemState($ll, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  };
  EVT_LIST_ITEM_SELECTED($parent->{line}, $parent->{line}, sub{select_line(@_, $parent)});
  $parent->{echo}->SetStatusText("Selected all lines associated with the $edge edge.");
};
sub highlight_edge {
  my ($self, $event, $parent) = @_;
  my $index = $event->GetIndex;
  my $line = $LINELIST[$index];
  my $transition = Xray::Absorption->get_IUPAC($line);
  $parent->deselect_all('edge');
  my $ee = -1;
  foreach my $edge (@EDGELIST) {
    ++$ee;
    next if ($transition !~ m{\A$edge});
    $parent->{edge}->SetItemState($ee, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
    my $ll = -1;
    foreach my $line (@LINELIST) {
      my $transition = Xray::Absorption->get_IUPAC($line);
      ++$ll;
      next if ($transition !~ m{\A$edge});
      $parent->{line}->SetItemState($ll, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
      $parent->{echo}->SetStatusText("Selected all lines associated with the $edge edge.");
    };
  };
};
sub unselect_data {
  my ($self, $event, $parent) = @_;
  $parent->deselect_all('data');
};
sub select_edge {
  my ($self, $event, $parent) = @_;
  $parent->deselect_all('line');
  my $index = $event->GetIndex;
  my $edge = $EDGELIST[$index];
  my $el = $parent->{element};
  my $en = Xray::Absorption->get_energy($el, $edge);
  $parent->{echo}->SetStatusText(q{}), return if not $en;
  my $wl = e2l($en);
  my $ga = Xray::Absorption->get_gamma($el, $edge);
  my $ti = 1.5192E15*$HBAR / $ga; # see Keski-Rahkonen and Klause, http://dx.doi.org/10.1016/S0092-640X(74)80020-3
  my $message = sprintf("%s %s edge: %.1f eV = %.5f Angstrom ..... core-hole lifetime: %.2f eV ~ %.2f fs",
			$el, $edge, $en, $wl, $ga, $ti);
  $parent->{echo}->SetStatusText($message);
};
sub select_line {
  my ($self, $event, $parent) = @_;
  my $index = $event->GetIndex;
  my $line = $LINELIST[$index];
  my $el = $parent->{element};
  my $en = Xray::Absorption->get_energy($el, $line);
  $parent->{echo}->SetStatusText(q{}), return if not $en;
  my $wl = e2l($en);
  my $message = sprintf("%s %s line: %.1f eV = %.5f Angstrom", $el, $line, $en, $wl);
  $parent->{echo}->SetStatusText($message);
};

sub on_key_down {
  my ($self, $event, $parent) = @_;
  if ($event->GetKeyCode == 13) {
    filter_plot($parent, $event);
  } else {
    $event->Skip;
  };
};

sub filter_plot {
  my ($self, $event) = @_;
  my $busy    = Wx::BusyCursor->new();
  my ($elem, $filter) = ($self->{element}, $self->{filterelement}->GetValue);
  my $z      = get_Z($elem);
  $self->{echo}->SetStatusText('You have not selected an absorbing element for the filter plot.'), return if not $z;
  $self->{echo}->SetStatusText('Your filter material, \"$filter\", is not a valid element.'), return if not get_Z($filter);

  my $edge   = ($z < 57) ? "K"   : "L3";
  my $line2  = ($z < 57) ? "Ka2" : "La1";

  Demeter -> po -> start_plot;
  Demeter -> co -> set(
		       filter_abs      => $z,
		       filter_edge     => $edge,
		       filter_filter   => $filter,
		       filter_emin     => Xray::Absorption -> get_energy($z, $line2) - 400,
		       filter_emax     => Xray::Absorption -> get_energy($z, $edge)  + 300,
		       filter_file     => Demeter->po->tempfile,
		       filter_width    => Demeter->co->default(qw(hephaestus filter_width)),
		      );
  my $command = Demeter->template('plot', 'prep_filter');
  Demeter -> dispose($command);

  $command = Demeter->template('plot', 'filter');
  Demeter -> po -> legend(x => 0.15, y => 0.85, );
  Demeter -> dispose($command, "plotting");

  undef $busy;
  $self->{echo}->SetStatusText(sprintf('Plotting %s as a filter for %s.', lc(get_name($filter)), lc(get_name($elem))));
  return 1;
};


1;

=head1 NAME

Demeter::UI::Hephaestus::Absorption - Hephaestus' absorption utility

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

The contents of Hephaestus' absorption utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::Absorption->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility uses a periodic table as the interface to tables of edge
and line energies.  Clicking on an element in the periodic table will
display that element's edge and line energies along with a few other
bits of information about that element.  There is also a button for
making a plot which shows how a fluorescence filter for that element
works.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Sizes of ListView widgets are not chosen optimally.

=back

Please report problems to the Ifeffit Mailing List
(http://cars9.uchicago.edu/mailman/listinfo/ifeffit/)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
