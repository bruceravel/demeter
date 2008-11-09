package Demeter::UI::Gtk2::Hephaestus::F1F2;
use strict;
use warnings;
use Carp;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Gtk2;
use Glib qw(TRUE FALSE);
use Gtk2::Ex::PodViewer;

use base 'Gtk2::Frame';
use Demeter;
use Demeter::UI::Gtk2::Hephaestus::PeriodicTable;
use Gtk2::SimpleList;

my $demeter = Demeter->new;

sub new { 
  my $class = shift;
  my $self = Gtk2::Frame->new;
  bless $self, $class;

  ## -------- Periodic table
  my $pt = Demeter::UI::Gtk2::Hephaestus::PeriodicTable -> new($self, 'f1f2_get_data');
  my $vbox = Gtk2::VBox->new;
  $pt   -> show;
  $vbox -> pack_start($pt, FALSE, FALSE, 1);
  $self -> add($vbox);


  ## -------- Energy grid
  my $hbox = Gtk2::HBox->new;
  $vbox -> pack_start($hbox, FALSE, FALSE, 5);
  my %labels = (emin=>'Starting energy', emax=>'Ending energy', egrid=>'Energy grid');
  my %defaults = (emin=>3000, emax=>7000, egrid=>5, width=>0);
  foreach my $e (qw(emin emax egrid)) {
    my $lab = Gtk2::Label->new( $labels{$e} );
    $hbox -> pack_start($lab, FALSE, FALSE, 1);
    $lab->show;

    $self->{$e."box"} = Gtk2::Entry->new;
    $self->{$e."box"}->set_text($defaults{$e});
    $hbox -> pack_start($self->{$e."box"}, FALSE, FALSE, 1);
    $self->{$e."box"}->set_width_chars(6);
    $self->{$e."box"}->show;
  };

  ## -------- Convolution
  $hbox = Gtk2::HBox->new;
  $vbox -> pack_start($hbox, FALSE, FALSE, 1);

  $self->{convlab} = Gtk2::Label->new( 'Convolution width' );
  $self->{convlab}->set_markup("<span foreground='#888888'>Convolution width</span>");
  $self->{convlab}->show;
  $hbox -> pack_start($self->{convlab}, FALSE, FALSE, 1);
  $self->{widthbox} = Gtk2::Entry->new;
  $self->{widthbox}->set_text($defaults{width});
  $hbox -> pack_start($self->{"widthbox"}, FALSE, FALSE, 1);
  $self->{widthbox}->set_width_chars(6);
  $self->{widthbox}->show;
  $self->{widthbox}->set_visibility(0);
  $self->{widthbox}->set_editable(0);

  $self->{natural} = Gtk2::CheckButton->new ( 'Convolute by the natural core-level width' );
  $hbox -> pack_start($self->{natural}, FALSE, FALSE, 1);
  $self->{natural}->set_active(1);
  $self->{natural}->signal_connect(toggled =>
				   sub {
				     my ($rb) = @_;
				     if ($self->{natural} -> get_active) {
				       $self->{convlab}->set_markup("<span foreground='#888888'>Convolution width</span>");
				       $self->{widthbox}->set_visibility(0);
				       $self->{widthbox}->set_editable(0)
				     } else {
				       $self->{convlab}->set_markup("<span foreground='#000000'>Convolution width</span>");
				       $self->{widthbox}->set_visibility(1);
				       $self->{widthbox}->set_editable(1);
				     };
				   });
  $self->{natural}->show;

  ## -------- How to plot
  $hbox = Gtk2::HBox->new;
  $vbox -> pack_start($hbox, FALSE, FALSE, 5);

  my $nobox = Gtk2::VBox->new;
  $hbox -> pack_start($nobox, FALSE, FALSE, 5);
  ## -------- Radio button for new/over plot
  $self->{howplot} = 'New plot';
  my $radio = undef;
  foreach my $value ('New plot', 'Overplot') {
    $radio = Gtk2::RadioButton->new ($radio, $value);
    $radio->signal_connect(toggled =>
			   sub {
			     my ($rb) = @_;
			     $self->{howplot} = $rb->get_label;
			   });
    $nobox->pack_start ($radio, FALSE, FALSE, 0);
    $radio->set_active (FALSE) if $self->{howplot} eq $value;
  }

  my $fppbox = Gtk2::VBox->new;
  $hbox -> pack_start($fppbox, FALSE, FALSE, 5);
  ## -------- Radio button for f'/f"/both plot
  $self->{fplot} = "Plot both f' and f\"";
  $radio = undef;
  foreach my $value ("Plot just f'", 'Plot just f"', "Plot both f' and f\"") {
    $radio = Gtk2::RadioButton->new ($radio, $value);
    $radio->signal_connect(toggled =>
			   sub {
			     my ($rb) = @_;
			     $self->{fplot} = $rb->get_label;
			   });
    $fppbox->pack_start ($radio, FALSE, FALSE, 0);
    $radio->set_active (FALSE) if $self->{fplot} eq $value;
  }

  ## -------- Save data
  $hbox = Gtk2::HBox->new;
  $vbox -> pack_start($hbox, FALSE, FALSE, 1);
  $self->{save} = Gtk2::Button->new( 'Save data' );
  $self->{save} -> show;
  $self->{save}->signal_connect( clicked => sub{print "I don't do anything yet.\n"} );
  $self->{save}->set_sensitive(0);
  $hbox -> pack_start($self->{save}, FALSE, FALSE, 60);


  return $self;
};

sub f1f2_get_data {
  my ($self, $el) = @_;
  local $| = 1;
  ##print join("|", $el, $self->{howplot}, $self->{fplot}, $self->{natural}->get_active, $self->{eminbox}->get_text), $/;

  $self->{save}->set_sensitive(1);
  $self->{save}->set_label('Save ' . get_symbol($el) . ' data');

  $demeter -> plot_with('pgplot');
  $demeter->co->set(
		    f1f2_emin    => $self->{eminbox}->get_text,
		    f1f2_emax    => $self->{emaxbox}->get_text,
		    f1f2_egrid   => $self->{egridbox}->get_text,
		    f1f2_z       => $el,
		    f1f2_newplot => ($self->{howplot} =~ m{New}) ? 1 : 0,
		    f1f2_width   => ($self->{natural}->get_active) ? 0 : $self->{widthbox}->get_text,
		    f1f2_file    => $demeter->po->tempfile,
		   );
  my $which = ($self->{fplot} =~ m{both}) ? 'f1f2'
            : ($self->{fplot} =~ m{f'\z}) ? 'f1'
	    :                               'f2';
  $demeter -> po -> start_plot if ($self->{howplot} =~ m{New});
  $demeter->dispose($demeter->template("plot", 'prep_f1f2'));
  $demeter->dispose($demeter->template("plot", $which), "plotting");

  #$demeter->po->cleantemp;
  #undef $demeter;
  return 1;
};

1;
