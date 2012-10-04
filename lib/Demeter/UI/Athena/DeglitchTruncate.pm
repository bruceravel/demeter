package Demeter::UI::Athena::DeglitchTruncate;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);

use File::Basename;
use List::MoreUtils qw(minmax);
use Scalar::Util qw(looks_like_number);

use vars qw($label);
$label = "Deglitch and truncate data";	# used in the Choicebox and in status bar messages to identify this tool

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
  $this->{margin} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{margin}, 0, wxALL|wxALIGN_CENTER, 5);

  $this->{emin_label} = Wx::StaticText->new($this, -1, "Emin:");
  $hbox -> Add($this->{emin_label}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{emin} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{emin}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{emin_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox -> Add($this->{emin_pluck}, 0, wxALL|wxALIGN_CENTER, 5);

  $this->{emax_label} = Wx::StaticText->new($this, -1, "Emax:");
  $hbox -> Add($this->{emax_label}, 0, wxALL|wxALIGN_CENTER, 5);
  $this->{emax} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
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


  my $truncatebox       = Wx::StaticBox->new($this, -1, 'Truncate data', wxDefaultPosition, wxDefaultSize);
  my $truncateboxsizer  = Wx::StaticBoxSizer->new( $truncatebox, wxVERTICAL );
  $box                 -> Add($truncateboxsizer, 0, wxGROW|wxALL, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $truncateboxsizer -> Add($hbox, 0, wxALL|wxALIGN_CENTER, 0);

  $this->{beforeafter} = Wx::RadioBox->new($this, -1, q{Drop points}, wxDefaultPosition, wxDefaultSize,
					   ["before", "after"], 1, wxRA_SPECIFY_ROWS);
  $this->{etrun} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{beforeafter}, 0, wxALL|wxALIGN_CENTER, 5);
  $hbox -> Add($this->{etrun},       0, wxALL|wxALIGN_CENTER, 5);
  EVT_TEXT_ENTER($this, $this->{etrun}, sub{$this->plot_truncate($app->current_data)});
  $this->{etrun_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox -> Add($this->{etrun_pluck}, 0, wxALL|wxALIGN_CENTER, 5);
  EVT_BUTTON($this, $this->{etrun_pluck}, sub{OnPluckTruncate(@_, $app)});
  $this->{etrun} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $truncateboxsizer -> Add($hbox, 0, wxGROW|wxALL, 0);
  $this->{replot_truncate}   = Wx::Button->new($this, -1, 'Replot');
  $this->{truncate}          = Wx::Button->new($this, -1, 'Truncate data');
  $this->{truncate_marked}   = Wx::Button->new($this, -1, 'Truncate all marked groups');
  $hbox -> Add($this->{replot_truncate}, 1, wxALL, 5);
  $hbox -> Add($this->{truncate},        1, wxALL, 5);
  $hbox -> Add($this->{truncate_marked}, 1, wxALL, 5);
  EVT_BUTTON($this, $this->{replot_truncate}, sub{$this->plot_truncate($app->current_data)});
  EVT_BUTTON($this, $this->{truncate},        sub{Truncate(@_, $app, 'current')});
  EVT_BUTTON($this, $this->{truncate_marked}, sub{Truncate(@_, $app, 'marked' )});

  $this->{indicator} = Demeter::Plot::Indicator->new(space=>'E');

  $this->{beforeafter}->SetSelection(1);

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: deglitching and truncating');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("deglitch")});

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
  if ($data->datatype eq 'chi') {
    $this->Enable(0);
    return;
  };

  $data->_update('background');
  $this->{margin}->SetValue(0.1 * $data->bkg_step);
  $this->{emin}->SetValue($data->bkg_nor1);
  $this->{emax}->SetValue($data->bkg_nor2);

  my @y = $data->get_array('energy');
  $this->{etrun}->SetValue($y[-1]);

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

  $data->standard;
  $::app->{main}->{Indicators}->plot;
  $data->unset_standard;

  $this->{remove}->Enable(0);
  $::app->{main}->status(sprintf("Plotted %s as points for deglitching", $data->name));
  $::app->heap_check(0);

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
  local $|=1;

  my ($dist, $ii) = (1e10, -1);
  my $which = ($this->{plotas}->GetSelection) ? 'chi' : 'xmu';
  my @x = ($which eq 'chi') ? $data->get_array('k') : $data->get_array('energy');
  $xx = $data->e2k($xx, "absolute") if ($which eq 'chi');
  my @y = $data->get_array($which);
  my ($miny, $maxy) = minmax(@y);
  foreach my $i (0 .. $#x) {	# need to scale these appropriately
    my $px  = ($x[$i] - $xx)/($x[-1] - $x[0]);
    my $ppy = ($which eq 'chi') ? $y[$i]*$xx**$data->get_kweight : $y[$i];
    my $py  = ($ppy - $yy)/($maxy - $miny);
    my $d   = sqrt($px**2 + $py**2);
    ($d < $dist) and ($dist, $ii) = ($d, $i);
  };
  $this->plot($data);
  my $request = ($which eq 'chi') ? 'chie' : 'xmu';
  $data->plot_marker($request, $x[$ii]);
  $this->{point} = ($which eq 'chi') ? $data->k2e($x[$ii], 'absolute') : $x[$ii];
  $this->{remove}->Enable(1);
  $app->{main}->status(sprintf("Plucked point at %.3f from %s", $this->{point}, $data->name));
};

sub OnRemove {
  my ($this, $event, $app) = @_;
  my $data = $app->current_data;
  $data->deglitch($this->{point});
  $this->plot($data);
  $app->{main}->status(sprintf("Removed point at %.3f from %s", $this->{point}, $data->name));
  $::app->modified(1);
};


sub plot_truncate {
  my ($this, $data) = @_;

  $::app->{main}->{PlotE}->pull_single_values;
  $data->po->set(e_mu=>1, e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  $data->po->start_plot;

  $data->plot('e');
  my $e = $this->{etrun}->GetValue - $data->bkg_e0;
  if (not looks_like_number($e)) {
    $::app->{main}->status("Not plotting for truncation -- your value for the cutoff energy is not a number!", 'error|nobuffer');
    return;
  };
  $this->{indicator}->x($e);
  $data->standard;
  $this->{indicator}->plot('e');
  $data->unset_standard;
  $::app->heap_check(0);
};

sub OnPluckTruncate {
  my ($this, $event, $app) = @_;
  my $data    = $app->current_data;
  $this->plot_truncate($data);
  my ($ok, $xx, $yy) = $app->cursor;
  return if not $ok;
  $this->{etrun}->SetValue($xx);
  $this->plot_truncate($data);
  $app->{main}->status(sprintf("Set indicator at %.3f", $xx));
};

sub Truncate {
  my ($this, $event, $app, $how) = @_;
  my @data = ($how eq 'marked') ? $app->marked_groups : ($app->current_data);
  my $beforeafter = ($this->{beforeafter}->GetSelection) ? 'after' : 'before' ;
  my $text = ($how eq 'marked') ? 'all marked groups' : 'current group' ;
  my $e = $this->{etrun}->GetValue;
  if (not looks_like_number($e)) {
    $::app->{main}->status("Not truncating -- your value for the cutoff energy is not a number!", 'error|nobuffer');
    return;
  };
  foreach my $d (@data) {
    $d->Truncate($beforeafter, $e);
    $app->{main}->status("Truncating ".$d->name, 'nobuffer');
  };
  $app->{main}->status(sprintf("Removed data %s %.3f for %s", $beforeafter, $e, $text));
  $this->plot_truncate($data[0]);
  $::app->modified(1);
};

1;


=head1 NAME

Demeter::UI::Athena::Deglitch - A deglitching tool_ for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.13.

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

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
