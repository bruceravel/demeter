package Demeter::UI::Hephaestus::Data;

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
use Carp;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use JSON qw(decode_json);

use Demeter::IniReader;
use Demeter::UI::Hephaestus::Common qw(enable_element);

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_NOTEBOOK_PAGE_CHANGED EVT_TOGGLEBUTTON EVT_SPIN);
use Demeter::UI::Wx::SpecialCharacters qw($ARING $OUMLAUT);
use Demeter::UI::Wx::PeriodicTable;

my $datadir = File::Spec->catfile($Demeter::UI::Hephaestus::hephaestus_base, 'Hephaestus', 'data');

## --- tab 0: general data
my %kalzium = %{Demeter::IniReader->read_file(File::Spec->catfile($datadir, "kalziumrc.dem"))};

## --- tab 1: Shannon ionic radii
my $ionic_radii = decode_json(Demeter->slurp(File::Spec->catfile($datadir, "ionic_radii.dem")));
my %ionic_radius_exists;
foreach my $item (@$ionic_radii) {
  $ionic_radius_exists{$item->{element}} = 1;
};

## --- tab 2: thermal neutron lengths and cross sections
my $neutron_xs = decode_json(Demeter->slurp(File::Spec->catfile($datadir, "neutrons.dem")));

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{echo} = $echoarea;

  $self->{pt} = Demeter::UI::Wx::PeriodicTable->new($self, sub{$self->multiplexer($_[0])}, $echoarea);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $self->SetSizer($vbox);
  $vbox -> Add($self->{pt}, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $vbox -> Add( 20, 10, 0, wxGROW );

  ## horizontal box for containing the tables of element data
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );



  $vbox -> Add($hbox, 1, wxEXPAND|wxALL);
  $self->{tabs}  = Wx::Notebook->new($self, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  $hbox -> Add($self->{tabs}, 1, wxEXPAND|wxLEFT|wxRIGHT, 5);
  $self -> SetSizerAndFit( $vbox );
  EVT_NOTEBOOK_PAGE_CHANGED($self, $self->{tabs}, sub{$self->select_tool(@_)});

  ## -------- Element data
  my $panel = Wx::Panel->new($self->{tabs}, -1);
  my $box = Wx::BoxSizer->new( wxVERTICAL );

  $self->{data} = Wx::ListCtrl->new($panel, -1, wxDefaultPosition, wxDefaultSize,
				    wxLC_REPORT|wxLC_HRULES|wxLC_SINGLE_SEL);
  $self->{data}->InsertColumn( 0, "Physical Properties", wxLIST_FORMAT_LEFT, 140 );
  $self->{data}->InsertColumn( 1, "Value", wxLIST_FORMAT_LEFT, 170);
  $self->{data}->InsertColumn( 2, "Chemical Properties", wxLIST_FORMAT_LEFT, 150 );
  $self->{data}->InsertColumn( 3, "Value", wxLIST_FORMAT_LEFT, 170 );
  my $i = 0;
  foreach my $row ('Name', 'Number', 'Symbol', 'Atomic Weight',
		   'Atomic Radius', "M${OUMLAUT}ssbauer", q{Discovery}) {
    my $idx = $self->{data}->InsertImageStringItem($i, $row, 0);
    $self->{data}->SetItemData($idx, $i++);
    $self->{data}->SetItem( $idx, 1, q{} );
    ##$self->{data}->SetItemFont( $idx, Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };
  $i = 0;
  foreach my $row ('Orbital Configuration', 'Oxidation State', 'Melting Point', 'Boiling Point',
		   'Electronegativity', 'Ionization Energy', '2nd Ion. Energy') {
    $self->{data}->SetItem( $i, 2, $row );
    $self->{data}->SetItem( $i++, 3, q{} );
    ##$self->{data}->SetItemFont( $idx, Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };
  EVT_LIST_ITEM_SELECTED($self->{data}, $self->{data}, sub{unselect_data(@_, $self)});
  $box -> Add($self->{data}, 1, wxEXPAND|wxALL, 5);

  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hh, 0, wxEXPAND|wxALL, 0);

  $self->{mossbauer} = Wx::ToggleButton->new($panel, -1, "Show M${OUMLAUT}ssbauer-active elements");
  $hh -> Add($self->{mossbauer}, 0, wxLEFT, 5);
  EVT_TOGGLEBUTTON($self, $self->{mossbauer}, sub{show_mossbauer(@_)});

  $self->{by} = Wx::ToggleButton->new($panel, -1, "Show elements known by");
  $hh -> Add($self->{by}, 0, wxLEFT, 25);
  EVT_TOGGLEBUTTON($self, $self->{by}, sub{show_date(@_)});

  $self->{datelabel} = Wx::StaticText->new($panel, -1, '1660');
  $hh -> Add($self->{datelabel}, 0, wxTOP|wxLEFT|wxRIGHT, 4);
  $self->{date} = Wx::SpinButton->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxSP_WRAP);
  $self->{date}->SetRange(0,36);
  $self->{date}->SetValue(0);
  $hh -> Add($self->{date}, 0, wxALL, 0);
  EVT_SPIN($self, $self->{date}, sub{increment_date(@_)});
  $self->{datelabel}->Enable(0);
  $self->{date}->Enable(0);

  $panel->SetSizerAndFit($box);
  $self->{tabs} -> AddPage($panel, 'Elemental data', 1);

  ## -------- Ioonic Radii
  $panel = Wx::Panel->new($self->{tabs}, -1);
  $box = Wx::BoxSizer->new( wxVERTICAL );

  $self->{radii} = Wx::ListView->new($panel, -1, wxDefaultPosition, wxDefaultSize,
				     wxLC_REPORT|wxLC_HRULES|wxLC_SINGLE_SEL);
  $self->{radii}->InsertColumn( 0, "Ionization",     wxLIST_FORMAT_LEFT, 90 );
  $self->{radii}->InsertColumn( 1, "Configuration",  wxLIST_FORMAT_LEFT, 100 );
  $self->{radii}->InsertColumn( 2, "Coordination #", wxLIST_FORMAT_LEFT, 105 );
  $self->{radii}->InsertColumn( 3, "Spin state",     wxLIST_FORMAT_LEFT, 75 );
  $self->{radii}->InsertColumn( 4, "Crystal radius", wxLIST_FORMAT_LEFT, 100 );
  $self->{radii}->InsertColumn( 5, "Ionic radius",   wxLIST_FORMAT_LEFT, 100 );
  $self->{radii}->InsertColumn( 6, "Notes",          wxLIST_FORMAT_LEFT, 70 );
  $box -> Add($self->{radii}, 1, wxEXPAND|wxALL, 5);

  my $font_size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize - 1;

  my $text = Wx::StaticText->new($panel, -1, 'Notes: R=from r3 vs V plots  C=calculated  E=estimated  ?=doubtful  *=most reliable');
  $text -> SetFont(Wx::Font->new( $font_size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ));
  $box -> Add($text, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  $text = Wx::StaticText->new($panel, -1,    '       M=from metallic oxides  A=Ahrens (1952)  P=Pauling (1960)');
  $text -> SetFont(Wx::Font->new( $font_size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ));
  $box -> Add($text, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  $panel->SetSizerAndFit($box);

  $self->{tabs} -> AddPage($panel, 'Ionic Radii', 0);

  ## -------- Neutron cross sections
  $panel = Wx::Panel->new($self->{tabs}, -1);
  $box = Wx::BoxSizer->new( wxVERTICAL );

  $self->{neutrons} = Wx::ListView->new($panel, -1, wxDefaultPosition, wxDefaultSize,
					wxLC_REPORT|wxLC_HRULES|wxLC_SINGLE_SEL);
  $self->{neutrons}->InsertColumn( 0, "Isotope",   wxLIST_FORMAT_LEFT, 70 );
  $self->{neutrons}->InsertColumn( 1, "Abundance", wxLIST_FORMAT_LEFT, 100 );
  $self->{neutrons}->InsertColumn( 2, "Coh b",     wxLIST_FORMAT_LEFT, 75 );
  $self->{neutrons}->InsertColumn( 3, "Inc b",     wxLIST_FORMAT_LEFT, 100 );
  $self->{neutrons}->InsertColumn( 4, "Coh xs",    wxLIST_FORMAT_LEFT, 70 );
  $self->{neutrons}->InsertColumn( 5, "Inc xs",    wxLIST_FORMAT_LEFT, 70 );
  $self->{neutrons}->InsertColumn( 6, "Scatt xs",  wxLIST_FORMAT_LEFT, 70 );
  $self->{neutrons}->InsertColumn( 7, "Abs xs",    wxLIST_FORMAT_LEFT, 90 );
  $box -> Add($self->{neutrons}, 1, wxEXPAND|wxALL, 5);

  $panel->SetSizerAndFit($box);

  $self->{tabs} -> AddPage($panel, 'Neutron data', 0);

  return $self;
};

sub multiplexer {
  my ($self, $el) = @_;
  if ($self->{tabs}->GetSelection == 0) {
    $self->data_get_data($el);
  } elsif ($self->{tabs}->GetSelection == 1) {
    $self->ionicradii_get_data($el);
  } elsif ($self->{tabs}->GetSelection == 2) {
    $self->neutrons_get_data($el);
  };
};

sub data_get_data {
  my ($self, $el) = @_;
  my $z = get_Z($el);
  foreach ( 0 .. $self->{data}->GetItemCount - 1 ) {
    $self->{data}->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
  };
  $self->{data}->SetItem(0, 1, get_name($el));
  $self->{data}->SetItem(1, 1, $z);
  $self->{data}->SetItem(2, 1, get_symbol($el));
  $self->{data}->SetItem(3, 1, sprintf("%.3f amu",$kalzium{$z}{Weight}));
  my $radius = ($kalzium{$z}{AR}) ? sprintf("%.3f $ARING",$kalzium{$z}{AR}/100) : q{};
  $self->{data}->SetItem(4, 1, $radius);
  $self->{data}->SetItem(5, 1, $kalzium{$z}{Mossbauer} || q{});
  $self->{data}->SetItem(6, 1, $kalzium{$z}{date} || q{ancient});

  $self->{data}->SetItem(0, 3, $kalzium{$z}{Orbits} || q{});
  my $ox = ($kalzium{$z}{Ox} eq 'k.A.') ? q{} : $kalzium{$z}{Ox};
  $self->{data}->SetItem(1, 3, $ox);
  my $mp = ($kalzium{$z}{MP}) ? sprintf("%s K", $kalzium{$z}{MP}) : q{};
  $self->{data}->SetItem(2, 3, $mp);
  my $bp = ($kalzium{$z}{BP}) ? sprintf("%s K", $kalzium{$z}{BP}) : q{};
  $self->{data}->SetItem(3, 3, $bp);
  $self->{data}->SetItem(4, 3, $kalzium{$z}{EN});
  my $ie = ($kalzium{$z}{IE}) ? sprintf("%s eV", $kalzium{$z}{IE}) : q{};
  $self->{data}->SetItem(5, 3, $ie);
  my $sc = ($kalzium{$z}{IE2}) ? sprintf("%s eV", $kalzium{$z}{IE2}) : q{};
  $self->{data}->SetItem(6, 3, $sc);
};

sub ionicradii_get_data {
  my ($self, $el) = @_;
  my $z = get_Z($el);
  my $row = 0;
  $self->{radii}->DeleteAllItems;
  foreach my $this (@$ionic_radii) {
    if ($this->{element} eq $el) {
      my $idx = $self->{radii}->InsertStringItem($row, join(" ", $this->{element}, $this->{ionization}));
      $self->{radii}->SetItem( $idx, 1, $this->{coordination});
      $self->{radii}->SetItem( $idx, 2, $this->{configuration});
      $self->{radii}->SetItem( $idx, 3, ($this->{spin} eq 'HS') ? 'high' : ($this->{spin} eq 'LS') ? 'low' : '');
      $self->{radii}->SetItem( $idx, 4, sprintf("%.3f $ARING", $this->{crystalradius}));
      $self->{radii}->SetItem( $idx, 5, sprintf("%.3f $ARING", $this->{ionicradius}));
      $self->{radii}->SetItem( $idx, 6, $this->{notes});
      ++$row;
    };
  };
  return 1;
};

sub neutrons_get_data {
  my ($self, $el) = @_;
  my $hash = $neutron_xs->{$el};
  $self->{neutrons}->DeleteAllItems;
  return if not $hash;

  my $idx = $self->{neutrons}->InsertStringItem(0, join(" ", $el, 'avg'));
  $self->{neutrons}->SetItem( $idx, 1, $hash->{avg}->{concentration});
  $self->{neutrons}->SetItem( $idx, 2, $hash->{avg}->{coherent_length});
  $self->{neutrons}->SetItem( $idx, 3, $hash->{avg}->{incoherent_length});
  $self->{neutrons}->SetItem( $idx, 4, $hash->{avg}->{coherent_cross_section});
  $self->{neutrons}->SetItem( $idx, 5, $hash->{avg}->{incoherent_cross_section});
  $self->{neutrons}->SetItem( $idx, 6, $hash->{avg}->{scattering_cross_section});
  $self->{neutrons}->SetItem( $idx, 7, $hash->{avg}->{absolute_cross_section});

  my $row = 1;
  foreach my $key (sort keys %$hash) {
    next if ($key eq 'avg');
    my $idx = $self->{neutrons}->InsertStringItem($row, join(" ", $el, $key));
    $self->{neutrons}->SetItem( $idx, 1, $hash->{$key}->{concentration});
    $self->{neutrons}->SetItem( $idx, 2, $hash->{$key}->{coherent_length});
    $self->{neutrons}->SetItem( $idx, 3, $hash->{$key}->{incoherent_length});
    $self->{neutrons}->SetItem( $idx, 4, $hash->{$key}->{coherent_cross_section});
    $self->{neutrons}->SetItem( $idx, 5, $hash->{$key}->{incoherent_cross_section});
    $self->{neutrons}->SetItem( $idx, 6, $hash->{$key}->{scattering_cross_section});
    $self->{neutrons}->SetItem( $idx, 7, $hash->{$key}->{absolute_cross_section});
    ++$row;
  };
};

sub unselect_data {
  my ($self, $event, $parent) = @_;
  foreach ( 0 .. $parent->{data}->GetItemCount - 1 ) {
    $parent->{data}->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
  };
};

sub select_tool {
  my ($self, $toss, $event) = @_;
  if ($self->{tabs}->GetSelection == 0) {
    enable_element($self->{pt}, get_symbol($_), sub{1}) foreach (1 .. 118);
    $self->{mossbauer}->SetValue(0);
    $self->{by}->SetValue(0);
    $self->{datelabel}->Enable(0);
    $self->{date}->Enable(0);
    return;
  };
  foreach my $i (1 .. 118) {
    my $el = get_symbol($i);
    my $onoff = 1;
    my $function = sub{return 0};
    if ($self->{tabs}->GetSelection == 1) {
      $function = sub{ exists( $ionic_radius_exists{$_[0]} ) };
    } elsif ($self->{tabs}->GetSelection == 2) {
      $function = sub{ exists( $neutron_xs->{$_[0]} ) };
    };
    enable_element($self->{pt}, $el, $function);
  };

};

sub show_mossbauer {
  my ($self, $event) = @_;
  if (not $self->{mossbauer}->GetValue) {
    enable_element($self->{pt}, get_symbol($_), sub{1}) foreach (1 .. 118);
    return;
  };
  $self->{by}->SetValue(0);
  $self->{datelabel}->Enable(0);
  $self->{date}->Enable(0);
  foreach my $z (1 .. 118) {
    enable_element($self->{pt}, get_symbol($z), sub{ $kalzium{$z}{Mossbauer} !~ m{\A(?:|silent)\z}i }); # not '' or Silent
  };
};

sub show_date {
  my ($self, $event) = @_;
  if (not $self->{by}->GetValue) {
    enable_element($self->{pt}, get_symbol($_), sub{1}) foreach (1 .. 118);
    $self->{datelabel}->Enable(0);
    $self->{date}->Enable(0);
    return;
  };
  $self->{mossbauer}->SetValue(0);
  $self->{datelabel}->Enable(1);
  $self->{date}->Enable(1);
  increment_date($self, $event);
};
my %events = (
	      1660 => "10th century CE: Muhammad ibn Zakariyya al-Razi first refutes Aristotle's theory of 4 elements",
	      1670 => "1669: Hennig Brand discovers phosphorus, the first chemically discovered element",
	      1680 => "",
	      1690 => "",
	      1700 => "",
	      1710 => "",
	      1720 => "",
	      1730 => "",
	      1740 => "",
	      1750 => "",
	      1760 => "",
	      1770 => "",
	      1780 => "1777: Carl Wilhelm Scheele publishes his discovery of oxygen",
	      1790 => "1789: Antoine Lavoisier defines the modern term 'element' and produces the first list of elements",
	      1800 => "1800: Alessandro Volta makes first battery with Cu and Ag disks stacked in brine electrolyte",
	      1810 => "",
	      1820 => "1817: Johann Wolfgang Dobereiner makes an early classification of elements into chemically similar triads",
	      1830 => "1830: August Comte predicts that analytic chemistry is 'an aberration which is happily almost impossible'",
	      1840 => "",
	      1850 => "",
	      1860 => "",
	      1870 => "1869: Dmitri Mendeleev presents the Periodic Table",
	      1880 => "",
	      1890 => "",
	      1900 => "1896: Marie Curie discovers that uranium emits X-rays",
	      1910 => "1902; Earnest Ruthorford, Hans Geiger, and James Marsden discover the atomic nucleus",
	      1920 => "1914: Henry Moseley finds a relationship between X-ray wavelength and atomic number",
	      1930 => "1922: Dirk Coster and Georg von Hevesy discover hafnium, the last discovered stable element",
	      1940 => "1940: Edwin McMillan and Philip Abelson produce neptunium, the first transuranic element discovered",
	      1950 => "1943: Glenn Seaborg modifies the periodic table to include the actinide series",
	      1970 => "1970: John Pople develops Gaussian, an early computational chemistry program",
	      1980 => "1971: Edward Stern, Dale Sayers, and Ferrell Lytle explain XAFS",
	      1990 => "",
	      2000 => "",
	      2010 => "2004: Yuri Oganessian discovers flerovium, beginning a series of discoveries via bombardment by Ca",
	      2020 => "2016: IUPAC names the elements nihonium, moscovium, tennessine, and oganesson",
	     );
sub increment_date {
  my ($self, $event) = @_;
  my $year = 1660 + 10*$self->{date}->GetValue; # discovery of phosphorus in 1669
  $self->{datelabel}->SetLabel("$year");
  foreach my $z (1 .. 118) {
    enable_element($self->{pt}, get_symbol($z), sub{ $kalzium{$z}{date} < $year });
  };
  $self->{echo}->SetStatusText($events{$year} || q{});

};


1;

=head1 NAME

Demeter::UI::Hephaestus::Data - Hephaestus' data utility

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

The contents of Hephaestus' data utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::Data->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility uses a periodic table as the interface to chemical and
physcial data of the elements.  Clicking on an element in the periodic
table will display that element's data.


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

More kinds of data should be included.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2019 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
