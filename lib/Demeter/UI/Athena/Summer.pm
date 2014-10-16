package Demeter::UI::Athena::Summer;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX);

use Demeter::UI::Wx::SpecialCharacters qw($MU $CHI);
use Wx::Perl::TextValidator;

use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(pairwise);

use vars qw($label);
$label = "Sum arbitrary combinations of data";

my $tcsize = [90,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $this->{lcf} = Demeter::LCF->new(unity=>0, inclusive=>0, one_e0=>0,
				   plot_difference=>0, plot_components=>0, noise=>0);
  $this->{sum}  = q{};
  $this->{components}  = [];
  $this->{weights}     = [];
  $this->{n}    = 0;
  $this->{nmax} = 8;

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer} = $box;

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $box -> Add($hbox, 0, wxGROW|wxALL, 5);

  $this->{space} = Wx::RadioBox->new($this, -1, 'Space', wxDefaultPosition, wxDefaultSize,
					 ["$MU(E)", "normalized $MU(E)", "$CHI(k)"],
					 1, wxRA_SPECIFY_ROWS);
  $this->{space}->SetSelection(1);
  #$this->{space}->Enable(2,0);
  EVT_RADIOBOX($this, $this->{space}, \&OnRadioBox);
  $hbox         -> Add($this->{space}, 0, wxALL, 3);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox         -> Add($vbox, 0, wxGROW|wxALL, 3);

  $this->{plotdata} = Wx::CheckBox->new($this, -1, "Include components in plot");
  $vbox         -> Add($this->{plotdata}, 0, wxGROW|wxALL, 3);
  $this->{plotmarked} = Wx::CheckBox->new($this, -1, "Include marked groups in plot");
  $vbox         -> Add($this->{plotmarked}, 0, wxGROW|wxLEFT|wxRIGHT, 3);

  my $stanbox       = Wx::StaticBox->new($this, -1, 'Components', wxDefaultPosition, wxDefaultSize);
  my $stanboxsizer  = Wx::StaticBoxSizer->new( $stanbox, wxVERTICAL );
  $box             -> Add($stanboxsizer, 0, wxGROW|wxALL, 3);
  $this->{stanbox}  = $stanbox;
  $this->{stanboxsizer}  = $stanboxsizer;
  foreach my $i (1..$this->{nmax}) {
    $this->add_choice;
  };

  $this->{plot}     = Wx::Button->new($this, -1, 'Plot sum');
  $this->{plotchir} = Wx::Button->new($this, -1, "Plot sum as $CHI(R)");
  $this->{make}     = Wx::Button->new($this, -1, 'Make data group from sum');
  #$this->{add}      = Wx::Button->new($this, -1, 'Add another group');
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 3) foreach qw(plot plotchir make); # add);
  EVT_BUTTON($this, $this->{plot},     sub{$this->plot});
  EVT_BUTTON($this, $this->{plotchir}, sub{$this->plot('R')});
  EVT_BUTTON($this, $this->{make},     sub{$this->make});
  $this->{plotchir}->Enable(0);

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: Summer');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.sum")});

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
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnRadioBox {
  my ($this, $event) = @_;
  if ($this->{space}->GetSelection == 2) {
    $this->{plotchir}->Enable(1);
  } else {
    $this->{plotchir}->Enable(0);
  };
};

sub add_choice {
  my ($this) = @_;
  ++$this->{n};

  my $box = Wx::BoxSizer->new( wxHORIZONTAL);
  $this->{stanboxsizer}->Add($box, 1, wxGROW|wxALL, 3);

  $box->Add(Wx::StaticText->new($this, -1, $this->{n}), 0, wxGROW|wxALL, 3);
  my $key = "standard".$this->{n};
  $this->{$key} = Demeter::UI::Athena::GroupList -> new($this, $::app, 1);
  $box->Add($this->{$key}, 1, wxGROW|wxALL, 0);
  $box->Add(Wx::StaticText->new($this, -1, "weight:"), 0, wxGROW|wxALL, 3);
  $key = "weight".$this->{n};
  $this->{$key} = Wx::TextCtrl->new($this, -1, 1, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $box->Add($this->{$key}, 0, wxALL, 0);
  $this->{$key} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );

  $this->SetSizerAndFit($this->{sizer});
  $this->Update;
};


