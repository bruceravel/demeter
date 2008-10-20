package Ifeffit::Demeter::UI::Gtk2::Hephaestus::Transitions;
use strict;
use warnings;
use Carp;
use Gtk2;
use Glib qw(TRUE FALSE);

use base 'Gtk2::Frame';

sub new { 
  my $class = shift;
  my $self = Gtk2::Frame->new;
  bless $self, $class;

  my $image = Gtk2::Image->new_from_file(File::Spec->catfile($Ifeffit::Demeter::UI::Gtk2::Hephaestus::hephaestus_base,
							     'Hephaestus', 'data', "trans_table.png"));
  $image -> set_padding(10, 10);
  $self  -> add($image);
  $image -> show;
  return $self;
};


1;
