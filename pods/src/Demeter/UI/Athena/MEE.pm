package Demeter::UI::Athena::MEE;
use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_RADIOBOX EVT_TEXT EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use File::Basename;
use File::Spec;
use Scalar::Util qw(looks_like_number);


use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Multi-electron excitation removal";

my $tcsize   = [60,-1];
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  $this->{mee}    = q{};
  $this->{update} = 1;

  ## algorithm choice
  $this->{algorithm} = Wx::RadioBox->new($this, -1, 'Algorithm', wxDefaultPosition, wxDefaultSize,
					 ['Reflection', 'Arctangent']);
  $box->Add($this->{algorithm}, 0, wxGROW|wxALL, 5);
  EVT_RADIOBOX($this, $this->{algorithm}, sub{$this->{update} = 1});

  ## parameters
  my $gbs = Wx::GridBagSizer->new( 5, 5 );
  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 10);

  $gbs->Add(Wx::StaticText->new($this, -1, "Energy shift"), Wx::GBPosition->new(0,0));
  $gbs->Add(Wx::StaticText->new($this, -1, "eV"),           Wx::GBPosition->new(0,2));
  $gbs->Add(Wx::StaticText->new($this, -1, "Scale by"),     Wx::GBPosition->new(1,0));
  $gbs->Add(Wx::StaticText->new($this, -1, "Broadening"),   Wx::GBPosition->new(2,0));
  $gbs->Add(Wx::StaticText->new($this, -1, "eV"),           Wx::GBPosition->new(2,2));

  $this->{shift}       = Wx::TextCtrl->new($this, -1, '0');
  $this->{shift_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{amp}         = Wx::TextCtrl->new($this, -1, '0.01');
  $this->{width}       = Wx::TextCtrl->new($this, -1, '0.5');
  $gbs->Add($this->{shift},       Wx::GBPosition->new(0,1));
  $gbs->Add($this->{shift_pluck}, Wx::GBPosition->new(0,3));
  $gbs->Add($this->{amp},         Wx::GBPosition->new(1,1));
  $gbs->Add($this->{width},       Wx::GBPosition->new(2,1));
  EVT_TEXT($this, $this->{shift}, sub{$this->{update} = 1});
  EVT_TEXT($this, $this->{amp},   sub{$this->{update} = 1});
  EVT_TEXT($this, $this->{width}, sub{$this->{update} = 1});
  EVT_BUTTON($this, $this->{shift_pluck}, sub{Pluck(@_, $app)});


  ## plotting
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxGROW|wxALL, 0);

  $this->{plote} = Wx::Button->new($this, -1, 'Plot in energy');
  $this->{plotk} = Wx::Button->new($this, -1, 'Plot in k');
  $this->{plotr} = Wx::Button->new($this, -1, 'Plot in R');
  $hbox->Add($this->{plote}, 1, wxGROW|wxALL, 5);
  $hbox->Add($this->{plotk}, 1, wxGROW|wxALL, 5);
  $hbox->Add($this->{plotr}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{plote}, sub{plot(@_, 'e')});
  EVT_BUTTON($this, $this->{plotk}, sub{plot(@_, 'k')});
  EVT_BUTTON($this, $this->{plotr}, sub{plot(@_, 'r')});

  ## make group
  $this->{make} = Wx::Button->new($this, -1, 'Make group from MEE-corrected data');
  $box->Add($this->{make}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{make}, sub{make(@_)});



  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: MEE');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("process.mee")});

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
  $this->{update} = 1;
  return if $::app->{plotting};
  $this->quickplot;
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};


sub Pluck {
  my ($frame, $event, $app) = @_;
  my $space = $app->{lastplot}->[0];
  if ($space !~ m{\A[ekq]\z}i) {
    $app->{main}->status("cannot pluck from a $space space plot in the MEE tool", 'alert');
    return;
  };
  $frame->quickplot($space);
  my ($return, $x, $y) = $app->cursor;
  if (not $return->status) {
    $app->{main}->status($return->message, 'alert');
    return;
  };
  $x = $app->current_data->k2e($x, 'absolute') if (lc($space) ne 'e');
  my $e = sprintf("%.3f", $x-$::app->current_data->bkg_e0);
  $frame->{shift}->SetValue($e);
  $app->{main}->status("Plucked $e for energy shift");
};

sub quickplot {
  my ($this, $space) = @_;
  $space ||= 'E';
  Demeter->po->start_plot;
  $::app->{main}->{'Plot'.uc($space)}->pull_single_values;
  Demeter->po->set(e_mu=>1, e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  $::app->current_data->plot($space);
  $::app->{lastplot} = [$space, 'single'];
  if ($this->{shift}->GetValue > 10) {
    $::app->current_data->standard;
    my $indic  = Demeter::Plot::Indicator->new(space=>'E', x=>$this->{shift}->GetValue,);
    $indic->plot;
    undef $indic;
    $::app->current_data->unset_standard;
  };
  return 1;
};

sub plot {
  my ($this, $event, $space) = @_;
  my $data = $::app->current_data;
  foreach my $p (qw(shift amp width)) {
    if (not looks_like_number($this->{$p}->GetValue)) {
      $::app->{main}->status("Not plotting -- the value for $p is not a number", 'error|nobuffer');
      return;
    };
  };
  $this->quickplot($space), return if ($this->{shift}->GetValue <= 0);
  if ($this->{update}) {
    $this->{mee} = $data->mee(shift => $this->{shift}->GetValue,
			      amp   => $this->{amp}  ->GetValue,
			      width => $this->{width}->GetValue,
			      how   => $this->{algorithm}->GetStringSelection);
  };
  Demeter->po->start_plot;
  $::app->{main}->{'Plot'.uc($space)}->pull_marked_values;
  $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1,
		 e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0, e_smooth=>0, chie=>0);
  $data->plot($space);
  $this->{mee}->plot($space);
  $::app->{lastplot} = [$space, 'single'];
  if ($this->{shift}->GetValue > 10) {
    $::app->current_data->standard;
    my $indic  = Demeter::Plot::Indicator->new(space=>'E', x=>$this->{shift}->GetValue,);
    $indic->plot;
    undef $indic;
    $::app->current_data->unset_standard;
  };
  $this->{update} = 0;
};

sub make {
  my ($this, $event) = @_;
  my $index = $::app->current_index;
  if ($index == $::app->{main}->{list}->GetCount-1) {
    $::app->{main}->{list}->AddData($this->{mee}->name, $this->{mee});
  } else {
    $::app->{main}->{list}->InsertData($this->{mee}->name, $index+1, $this->{mee});
  };
  $::app->{main}->status("Made group from " . $::app->current_data->name . " with multi-electron excitation removed");
  $::app->modified(1);
  $::app->heap_check(0);
};


1;


=head1 NAME

Demeter::UI::Athena::MEE - A multi-electron excitation removal tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This module provides a tool for interactively removing a multielectron
excitation from XAS data.  The MEE is modeled as either a reflection
of the XAS data or as an arctangent and subtracted from the data.  The
user can set the energy shift, amplitude, and broadening parameters,
then plot the resulting data in energy, k, or R.  A data group can be
made from the subtracted data and placed in the group list.

=head1 CONFIGURATION

There are currently no configuration parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
