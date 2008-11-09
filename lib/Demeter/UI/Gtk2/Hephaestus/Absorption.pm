package Demeter::UI::Gtk2::Hephaestus::Absorption;
use strict;
use warnings;
use Carp;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Gtk2;
use Glib qw(TRUE FALSE);
use Gtk2::Ex::PodViewer;

use base 'Gtk2::Frame';
use Demeter::UI::Gtk2::Hephaestus::PeriodicTable;
use Gtk2::SimpleList;

use Xray::Absorption;

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
  my $class = shift;
  my $self = Gtk2::Frame->new;
  bless $self, $class;

  my $pt = Demeter::UI::Gtk2::Hephaestus::PeriodicTable -> new($self, 'abs_get_data');

  my $vbox = Gtk2::VBox->new;

  $pt   -> show;
  $vbox -> pack_start($pt, FALSE, FALSE, 1);
  $self -> add($vbox);

  my $frame = Gtk2::Frame->new(  );
  $frame->set_shadow_type('etched-in');


  my $datalist = Gtk2::SimpleList->new (
					'Property' => 'text',
					'Value'.q{ }x17    => 'scalar',
				       );
  $datalist->get_selection->set_mode ('none');
  $self->{datalist} = $datalist;
  @{$datalist->{data}} = (
			  [ 'Name',    q{} ],
			  [ 'Number',  0   ],
			  [ 'Weight',  q{} ],
			  [ 'Density', q{} ],
			  [ 'Filter',  q{} ],
			 );
  $frame -> add($datalist);

  my $hbox = Gtk2::HBox->new;
  $vbox -> pack_start($hbox, FALSE, FALSE, 1);
  $datalist -> show;
  $hbox -> pack_start($frame, FALSE, FALSE, 1);



  my $scrolled = Gtk2::ScrolledWindow->new;
  $scrolled->set_policy ('never', 'automatic');
  $scrolled->set_shadow_type('etched-in');
  my $edgelist = Gtk2::SimpleList->new (
					'Edge'          => 'text',
					'Energy'.q{ }x4 => 'scalar',
				       );
  $edgelist->get_selection->set_mode('single');
  $self->{edges} = $edgelist;
  foreach my $ed (@EDGELIST) {
    push @{$edgelist->{data}}, [ $ed, q{}];
  };
  $scrolled -> add($edgelist);
  $edgelist -> show;
  $hbox -> pack_start($scrolled, FALSE, FALSE, 1);



  $scrolled = Gtk2::ScrolledWindow->new;
  $scrolled->set_policy ('never', 'automatic');
  $scrolled->set_shadow_type('etched-in');
  my $linelist = Gtk2::SimpleList->new (
					'Line'            => 'text',
					'Transition'      => 'text',
					'Energy'.q{ }x4   => 'scalar',
					'Strength'        => 'scalar',
				       );
  $linelist->get_selection->set_mode('multiple');
  $self->{lines} = $linelist;
  foreach my $li (@LINELIST) {
    push @{$linelist->{data}}, [ Xray::Absorption->get_Siegbahn_full($li), Xray::Absorption->get_IUPAC($li), q{}, q{}];
  };
  ##$scrolled -> set_border_width(4);
  $scrolled -> add($linelist);
  $linelist -> show;
  $hbox -> pack_start($scrolled, FALSE, FALSE, 1);

  $edgelist -> get_selection -> 
    signal_connect( changed => sub {
		      my ($self) = @_;
		      local $|=1;
		      return if not (($self->get_selected)[1]);
		      $linelist->get_selection->unselect_all;
		      my $x = ($self->get_selected)[0]->get(($self->get_selected)[1], 0);
		      my $i = -1;
		      foreach my $li (@LINELIST) {
			my $iupac = uc(Xray::Absorption->get_IUPAC($li));
			$i++;
			next if ($iupac !~ m{\A$x});
			$linelist->select($i);
		      };
		    });


  $hbox = Gtk2::HBox->new;
  $vbox -> pack_start($hbox, FALSE, FALSE, 1);
  $self->{plot} = Gtk2::Button->new( 'Plot filter' );
  $self->{plot}->signal_connect( clicked => sub{ filter_plot($datalist->{data}[0][1], $datalist->{data}[4][1]) } );
  $vbox -> pack_start($self->{plot}, FALSE, FALSE, 1);
  $self->{plot}->set_sensitive (FALSE);

  return $self;
};

