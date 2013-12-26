package Demeter::UI::Athena::Plot::Indicators;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON EVT_BUTTON EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::UI::Athena::Replot;

use File::Basename;

use vars qw($nind);
$nind = 4;

my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $outerbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $indbox    = Wx::StaticBox->new($this, -1, ' Indicators ', wxDefaultPosition, wxDefaultSize);
  my $indboxsizer  = Wx::StaticBoxSizer->new( $indbox, wxVERTICAL );
  $outerbox    -> Add($indboxsizer, 0, wxGROW|wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 5 );
  foreach my $j (1..$nind) {
    $this->{'check'.$j} = Wx::CheckBox->new($this, -1, $j, wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT);
    $this->{'space'.$j} = Wx::Choice->new($this, -1, wxDefaultPosition, [50, -1], ['E', 'k', 'R', 'q']);
    $this->{'text'.$j}  = Wx::StaticText->new($this, -1, ' at ');
    $this->{'value'.$j} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [45, -1], wxTE_PROCESS_ENTER);
    $this->{'grab'.$j}  = Wx::BitmapButton -> new($this, -1, $bullseye);
    $this->{'group'.$j} = q{};
    $this->{'check'.$j} -> SetValue(1);

    $gbs -> Add($this->{'check'.$j}, Wx::GBPosition->new($j-1,0));
    $gbs -> Add($this->{'space'.$j}, Wx::GBPosition->new($j-1,1));
    $gbs -> Add($this->{'text'.$j},  Wx::GBPosition->new($j-1,2));
    $gbs -> Add($this->{'value'.$j}, Wx::GBPosition->new($j-1,3));
    $gbs -> Add($this->{'grab'.$j},  Wx::GBPosition->new($j-1,4));

    $app->mouseover($this->{'check'.$j}, "Toggle indicator #$j on and off.");
    $app->mouseover($this->{'space'.$j}, "Select the plot space for indicator #$j.");
    $app->mouseover($this->{'value'.$j}, "Specify the x-axis coordinate where indicator #$j is to be plotted.");
    $app->mouseover($this->{'grab'.$j},  "Grab the value for indicator #$j from the plot using the mouse.");

    EVT_TEXT_ENTER($this, $this->{'value'.$j}, sub{1});
    EVT_BUTTON($this, $this->{'grab'.$j}, sub{Pluck(@_, $app, $j)});
  };
  $indboxsizer -> Add($gbs, 0, wxALL, 0);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{all} = Wx::Button->new($this, -1, 'Plot all');
  $hbox -> Add($this->{all}, 1, wxALL|wxGROW, 2);
  $this->{none} = Wx::Button->new($this, -1, 'Plot none');
  $hbox -> Add($this->{none}, 1, wxALL|wxGROW, 2);
  $outerbox -> Add($hbox, 0, wxALL|wxGROW, 0);

  EVT_BUTTON($this, $this->{all},  sub{$this->{'check'.$_}->SetValue(1) foreach (1..$nind)});
  EVT_BUTTON($this, $this->{none}, sub{$this->{'check'.$_}->SetValue(0) foreach (1..$nind)});

  $app->mouseover($this->{all},  "Toggle all indicators ON.");
  $app->mouseover($this->{none}, "Toggle all indicators OFF.");


  $this -> SetSizer($outerbox);
  return $this;
};

sub label {
  return 'Indicators';
};

sub fetch {
  my ($self) = @_;
  foreach my $j (1..$nind) {
    my $indic = $self->{'group'.$j} || Demeter::Plot::Indicator->new;
    $self->{'group'.$j} = $indic;
    $indic->space ($self->{'space'.$j}->GetStringSelection || $indic->po->space);
    $indic->x     ($self->{'value'.$j}->GetValue || 0);
    $indic->active($self->{'check'.$j}->GetValue);
    $indic->active(0) if ($self->{'value'.$j}->GetValue =~ m{\A\s*\z});
  };
  return $self;
};

sub plot {
  my ($self) = @_;
  $self->fetch;
  #local $|=1;
  foreach my $j (1..$nind) {
    #print $self->{'group'.$j}->report, $/;
    $self->{'group'.$j}->plot;
  };
};

sub Pluck {
  my ($this, $event, $app, $j) = @_;

  my $on_screen = lc($app->{lastplot}->[0]);
  if (not $on_screen) {
    $app->{main}->status("Cannot pluck, you haven't made a plot yet.");
    return;
  };
  if ($on_screen eq 'quad') {
    $app->{main}->status("Cannot pluck from a quad plot.");
    return;
  };

  my $busy = Wx::BusyCursor->new();
  my ($ok, $x, $y) = $app->cursor;
  return if not $ok;
  my $plucked = $x;
  $plucked -= $app->current_data->bkg_e0 if (lc($on_screen) eq 'e');
  $plucked = sprintf("%.3f", $plucked);

  ($on_screen = uc($on_screen)) if ($on_screen =~ m{\A[er]\z});
  $this->{'space'.$j}->SetStringSelection($on_screen);
  $this->{'value'.$j}->SetValue($plucked);

  $app->{main}->status("Plucked $plucked for an indicator in $on_screen");
  undef $busy;
};

1;

=head1 NAME

Demeter::UI::Athena::Plot::Indicators - plot indicator controls

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

This module provides controls for plotting indicators in Athena

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
