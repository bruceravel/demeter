package Demeter::UI::Gtk2::Hephaestus::Help;
use strict;
use warnings;
use Carp;
use Gtk2;
use Glib qw(TRUE FALSE);
use Gtk2::Ex::PodViewer;

use base 'Gtk2::ScrolledWindow';

sub new {
  my $class = shift;
  my $self = Gtk2::ScrolledWindow->new();
  bless $self, $class;
  $self -> set_policy ('never', 'always');

  my $page = Gtk2::Ex::PodViewer -> new;

  my $pod = File::Spec->catfile($Demeter::UI::Gtk2::Hephaestus::hephaestus_base,
				'Hephaestus', 'data', "hephaestus.pod");
  $page -> load($pod);
  $self -> add_with_viewport($page);
  $page -> signal_connect('link_clicked', sub{1});
  $page -> show;
  return $self;
};


1;
