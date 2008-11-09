package Demeter::UI::Gtk2::Hephaestus;
use strict;
use warnings;
use Carp;
use Gtk2;
use Gtk2::Gdk::Keysyms;
use Glib qw(TRUE FALSE);
use File::Basename;
use File::Spec;

use Ifeffit;
use Demeter;

use base 'Gtk2::Window';

sub import {
  foreach my $m (qw(Absorption Data EdgeFinder LineFinder Transitions F1F2 Help)) {
    next if $INC{"Demeter/UI/Gtk2/Hephaestus/$m.pm"};
    ##print "Demeter/UI/Gtk2/Hephaestus/$m.pm\n";
    require "Demeter/UI/Gtk2/Hephaestus/$m.pm";
  };
};
sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};

use vars qw($hephaestus_base);
$hephaestus_base = identify_self();

my %note_of = (absorption   => 'periodic table of edge and line energies',
	       formulas     => 'compute total cross sections of materials',
	       data	    => 'chemical data for the elements',
	       ion	    => 'optimize ion chamber gases',
	       transitions  => 'electronic transions for fluorescence lines',
	       find	    => 'ordered list of absorption edge energies',
	       line	    => 'ordered list of fluorescence line energies',
	       f1f2	    => 'periodic table of anomalous scattering',
	       help	    => '',
	       configure    => '',
	     );
my %label_of = (absorption   => 'Absorption',
		formulas     => 'Formulas',
		data	     => 'Data',
		ion	     => 'Ion chambers',
		transitions  => 'Transitions',
		find	     => 'Edge finder',
		line	     => 'Line finder',
		f1f2	     => "F' and F\"",
		help	     => 'Document',
		configure    => 'Configure',
	       );



sub new {
  my $class = shift; # create
  my $self = Gtk2::Window->new;
  bless $self, $class;

  my $vbox = Gtk2::VBox->new;
  $self->add ($vbox);
  $vbox->show;

  #$self->set_position('center-always');

  $self->{notebook} = Gtk2::Notebook->new;
  $self->{notebook}->set_tab_pos('left');
  $self->{notebook}->set_scrollable(0);


  # put whatever files or whatever in here 
  foreach my $page (qw(absorption formulas data ion transitions find line f1f2 configure help)) {

    # Create a frame
    # Add the frame to a scrolledwindow
    my $display = Gtk2::Frame->new( );
    my $labwidg = Gtk2::Label->new( );
    my $style = $labwidg->get_style; # set up the new style the way you want.
    my $fg = '#5500aa';
    $labwidg->set_markup("<b><span foreground=\"$fg\" size=\"15000\"> "
			 . $label_of{$page}
			 . ":</span> <span foreground=\"$fg\" size=\"12000\">"
			 . $note_of{$page}
			 . " </span></b>");



    $display -> set_label_widget($labwidg);
    $display -> set_shadow_type('none');

    my $this = ($page eq 'transitions') ? Demeter::UI::Gtk2::Hephaestus::Transitions->new()
             : ($page eq 'find')        ? Demeter::UI::Gtk2::Hephaestus::EdgeFinder->new()
             : ($page eq 'line')        ? Demeter::UI::Gtk2::Hephaestus::LineFinder->new()
             : ($page eq 'help')        ? Demeter::UI::Gtk2::Hephaestus::Help->new()
             : ($page eq 'absorption')  ? Demeter::UI::Gtk2::Hephaestus::Absorption->new() # periodic tables
             : ($page eq 'data')        ? Demeter::UI::Gtk2::Hephaestus::Data->new()
             : ($page eq 'f1f2')        ? Demeter::UI::Gtk2::Hephaestus::F1F2->new()
             :                            q{};
    if ($this) {
      $display->add($this);
      $this -> show;
    };
    #add to notebook
    $self->{notebook}->append_page($display, $self->make_label($page));
  };

  # the dialog's vbox is an advertised widget which you can add to
  $vbox->pack_start($self->{notebook},1,1,0);
  $vbox->show_all();

  my %dispatch_table = (
			$Gtk2::Gdk::Keysyms{q}    => sub { my $demeter = Demeter->new;
							   $demeter->po->cleantemp;
							   Gtk2->main_quit;
							 },
			$Gtk2::Gdk::Keysyms{Up}   => sub{$self->{notebook}->prev_page},
			$Gtk2::Gdk::Keysyms{Down} => sub{$self->{notebook}->next_page},
		       );
  $self->signal_connect (key_press_event => sub {
			   my ($widget, $event) = @_;
			   my $this = $event->keyval;
			   return 0 if not $dispatch_table{$this};
			   return 0 if (($event->state)[0] !~ m{control});
			   &{$dispatch_table{$this}};
			   return 0;
			 });


  return $self;
}

sub make_label {
  my ($self,$text) = @_;
  my $hbox = Gtk2::HBox->new;
  my $label = Gtk2::Label->new($label_of{$text}." ");
  my $image = Gtk2::Image->new_from_file(File::Spec->catfile($hephaestus_base, 'Hephaestus', 'icons', "$text.png"));
  $hbox->pack_start( $image, FALSE, FALSE, 0 );
  $hbox->pack_start( $label, FALSE, FALSE, 0 );
  $label->show;
  $image->show;

  return $hbox;
}

## Edge finder and configure icons from Kids icon set for KDE, Everaldo Coelho, http://www.everaldo.com
## Absorbtion (gold), Formulas (mortar), Data (chemical hazard), Document (book) icons taken from Wikimedia (search terms)
## f1f2 icon adapted from graphics at Matt's diffkk homepage
## Ion chambers icon taken from http://www.adc9001.com/index.php?src=synchrotron
## Tranisitions is (as I recall) original artwork
## Line finder icon from http://alpha.asi.ualberta.com/ProjectAreas/XraySpec/xrayproj.htm, Fig 2, Ni panel

1;

