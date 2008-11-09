package Demeter::UI::Gtk2::Hephaestus::Data;
use strict;
use warnings;
use Carp;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Config::IniFiles;
use Gtk2;
use Glib qw(TRUE FALSE);
use Gtk2::Ex::PodViewer;

use base 'Gtk2::Frame';
use Demeter::UI::Gtk2::Hephaestus::PeriodicTable;
use Gtk2::SimpleList;

my %kalziumlist = (Name	      => 'Name',
		   Symbol     => 'Symbol',
		   Weight     => 'Atomic Weight',
		   Orbits     => 'Orbital Configuration',
		   Ox	      => 'Oxidation States',
		   Mossbauer  => 'Mossbauer',
		   MP	      => 'Melting Point',
		   BP	      => 'Boiling Point',
		   EN	      => 'Electronegativity',
		   IE	      => 'Ionization Energy',
		   IE2	      => '2nd Ion. Energy',
		   AR	      => 'Atomic Radius'
		  );

my %kalzium;
tie %kalzium, 'Config::IniFiles', (-file=>File::Spec->catfile($Demeter::UI::Gtk2::Hephaestus::hephaestus_base,
							      'Hephaestus', 'data', "kalziumrc"));

sub new { 
  my $class = shift;
  my $self = Gtk2::Frame->new;
  bless $self, $class;

  my $pt = Demeter::UI::Gtk2::Hephaestus::PeriodicTable -> new($self, 'data_get_data');

  my $vbox = Gtk2::VBox->new;

  $pt   -> show;
  $vbox -> pack_start($pt, FALSE, FALSE, 1);
  $self -> add($vbox);


  my $frame = Gtk2::Frame->new(  );
  $frame->set_shadow_type('etched-in');


  my $datalist = Gtk2::SimpleList->new (
					'Property'        => 'text',
					'Value'.q{ } x 25 => 'scalar',
					'Property'        => 'text',
					'Value'.q{ } x 25 => 'scalar',
				       );
  $datalist->get_selection->set_mode ('none');
  $self->{datalist} = $datalist;
  push @{$datalist->{data}}, [ 'Name',                  q{}, $kalziumlist{MP},  q{} ];
  push @{$datalist->{data}}, [ 'Number',                q{}, $kalziumlist{BP},  q{} ];
  push @{$datalist->{data}}, [ 'Symbol',                q{}, $kalziumlist{EN},  q{} ];
  push @{$datalist->{data}}, [ $kalziumlist{Weight},    q{}, $kalziumlist{IE},  q{} ];
  push @{$datalist->{data}}, [ $kalziumlist{Orbits},    q{}, $kalziumlist{IE2}, q{} ];
  push @{$datalist->{data}}, [ $kalziumlist{Ox},        q{}, $kalziumlist{AR},  q{} ];
  push @{$datalist->{data}}, [ $kalziumlist{Mossbauer}, q{}, q{}             ,  q{} ];
  $frame -> add($datalist);


  my $hbox = Gtk2::HBox->new;
  $vbox -> pack_start($hbox, FALSE, FALSE, 1);
  $datalist -> show;
  $hbox -> pack_start($frame, FALSE, FALSE, 1);




  return $self;
};

sub data_get_data {
  my ($self, $el) = @_;
  my $z = get_Z($el);
  my $datalist = $self->{datalist};
  $datalist -> get_selection -> unselect_all;
  $datalist -> cell_insert(0, 1, get_name($el));
  $datalist -> cell_insert(1, 1, $z);
  $datalist -> cell_insert(2, 1, get_symbol($el));
  $datalist -> cell_insert(3, 1, $kalzium{$z}{Weight});
  $datalist -> cell_insert(4, 1, $kalzium{$z}{Orbits});
  $datalist -> cell_insert(5, 1, $kalzium{$z}{Ox});
  $datalist -> cell_insert(6, 1, $kalzium{$z}{Mossbauer});

  $datalist -> cell_insert(0, 3, $kalzium{$z}{MP});
  $datalist -> cell_insert(1, 3, $kalzium{$z}{BP});
  $datalist -> cell_insert(2, 3, $kalzium{$z}{EN});
  $datalist -> cell_insert(3, 3, $kalzium{$z}{IE});
  $datalist -> cell_insert(4, 3, $kalzium{$z}{IE2});
  $datalist -> cell_insert(5, 3, $kalzium{$z}{AR});
};

1;
