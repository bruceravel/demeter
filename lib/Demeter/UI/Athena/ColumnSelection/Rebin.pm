package Demeter::UI::Athena::ColumnSelection::Rebin;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::UI::Athena::Replot;

sub new {
  my ($class, $parent, $data) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  $this->{do_rebin} = Wx::CheckBox->new($this, -1, "Perform rebinning");
  $box -> Add($this->{do_rebin}, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 10);
  $this->{controls} = [];
  EVT_CHECKBOX($this, $this->{do_rebin}, sub{EnableRebin(@_, $this)});

  my $gbs = Wx::GridBagSizer->new( 3, 3 );

  #my $label = Wx::StaticText->new($this, -1, 'Absorber');
  #$gbs->Add($label, Wx::GBPosition->new(0,0));
  #push @{$this->{controls}}, $label;

  my $label = Wx::StaticText->new($this, -1, 'Edge region');
  $gbs->Add($label, Wx::GBPosition->new(0,0));
  push @{$this->{controls}}, $label;

  $label = Wx::StaticText->new($this, -1, 'Pre-edge grid');
  $gbs->Add($label, Wx::GBPosition->new(1,0));
  push @{$this->{controls}}, $label;

  $label = Wx::StaticText->new($this, -1, 'XANES grid');
  $gbs->Add($label, Wx::GBPosition->new(2,0));
  push @{$this->{controls}}, $label;

  $label = Wx::StaticText->new($this, -1, 'EXAFS grid');
  $gbs->Add($label, Wx::GBPosition->new(3,0));
  push @{$this->{controls}}, $label;



  $label = Wx::StaticText->new($this, -1, 'to');
  $gbs->Add($label, Wx::GBPosition->new(0,3));
  push @{$this->{controls}}, $label;

  $label = Wx::StaticText->new($this, -1, 'eV');
  $gbs->Add($label, Wx::GBPosition->new(0,5));
  push @{$this->{controls}}, $label;

  $label = Wx::StaticText->new($this, -1, 'eV');
  $gbs->Add($label, Wx::GBPosition->new(1,3), Wx::GBSpan->new(1,2));
  push @{$this->{controls}}, $label;

  $label = Wx::StaticText->new($this, -1, 'eV');
  $gbs->Add($label, Wx::GBPosition->new(2,3), Wx::GBSpan->new(1,2));
  push @{$this->{controls}}, $label;

  $label = Wx::StaticText->new($this, -1, "$ARING$MACRON$ONE");
  $gbs->Add($label, Wx::GBPosition->new(3,3), Wx::GBSpan->new(1,2));
  push @{$this->{controls}}, $label;

  #$this->{abs}   = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [60,-1]);
  foreach my $w (qw(emin emax pre xanes exafs)) {
    $this->{$w}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [60,-1]);
    $this->{$w} -> Enable(1);
    $this->{$w} -> SetValue($data->co->default('rebin', $w)||$data->co->demeter('rebin', $w));
    push @{$this->{controls}}, $this->{$w};
  };
  #$gbs->Add($this->{abs},   Wx::GBPosition->new(0,2));
  $gbs->Add($this->{emin},  Wx::GBPosition->new(0,2));
  $gbs->Add($this->{emax},  Wx::GBPosition->new(0,4));
  $gbs->Add($this->{pre},   Wx::GBPosition->new(1,2));
  $gbs->Add($this->{xanes}, Wx::GBPosition->new(2,2));
  $gbs->Add($this->{exafs}, Wx::GBPosition->new(3,2));

  $box->Add($gbs, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  EnableRebin($this, 0);

  $this->SetSizerAndFit($box);
  return $this;

};


sub EnableRebin {
  my ($this, $event) = @_;
  my $onoff = $this->{do_rebin}->GetValue;
  $_->Enable($onoff) foreach @{$this->{controls}};
};

1;

=head1 NAME

Demeter::UI::Athena::ColumnSelection::Preprocess - column selection rebinning controls

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This module provides controls for handling rebinning in Athena's
column selection dialog

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