sub filter_plot {
  my ($elem, $filter) = @_;
  my $z      = get_Z($elem);
  my $edge   = ($z < 57) ? "K"   : "L3";
  my $line2  = ($z < 57) ? "Ka2" : "La1";

  my $demeter = Demeter->new;
  $demeter -> plot_with('gnuplot');
  $demeter->co->set(
		    filter_abs      => $z,
		    filter_edge     => $edge,
		    filter_filter   => $filter,
		    filter_emin     => Xray::Absorption -> get_energy($z, $line2) - 400,
		    filter_emax     => Xray::Absorption -> get_energy($z, $edge)  + 300,
		    filter_file     => $demeter->po->tempfile,
		   );
  $demeter -> po -> start_plot;
  my $command = $demeter->template('plot', 'prep_filter');
  $demeter -> dispose($command);

  $command = $demeter->template('plot', 'filter');
  $demeter -> po -> legend(x => 0.15, y => 0.85, );
  $demeter -> dispose($command, "plotting");

  $demeter->po->cleantemp;
  undef $demeter;
  return 1;
};

sub _label_style {
  return "<span weight=\"bold\" gravity=\"east\">$_[0]</span>"
};



sub abs_get_data {
  my ($self, $el) = @_;
  my $datalist = $self->{datalist};
  my $z = get_Z($el);
  $datalist->cell_insert(0, 1, get_name($el));
  $datalist->cell_insert(1, 1, $z);
  $datalist->cell_insert(2, 1, Xray::Absorption->get_atomic_weight($el) . ' amu');
  $datalist->cell_insert(3, 1, Xray::Absorption->get_density($el) . ' g/cm^3');

  my $filter = ($z <  24) ? q{}
             : ($z == 37) ? 35     ## Kr is a stupid filter material
             : ($z <  39) ? $z - 1 ## Z-1 for V - Y
             : ($z == 45) ? 44     ## Tc is a stupid filter material
             : ($z == 56) ? 53     ## Xe is a stupid filter material
             : ($z <  57) ? $z - 2 ## Z-2 for Zr - Ba
	     : l_filter($el);	   ## K filter for heavy elements
  $datalist->cell_insert(4, 1, get_symbol($filter));

  my $edgelist = $self->{edges};
  $edgelist -> get_selection -> unselect_all;
  my $i = 0;
  foreach my $ed (@EDGELIST) {
    $edgelist->cell_insert($i++, 1, Xray::Absorption->get_energy($el, $ed));
  };

  my $linelist = $self->{lines};
  $linelist -> get_selection -> unselect_all;
  $i = 0;
  foreach my $li (@LINELIST) {
    $linelist->cell_insert($i,   2, Xray::Absorption->get_energy($el, $li));
    my $intensity = Xray::Absorption->get_intensity($el, $li);
    $linelist->cell_insert($i++, 3, ($intensity) ? sprintf("%.4f", $intensity) : q{});
  };

  ($filter) ? $self->{plot}->set_sensitive (TRUE) :$self->{plot}->set_sensitive (FALSE);

};

sub l_filter {
  my $elem = $_[0];
  return q{} if (get_Z($elem) > 98);
  my $en = Xray::Absorption -> get_energy($elem, 'la1') + 3*30;
  my $filter = q{};
  foreach (@k_list) {
    $filter = $_->[0];
    last if ($_->[2] >= $en);
  };
  my $result = get_Z($filter);
  ++$result if ($result == 36);
  return $result;
};


package Patch::BR::Gtk2::SimpleList;

use Gtk2::SimpleList;
package Gtk2::SimpleList;

sub cell_insert {
  my ($self, $row, $col, $value) = @_;
  $self->{data}[$row][$col] = $value;
};


1;
