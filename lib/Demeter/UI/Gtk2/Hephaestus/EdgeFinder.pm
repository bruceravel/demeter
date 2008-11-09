package Demeter::UI::Gtk2::Hephaestus::EdgeFinder;
use strict;
use warnings;
use Carp;
use Gtk2;
use Glib qw(TRUE FALSE);
use Scalar::Util qw(looks_like_number);

use base 'Gtk2::Frame';


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
					'Edge'          => 'text',
					'Energy'.q{ }x4 => 'scalar',
				       );
  $list->get_selection->set_mode('single');
  $list -> set_headers_visible(1);
  $self->{data} = $list;
  my $i = 0;
  foreach my $ed (@edge_list) {
    push @{$list->{data}}, [ ucfirst($ed->[0]), ucfirst($ed->[1]), $ed->[2] ];
    ++$i if ($ed->[2] < 8978);
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
  $hbox -> pack_start($search, FALSE, FALSE, 1);

  my $vbox = Gtk2::VBox -> new;
  $search -> add ($vbox);

  ## -------- Entry box for inputting target energy, Return activates a search
  $self->{target} = 8979;
  $self->{entry} = Gtk2::Entry->new_with_max_length(20);
  $self->{entry} -> show;
  $vbox->pack_start ($self->{entry}, FALSE, FALSE, 5);
  $self->{entry} -> set_text($self->{target});
  $self->{entry}->{insert} = $self->{entry}->signal_connect('insert_text' => \&edge_validate);
  $self->{entry}->{keypress} = 
    $self->{entry}->signal_connect('key-press-event' =>
				   sub {
				     my ($widget,$event)= @_;
				     ## return triggers a search
				     if ($event->keyval() eq $Gtk2::Gdk::Keysyms{Return}) {
				       edge_search($self);
				       return TRUE;
				     };
				     return FALSE;
				   });


  ## -------- Radio button for selecting harmonic
  $self->{harmonic} = 'Fundamental';
  my $radio = undef;
  foreach my $value (qw(Fundamental Second Third)) {
    $radio = Gtk2::RadioButton->new ($radio, $value);
    $radio->signal_connect(toggled =>
			   sub {
			     my ($rb) = @_;
			     $self->{harmonic} = $rb->get_label;
			     edge_search($self);
			   });
    $vbox->pack_start ($radio, FALSE, FALSE, 0);
    $radio->set_active (TRUE) if $self->{harmonic} eq $value;
  }

  return $self;
};

sub edge_validate {
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


sub edge_search {
  my ($self) = @_;
  $self->{target} = $self->{entry}->get_text;
  return 0 if not looks_like_number($self->{target});
  #print $self->{target}, "  ", $self->{harmonic}, $/;
  my $target = ($self->{harmonic} eq 'Fundamental') ? $self->{target}
             : ($self->{harmonic} eq 'Second')      ? $self->{target} * 2
             :                                        $self->{target} * 3;
  return 0 if ($target < 100);
  my $list = $self->{data};
  my $i = 0;
  foreach my $ed (@edge_list) {
    last if ($ed->[2] > $target);
    ++$i;
  };
  $list -> get_selection -> unselect_all;
  my $path = Gtk2::TreePath->new_from_indices ($i-1);
  $list->scroll_to_cell($path);
  $list->select($i-1);
  return 1;
};

1;
