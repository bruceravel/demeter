package Demeter::UI::Athena::Deglitch;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX);

use Demeter::UI::Wx::SpecialCharacters qw(:all);

use File::Basename;
use List::MoreUtils qw(minmax);

use vars qw($label);
$label = "Deglitch data";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [60,-1];

my $icon          = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye      = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  my $singlebox       = Wx::StaticBox->new($this, -1, 'Deglitch a single point', wxDefaultPosition, wxDefaultSize);
  my $singleboxsizer  = Wx::StaticBoxSizer->new( $singlebox, wxHORIZONTAL );
  $box               -> Add($singleboxsizer, 0, wxGROW|wxALL, 5);

  $this->{plotas}     = Wx::RadioBox->new($this, -1, q{Plot as}, wxDefaultPosition, wxDefaultSize,
					  ["$MU(E)", "$CHI(E)"], 1, wxRA_SPECIFY_ROWS);
  $this->{choose}     = Wx::Button->new($this, -1, "Choose a point");
  $this->{remove}     = Wx::Button->new($this, -1, "Remove point");
  $this->{replot}     = Wx::Button->new($this, -1, "Replot");
  $singleboxsizer    -> Add($this->{plotas}, 0, wxALL|wxALIGN_CENTER, 5);
  $singleboxsizer    -> Add($this->{choose}, 1, wxALL|wxALIGN_CENTER, 5);
  $singleboxsizer    -> Add($this->{remove}, 1, wxALL|wxALIGN_CENTER, 5);
  $singleboxsizer    -> Add($this->{replot}, 1, wxALL|wxALIGN_CENTER, 5);
  EVT_RADIOBOX($this, $this->{plotas}, sub{OnPlotas(@_, $app)});
  EVT_BUTTON($this, $this->{choose}, sub{OnChoose(@_, $app)});
  EVT_BUTTON($this, $this->{remove}, sub{OnRemove(@_, $app)});
  EVT_BUTTON($this, $this->{replot}, sub{$this->plot($app->current_data)});
  $this->{remove}->Enable(0);

  my $manybox         = Wx::StaticBox->new($this, -1, 'Deglitch many points', wxDefaultPosition, wxDefaultSize);
  my $manyboxsizer    = Wx::StaticBoxSizer->new( $manybox, wxVERTICAL );
  $box               -> Add($manyboxsizer, 0, wxGROW|wxALL, 5);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $manyboxsizer -> Add($hbox, 0, wxGROW|wxALL, 0);

  $this->{margin_label} = Wx::StaticText->new($this, -1, "Margin:");
  $hbox -> Add($this->{margin_label}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{margin} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $hbox -> Add($this->{margin}, 0, wxALL|wxALIGN_CENTER, 5);

  $this->{emin_label} = Wx::StaticText->new($this, -1, "Emin:");
  $hbox -> Add($this->{emin_label}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{emin} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $hbox -> Add($this->{emin}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{emin_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox -> Add($this->{emin_pluck}, 0, wxALL|wxALIGN_CENTER, 5);

  $this->{emax_label} = Wx::StaticText->new($this, -1, "Emax:");
  $hbox -> Add($this->{emax_label}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{emax} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $hbox -> Add($this->{emax}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{emax_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox -> Add($this->{emax_pluck}, 0, wxALL|wxALIGN_CENTER, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $manyboxsizer -> Add($hbox, 0, wxGROW|wxALL, 0);
  $this->{replot_many} = Wx::Button->new($this, -1, "Replot margins");
  $this->{remove_many} = Wx::Button->new($this, -1, "Remove points");
  $hbox -> Add($this->{replot_many}, 1, wxALL|wxALIGN_CENTER, 5);
  $hbox -> Add($this->{remove_many}, 1, wxALL|wxALIGN_CENTER, 5);
  $this->{remove_many}->Enable(0);

  $manybox->Enable(0);
  $this->{$_}->Enable(0) foreach (qw(margin margin_label emin emin_label
				     emax emax_label emax_pluck emax_pluck
				     replot_many remove_many));

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: deglitching');
  $this->{return}   = Wx::Button->new($this, -1, 'Return to main window');
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 2) foreach (qw(document return));
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("deglitch")});
  EVT_BUTTON($this, $this->{return},   sub{  $app->{main}->{views}->SetSelection(0); $app->OnGroupSelect});

  $this->SetSizerAndFit($box);
  return $this;
};

## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  $data->_update('background');
  $this->{margin}->SetValue(0.1 * $data->bkg_step);
  $this->{emin}->SetValue($data->bkg_nor1);
  $this->{emax}->SetValue($data->bkg_nor2);
  if ($data->datatype eq 'chi') {
    $this->Enable(0);
    return;
  };
  $this->plot($data);
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub plot {
  my ($this, $data) = @_;
  my $save = $data->po->datastyle;
  $data->po->datastyle("points");

  $::app->{main}->{PlotE}->pull_single_values;
  $data->po->set(e_mu=>1, e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  $data->po->start_plot;

  my $space = ($this->{plotas}->GetSelection) ? 'k' : 'e';
  $data->po->chie(1) if ($space eq 'k');
  $data->plot($space);
  $this->{remove}->Enable(0);

  $data->po->datastyle($save);
};


sub OnPlotas {
  my ($this, $event, $app) = @_;
  my $data = $app->current_data;
  $this->plot($data);
};


sub OnChoose {
  my ($this, $event, $app) = @_;
  my $data    = $app->current_data;
  $this->plot($data);
  my ($ok, $xx, $yy) = $app->cursor;
  return if not $ok;
  #my $plucked = $data->bkg_e0 + $self->bkg_eshift + $x;

  my ($dist, $ii) = (1e10, -1);
  my @x = $data->get_array('energy');
  my $which = ($this->{plotas}->GetSelection) ? 'chie' : 'xmu';
  my @y = $data->get_array($which);
  my ($miny, $maxy) = minmax(@y);
  foreach my $i (0 .. $#x) {	# need to scale these appropriately
    my $px = ($x[$i] - $xx)/($x[-1] - $x[0]);
    my $py = ($y[$i] - $yy)/($maxy - $miny);
    my $d  = sqrt($px**2 + $py**2);
    ($d < $dist) and ($dist, $ii) = ($d, $i);
  };
  $this->plot($data);
  $data->plot_marker('xmu', $x[$ii]);
  $this->{point} = $x[$ii];
  $this->{remove}->Enable(1);
  $app->{main}->status(sprintf("Plucked point at %.3f", $x[$ii]));
};

sub OnRemove {
  my ($this, $event, $app) = @_;
  my $data = $app->current_data;
  $data->deglitch($this->{point});
  $this->plot($data);
  $app->{main}->status(sprintf("Removed point at %.3f", $this->{point}));
};

1;


=head1 NAME

Demeter::UI::Athena::Deglitch - A deglitching tool_ for Athena

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

This module provides a tool for deglitching -- removing spurious
points from mu(E) data.  There are two algorithms.  The first is a
simple selection of data points using the mouse.  The second removes
all points which lie outside of a marging around either the pre-edge
or post-edge line.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