sub sum {
  my ($this) = @_;

  $this->{sum}        = q{};
  $this->{components} = [];
  $this->{weights}    = [];

  my (@data, @weight);
  my $space = (qw(xmu norm chi))[$this->{space}->GetSelection];
  $this->{lcf}->space($space);
  my $datatype = ($space eq 'chi') ? 'chi' : 'xmu';
  foreach my $i (1 .. $this->{nmax}) {
    next if ($this->{"standard$i"}->GetStringSelection eq 'None');
    next if ($this->{"weight$i"}->GetValue == 0);
    next if not looks_like_number($this->{"weight$i"}->GetValue);
    push @data, $this->{"standard$i"}->GetClientData(scalar $this->{"standard$i"}->GetSelection);
    push @weight, $this->{"weight$i"}->GetValue;
  };
  return if ($#data == -1);

  my $save = Demeter->po->kweight;
  Demeter->po->kweight(0);

  $this->{lcf}->data($data[0]);		# the data must be set to provide an
                                # interpolation standard, but no fit
                                # will actually be done
  foreach my $n (0 .. $#data) {
    $this->{lcf}->add($data[$n], weight=>$weight[$n]);
  };
  $this->{lcf}->prep_arrays('set');
  Demeter->po->kweight($save);

  my $x = $this->{lcf}->ref_array('x');
  my $y = $this->{lcf}->ref_array('lcf');
  my $sum = $data[0]->put($x, $y, datatype=>$datatype, name=>'sum');
  $sum->e0($data[0]);
  $sum->set(bkg_z=>$data[0]->bkg_z, fft_edge=>$data[0]->fft_edge);
  $sum->resolve_defaults;
  $this->{sum}        = $sum;
  $this->{components} = \@data;
  $this->{weights}    = \@weight;
  $this->{lcf}->clear;
  $this->{lcf}->clean;
};

sub plot {
  my ($this, $how) = @_;
  $how ||= q{};
  my $busy = Wx::BusyCursor->new();
  $this->sum;
  if (not $this->{sum}) {
    $::app->{main}->status("Cannot sum and plot -- no components have been defined.", 'alert');
    undef $busy;
    return;
  };
  my $plotspace = 'E';
  if ($this->{space}->GetSelection == 2) {
    $::app->{main}->{PlotK}->pull_single_values;
    $::app->{main}->{PlotR}->pull_marked_values if (lc($how) eq 'r');
    $plotspace = (lc($how) eq 'r') ? 'R' : 'k';
  } else {
    $::app->{main}->{PlotE}->pull_single_values;
    Demeter->po->set(e_mu=>1, e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0,
		     e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0, e_smooth=>0);
    Demeter->po->e_norm(1) if ($this->{space}->GetSelection == 1);
  };
  Demeter->po->start_plot;

  my $message = 'summation';
  ## plot the summation
  $this->{sum}->plot($plotspace);

  ## plot the components
  if ($this->{plotdata}->GetValue) {
    my $ii = 0;
    foreach my $c (@{$this->{components}}) {
      my $save = $c->plot_multiplier;
      $c->plot_multiplier($this->{weights}->[$ii]);
      $c->plot($plotspace);
      $c->plot_multiplier($save);
      ++$ii;
    };
    $message .= ', components';
  };

  ## plot the marked groups
  if ($this->{plotmarked}->GetValue) {
    my $clb = $::app->{main}->{list};
    my $count = 0;
    foreach my $i (0 .. $clb->GetCount-1) {
      next if not $clb->IsChecked($i);
      $clb->GetIndexedData($i)->plot($plotspace);
      ++$count;
    };
    $message .= ($count == 1) ? ', marked group' : ', marked groups';
  };

  $::app->{main}->status("Plotted " . $message);
  undef $busy;
};


sub make {
  my ($this) = @_;
  my $busy = Wx::BusyCursor->new();
  $this->sum;
  if (not $this->{sum}) {
    $::app->{main}->status("Cannot make summed data group -- no components have been defined.", 'alert');
    undef $busy;
    return;
  };
  my $string = join(", ", pairwise {sprintf("%s (%s)", $a->name, $b)} @{$this->{components}}, @{$this->{weights}});
  $this->{sum} -> source("Sumation of ".$string);
  my $index = $::app->current_index;
  if ($index == $::app->{main}->{list}->GetCount-1) {
    $::app->{main}->{list}->AddData($this->{sum}->name, $this->{sum});
  } else {
    $::app->{main}->{list}->InsertData($this->{sum}->name, $index+1, $this->{sum});
  };
  $::app->{main}->status("Made data group from summation of $string");
  $::app->modified(1);
  $::app->heap_check(0);
  undef $busy;
};
1;


=head1 NAME

Demeter::UI::Athena::Summer - A data summer for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module provides a simple tool for summing a list of data groups
with arbitrary weights.  This is a little like the LCF tool and little
like the difference spectrum tool, but not quite.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

C<push_values> does not update menus to reflect changes in groups list

=item *

It might be nice to allow the number of data group choice menus
(currently 8) to be configurable.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
