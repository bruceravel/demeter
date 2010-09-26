package Demeter::UI::Athena::Rebin;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHOICE);

use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Rebin data";

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $demeter = $Demeter::UI::Athena::demeter;

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{rebinned} = q{};;

  my $gbs = Wx::GridBagSizer->new( 3, 3 );

  my $label = Wx::StaticText->new($this, -1, 'Rebinning');
  $gbs->Add($label, Wx::GBPosition->new(0,0));

  $label = Wx::StaticText->new($this, -1, 'Edge energy');
  $gbs->Add($label, Wx::GBPosition->new(1,0));

  $label = Wx::StaticText->new($this, -1, 'Edge region');
  $gbs->Add($label, Wx::GBPosition->new(2,0));

  $label = Wx::StaticText->new($this, -1, 'Pre-edge grid');
  $gbs->Add($label, Wx::GBPosition->new(3,0));

  $label = Wx::StaticText->new($this, -1, 'XANES grid');
  $gbs->Add($label, Wx::GBPosition->new(4,0));

  $label = Wx::StaticText->new($this, -1, 'EXAFS grid');
  $gbs->Add($label, Wx::GBPosition->new(5,0));



  $label = Wx::StaticText->new($this, -1, ',');
  $gbs->Add($label, Wx::GBPosition->new(2,3));

  $label = Wx::StaticText->new($this, -1, 'eV');
  $gbs->Add($label, Wx::GBPosition->new(2,5));

  $label = Wx::StaticText->new($this, -1, 'eV');
  $gbs->Add($label, Wx::GBPosition->new(3,3), Wx::GBSpan->new(1,2));

  $label = Wx::StaticText->new($this, -1, 'eV');
  $gbs->Add($label, Wx::GBPosition->new(4,3), Wx::GBSpan->new(1,2));

  $label = Wx::StaticText->new($this, -1, "$ARING$MACRON$ONE");
  $gbs->Add($label, Wx::GBPosition->new(5,3), Wx::GBSpan->new(1,2));

  $this->{abs}   = Wx::StaticText->new($this, -1, q{}, wxDefaultPosition, [60,-1]);
  $this->{edge}   = Wx::StaticText->new($this, -1, q{}, wxDefaultPosition, [60,-1]);
  foreach my $w (qw(emin emax pre xanes exafs)) {
    $this->{$w}  = Wx::TextCtrl->new($this, -1, $demeter->co->default('rebin', $w), wxDefaultPosition, [120,-1]);
  };
  $gbs->Add($this->{abs},   Wx::GBPosition->new(0,2), Wx::GBSpan->new(1,3));
  $gbs->Add($this->{edge},  Wx::GBPosition->new(1,2));
  $gbs->Add($this->{emin},  Wx::GBPosition->new(2,2));
  $gbs->Add($this->{emax},  Wx::GBPosition->new(2,4));
  $gbs->Add($this->{pre},   Wx::GBPosition->new(3,2));
  $gbs->Add($this->{xanes}, Wx::GBPosition->new(4,2));
  $gbs->Add($this->{exafs}, Wx::GBPosition->new(5,2));

  $box->Add($gbs, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  $this->{replot} = Wx::Button->new($this, -1, 'Plot data and rebinned data',       wxDefaultPosition, $tcsize);
  $this->{make}   = Wx::Button->new($this, -1, 'Make rebinned data group',          wxDefaultPosition, $tcsize);
  $this->{marked} = Wx::Button->new($this, -1, 'Rebin marked data and make groups', wxDefaultPosition, $tcsize);
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 5) foreach (qw(replot make marked));

  EVT_BUTTON($this, $this->{replot}, sub{$this->plot($app->current_data)});
  EVT_BUTTON($this, $this->{make},   sub{$this->make($app)});
  EVT_BUTTON($this, $this->{marked}, sub{$this->make_marked($app)});

  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  1;
};
sub push_values {
  my ($this, $data) = @_;
  $this->Enable(1);
  $this->{abs}  -> SetLabel($data->name);
  $this->{edge} -> SetLabel($data->bkg_e0);
  delete $this->{rebinned};
  foreach my $w (qw(emin emax pre xanes exafs)) {
    my $key = 'rebin_'.$w;
    my $value = $this->{$w}->GetValue;
    $data->co->set_default('rebin', $w, $value);
  };
  delete $this->{rebinned};
  if ($data->rebinned) {
    $this->Enable(0);
  } elsif ($data->datatype eq 'chi') {
  } else {
    $this->{rebinned} = $data->rebin;
    $this->plot($data);
  };
};
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub plot {
  my ($this, $data) = @_;
  $::app->{main}->{PlotE}->pull_single_values;
  $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  $data->po->start_plot;
  $_->plot('e') foreach ($data, $this->{rebinned});
};

sub make {
  my ($this, $app) = @_;

  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->Append($this->{rebinned}->name, $this->{rebinned});
  } else {
    $app->{main}->{list}->Insert($this->{rebinned}->name, $index+1, $this->{rebinned});
  };
  $app->{main}->status("Rebinned " . $app->current_data->name);
  $app->modified(1);
};
sub marked {
  my ($this, $app) = @_;
  my $busy = Wx::BusyCursor->new();
  my $count = 0;
  foreach my $j (reverse (0 .. $app->{main}->{list}->GetCount-1)) {
    if ($app->{main}->{list}->IsChecked($j)) {
      if ($index == $app->{main}->{list}->GetCount-1) {
	$app->{main}->{list}->Append($this->{rebinned}->name, $this->{rebinned});
      } else {
	$app->{main}->{list}->Insert($this->{rebinned}->name, $index+1, $this->{rebinned});
      };
      ++$count;
    };
  };
  undef $busy;
  return if not $count;
  $app->modified(1);
  $app->{main}->status("Made rebinned groups from $count marked groups.");
};
1;


=head1 NAME

Demeter::UI::Athena::Rebin - A rebinning for continuous scan data for Athena

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

This module provides a tool for rebinning continuous scan data onto a
standard EXAFS energy grid.

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
