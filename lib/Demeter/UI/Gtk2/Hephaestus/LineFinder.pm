package Demeter::UI::Gtk2::Hephaestus::LineFinder;
use strict;
use warnings;
use Carp;
use Gtk2;
use Glib qw(TRUE FALSE);
use Scalar::Util qw(looks_like_number);

use base 'Gtk2::Frame';


## snarf (quietly!) the list of energies from the list used for the
## next_energy function in Xray::Absoprtion::Elam
my $hash;
do {
  no warnings;
  $hash = $$Xray::Absorption::Elam::r_elam{line_list};
};
my @line_list = ();
foreach my $key (keys %$hash) {
  next unless exists $$hash{$key}->[2];
  push @line_list, $$hash{$key};
};
## and sort by increasing energy
@line_list = sort {$a->[2] <=> $b->[2]} @line_list;

sub new {
  my $class = shift;
  my $self = Gtk2::Frame->new;
  bless $self, $class;



  my $frame = Gtk2::Frame->new(  );
  $self -> add($frame);
  $frame -> show;

  my $hbox = Gtk2::HBox->new;
  $frame -> add($hbox);

  my $scrolled = Gtk2::ScrolledWindow->new;
  $scrolled->set_policy ('never', 'automatic');
  $scrolled->set_shadow_type('etched-in');
  my $list = Gtk2::SimpleList->new (
					'Element'       => 'text',
					'Line'          => 'text',
					'Transition'    => 'text',
					'Strength'      => 'text',
					'Energy'.q{ }x4 => 'scalar',
				       );
  $list->get_selection->set_mode('single');
  $list -> set_headers_visible(1);
  $self->{data} = $list;
  my $i = 0;
  foreach my $ed (@line_list) {
    push @{$list->{data}}, [ ucfirst($ed->[0]),
			     Xray::Absorption->get_Siegbahn_full($ed->[1]),
			     Xray::Absorption->get_IUPAC($ed->[1]),
			     sprintf("%.4f", Xray::Absorption->get_intensity($ed->[0], $ed->[1])),
			     $ed->[2] ];
    ++$i if ($ed->[2] < 8046);
  };
  $scrolled -> add($list);
  $list -> show;
  $scrolled -> show;
  #print $list->{data}[1][1], $/;
  #$list -> scroll_to_point(0, 0.8);

  my $path = Gtk2::TreePath->new_from_indices ($i-10);
  $list->scroll_to_cell ($path);
  $list->select($i);

  $hbox -> pack_start($scrolled, FALSE, FALSE, 1);

  my $search = Gtk2::Frame->new( 'Target energy' );
  $hbox -> pack_start($search, FALSE, FALSE, 10);

  my $vbox = Gtk2::VBox -> new;
  $search -> add ($vbox);

  ## -------- Entry box for inputting target energy, Return activates a search
  $self->{target} = 8046;
  $self->{entry} = Gtk2::Entry->new_with_max_length(20);
  $self->{entry} -> show;
  $vbox->pack_start ($self->{entry}, FALSE, FALSE, 5);
  $self->{entry} -> set_text($self->{target});
  $self->{entry}->{insert} = $self->{entry}->signal_connect('insert_text' => \&line_validate);
  $self->{entry}->{keypress} = 
    $self->{entry}->signal_connect('key-press-event' =>
				   sub {
				     my ($widget,$event)= @_;
				     ## return triggers a search
				     if ($event->keyval() eq $Gtk2::Gdk::Keysyms{Return}) {
				       line_search($self);
				       return TRUE;
				     };
				     return FALSE;
				   });


  ## -------- Button for starting search
  $self->{harmonic} = 'Fundamental';
  my $button = Gtk2::Button -> new( 'Search' );
  $button -> show;
  $vbox->pack_start ($button, FALSE, FALSE, 0);
  $button->signal_connect( clicked => sub{ line_search($self) } );

  return $self;
};

sub line_validate {
  my ($entry, $text, $len, $pos) = @_;
  $text =~ s/[^-0-9]//g;
  if (length($text)) { # we temporarily block the signal to avoid recursion
    $entry->signal_handler_block($entry->{insert});
    $pos = $entry->insert_text($text, $pos);
    $entry->signal_handler_unblock($entry->{insert});
  };
  #$entry->signal_emit_stop_by_name('insert-text');
  # return the new position of the cursor here
  return (q{}, $pos);
}


sub line_search {
  my ($self) = @_;
  $self->{target} = $self->{entry}->get_text;
  return 0 if not looks_like_number($self->{target});
  my $list = $self->{data};
  my $i = 0;
  foreach my $li (@line_list) {
    last if ($li->[2] > $self->{target});
    ++$i;
  };
  $list -> get_selection -> unselect_all;
  my $path = Gtk2::TreePath->new_from_indices ($i);
  $list->scroll_to_cell($path);
  $list->select($i);
  return 1;
};

1;
