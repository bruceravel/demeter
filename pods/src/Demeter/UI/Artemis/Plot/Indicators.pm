package  Demeter::UI::Artemis::Plot::Indicators;


=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Wx qw( :everything );
use base qw(Wx::Panel);
use Wx::Event qw(EVT_BUTTON EVT_CHECKBOX EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);

use File::Basename;
use File::Spec;

use vars qw($nind);
$nind = 5;
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Artemis.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize);

  my $outerbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $indbox    = Wx::StaticBox->new($this, -1, ' Indicators ', wxDefaultPosition, wxDefaultSize);
  $indboxsizer  = Wx::StaticBoxSizer->new( $indbox, wxVERTICAL );
  $outerbox    -> Add($indboxsizer, 0, wxGROW|wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 5 );
  foreach my $j (1..$nind) {
    $this->{'check'.$j} = Wx::CheckBox->new($this, -1, $j, wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT);
    $this->{'space'.$j} = Wx::Choice->new($this, -1, wxDefaultPosition, [50, -1], ['k', 'R', 'q']);
    $this->{'text'.$j}  = Wx::StaticText->new($this, -1, ' at ');
    $this->{'value'.$j} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [45, -1]);
    $this->{'grab'.$j}  = Wx::BitmapButton -> new($this, -1, $bullseye);
    $this->{'group'.$j} = q{};
    $this->{'check'.$j} -> SetValue(1);

    $gbs -> Add($this->{'check'.$j}, Wx::GBPosition->new($j-1,0));
    $gbs -> Add($this->{'space'.$j}, Wx::GBPosition->new($j-1,1));
    $gbs -> Add($this->{'text'.$j},  Wx::GBPosition->new($j-1,2));
    $gbs -> Add($this->{'value'.$j}, Wx::GBPosition->new($j-1,3));
    $gbs -> Add($this->{'grab'.$j},  Wx::GBPosition->new($j-1,4));

    $this->mouseover("check".$j,  "Toggle indicator #$j on and off.");
    $this->mouseover("space".$j,  "Select the plot space for indicator #$j.");
    $this->mouseover("value".$j,  "Specify the x-axis coordinate where indicator #$j is to be plotted.");
    $this->mouseover("grab".$j,   "Grab the value for indicator #$j from the plot using the mouse.");

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
  foreach my $i (1..$nind) {
    EVT_BUTTON($this, $this->{'grab'.$i}, sub{Pluck(@_, $i)});
  };

  $this->mouseover("all",  "Toggle all indicators ON.");
  $this->mouseover("none", "Toggle all indicators OFF.");


  $this -> SetSizer($outerbox);
  return $this;
};

sub mouseover {
  my ($self, $widget, $text) = @_;
  my $sb = $Demeter::UI::Artemis::frames{main}->{statusbar};
  EVT_ENTER_WINDOW($self->{$widget}, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($self->{$widget}, sub{$sb->PopStatusText if ($sb->GetStatusText eq $text); $_[1]->Skip});
};

sub fetch {
  my ($self) = @_;
  foreach my $j (1..$nind) {
    my $indic = ($self->{'group'.$j}) ? $Demeter::UI::Artemis::demeter->mo->fetch("Indicator", $self->{'group'.$j})
      : Demeter::Plot::Indicator->new;
    $self->{'group'.$j} = $indic->group;
    $indic->space ($self->{'space'.$j}->GetStringSelection || 'k');
    $indic->x     ($self->{'value'.$j}->GetValue || 0);
    $indic->active($self->{'check'.$j}->GetValue);
    $indic->active(0) if ($self->{'value'.$j}->GetValue =~ m{\A\s*\z});
  };
  return $self;
};

sub populate {
  my ($self, @list) = @_;
  foreach my $i (@list) {	# thawing the yaml returns a list of hash references containing attributes and their values
    my $indic = Demeter::Plot::Indicator->new(%$i);
    my $j = $indic->i;
    next if ($j > $nind);
    $self->{'group'.$j} = $indic->group;
    $self->{'space'.$j}->SetStringSelection($indic->space);
    $self->{'value'.$j}->SetValue($indic->x);
    $self->{'check'.$j}->SetValue($indic->active);
    if (($indic->x == 0) and (not $indic->active)) {
      $self->{'value'.$j}->SetValue(q{});
      $self->{'check'.$j}->SetValue(1);
    };
  };
  return $self;
};

sub plot {
  my ($self, $ds) = @_;
  return $self if (not $ds);
  $ds->standard;
  $self->fetch;
  foreach my $j (1..5) {
    my $this = $self->{'group'.$j};
    my $indic = $Demeter::UI::Artemis::demeter->mo->fetch("Indicator", $this);
    $indic->plot;
  };
  $ds->unset_standard;
  return $self;
};


sub Pluck {
  my ($self, $ev, $i) = @_;
  my $on_screen       = $Demeter::UI::Artemis::frames{Plot}->{last};
  if (not $on_screen) {
    $Demeter::UI::Artemis::frames{main}->status("You haven't made a plot yet");
    return;
  };
  if ($on_screen eq 'multiplot') {
    $Demeter::UI::Artemis::frames{main}->status("Cannot pluck a value from a multiplot.");
    return;
  };
  $on_screen          = 'R' if (lc($on_screen) eq 'r');
  my ($ok, $x, $y)    = $::app->cursor($self);
  $self->status("Failed to pluck a value for $which"), return if not $ok;
  my $plucked         = sprintf("%.3f", $x);
  $self->{'value'.$i}->SetValue($plucked);
  $self->{'space'.$i}->SetStringSelection($on_screen);
  my $text            = sprintf("Plucked %s as the value for an indicator in %s.", $plucked, $on_screen);
  $Demeter::UI::Artemis::frames{main}->status($text);
}

1;

=head1 NAME

Demeter::UI::Artemis::Plot::Indicators - plot indicator controls

=head1 VERSION

This documentation refers to Demeter version 0.9.9.

=head1 SYNOPSIS

This module provides controls for plotting indicators in Artemis

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

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
