package Ifeffit::Demeter::UI::Gtk2::Hephaestus::PeriodicTable;
use strict;
use warnings;
use Carp;
use Gtk2;
use Glib qw(TRUE FALSE);
use Gtk2::Ex::PodViewer;

use base 'Gtk2::Table';

#           columns: 0 -- 17    rows: 0 -- 8
#           [ symbol, row, column, phase]
my @elements = (['H',  0, 0,  'g'],
		['He', 0, 17, 'g'],
		['Li', 1, 0,  'm'],
		['Be', 1, 1,  'm'],
		['B',  1, 12, 's'],
		['C',  1, 13, 'n'],
		['N',  1, 14, 'n'],
		['O',  1, 15, 'n'],
		['F',  1, 16, 'n'],
		['Ne', 1, 17, 'g'],
		['Na', 2, 0,  'm'],
		['Mg', 2, 1,  'm'],
		['Al', 2, 12, 'm'],
		['Si', 2, 13, 's'],
		['P',  2, 14, 'n'],
		['S',  2, 15, 'n'],
		['Cl', 2, 16, 'n'],
		['Ar', 2, 17, 'g'],
		['K',  3, 0,  'm'],
		['Ca', 3, 1,  'm'],
		['Sc', 3, 2,  'm'],
		['Ti', 3, 3,  'm'],
		['V',  3, 4,  'm'],
		['Cr', 3, 5,  'm'],
		['Mn', 3, 6,  'm'],
		['Fe', 3, 7,  'm'],
		['Co', 3, 8,  'm'],
		['Ni', 3, 9,  'm'],
		['Cu', 3, 10, 'm'],
		['Zn', 3, 11, 'm'],
		['Ga', 3, 12, 'm'],
		['Ge', 3, 13, 's'],
		['As', 3, 14, 's'],
		['Se', 3, 15, 'n'],
		['Br', 3, 16, 'n'],
		['Kr', 3, 17, 'g'],
		['Rb', 4, 0,  'm'],
		['Sr', 4, 1,  'm'],
		['Y',  4, 2,  'm'],
		['Zr', 4, 3,  'm'],
		['Nb', 4, 4,  'm'],
		['Mo', 4, 5,  'm'],
		['Tc', 4, 6,  'm'],
		['Ru', 4, 7,  'm'],
		['Rh', 4, 8,  'm'],
		['Pd', 4, 9,  'm'],
		['Ag', 4, 10, 'm'],
		['Cd', 4, 11, 'm'],
		['In', 4, 12, 'm'],
		['Sn', 4, 13, 'm'],
		['Sb', 4, 14, 's'],
		['Te', 4, 15, 's'],
		['I',  4, 16, 'n'],
		['Xe', 4, 17, 'g'],
		['Cs', 5, 0,  'm'],
		['Ba', 5, 1,  'm'],
		['La', 5, 2,  'm'],
		['Ce', 7, 3,  'm'],
		['Pr', 7, 4,  'm'],
		['Nd', 7, 5,  'm'],
		['Pm', 7, 6,  'm'],
		['Sm', 7, 7,  'm'],
		['Eu', 7, 8,  'm'],
		['Gd', 7, 9,  'm'],
		['Tb', 7, 10, 'm'],
		['Dy', 7, 11, 'm'],
		['Ho', 7, 12, 'm'],
		['Er', 7, 13, 'm'],
		['Tm', 7, 14, 'm'],
		['Yb', 7, 15, 'm'],
		['Lu', 7, 16, 'm'],
		['Hf', 5, 3,  'm'],
		['Ta', 5, 4,  'm'],
		['W',  5, 5,  'm'],
		['Re', 5, 6,  'm'],
		['Os', 5, 7,  'm'],
		['Ir', 5, 8,  'm'],
		['Pt', 5, 9,  'm'],
		['Au', 5, 10, 'm'],
		['Hg', 5, 11, 'm'],
		['Tl', 5, 12, 'm'],
		['Pb', 5, 13, 'm'],
		['Bi', 5, 14, 'm'],
		['Po', 5, 15, 'm'],
		['At', 5, 16, 's'],
		['Rn', 5, 17, 'g'],
		['Fr', 6, 0,  'm'],
		['Ra', 6, 1,  'm'],
		['Ac', 6, 2,  'm'],
		['Th', 8, 3,  'm'],
		['Pa', 8, 4,  'm'],
		['U',  8, 5,  'm'],
		['Np', 8, 6,  'm'],
		['Pu', 8, 7,  'm'],
		['Am', 8, 8,  'm'],
		['Cm', 8, 9,  'm'],
		['Bk', 8, 10, 'm'],
		['Cf', 8, 11, 'm'],
		['Es', 8, 12, 'm'],
		['Fm', 8, 13, 'm'],
		['Md', 8, 14, 'm'],
		['No', 8, 15, 'm'],
		['Lr', 8, 16, 'm'],
		['Rf', 6, 3,  'm'],
		['Ha', 6, 4,  'm'],
		['Sg', 6, 5,  'm'],
		['Bh', 6, 6,  'm'],
		['Hs', 6, 7,  'm'],
		['Mt', 6, 8,  'm'],
	       );

my %color_of = (
		m => '#2F4F4F',	# metal (Dark Slate Grey)
		g => '#FF2400',	# gas (Red)
		s => '#9A32CD',	# semi-metal (Purple)
		n => '#228B22',	# non-metal (Green)
	       );

sub new {
  my ($class, $parent, $callback) = @_;
  my $self = Gtk2::Table->new(8,18);
  bless $self, $class;

  foreach my $el (@elements) {
    my $label = Gtk2::Label->new;
    $label->set_markup("<span foreground='$color_of{$el->[3]}'><b>" . $el->[0] . "</b></span>");
    my $button = Gtk2::Button->new( );
    my $t = $el->[1];
    my $b = $el->[1]+1;
    my $l = $el->[2];
    my $r = $el->[2]+1;
    $button->add($label);
    $button->signal_connect( clicked => sub{$parent->$callback($el->[0])} );
    $self->attach($button, $l, $r, $t, $b, ['shrink', 'fill'], 'shrink', 2, 2);
  };
  my $label = Gtk2::Label->new('Lanthenides');
  $label -> set_justify('right');
  $self->attach($label, 0, 3, 7, 8, ['shrink', 'fill'], 'shrink', 2, 2);
  $label = Gtk2::Label->new('Actinides');
  $label -> set_justify('right');
  $self->attach($label, 0, 3, 8, 9, ['shrink', 'fill'], 'shrink', 2, 2);

  return $self;
};

1;
