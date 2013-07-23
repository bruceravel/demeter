package  Demeter::UI::Artemis::Data::BondValence;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;

use Chemistry::Elements qw(get_symbol);
use Demeter::UI::Wx::SpecialCharacters qw($S02);
use List::MoreUtils qw(uniq);
use Scalar::Util qw(looks_like_number);
use Xray::BondValence qw(bvdescribe valences available);

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX EVT_CHOICE);
use Wx::Perl::TextValidator;

sub new {
  my ($class, $parent, @paths) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Compute a bond valence sum",
				Wx::GetMousePosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  ## --- elements and valences
  my $gbs = Wx::GridBagSizer->new( 6, 10 );
  $vbox -> Add($gbs, 0, wxGROW|wxALL, 5);

  my $abs = get_symbol($paths[0]->bvabs);
  $gbs -> Add( Wx::StaticText -> new($this, -1, $abs.' valence:'),  Wx::GBPosition->new(0,0));
  $this->{valence_abs} = Wx::Choice -> new($this, -1, wxDefaultPosition, wxDefaultSize, [valences($abs)]);
  $gbs -> Add( $this->{valence_abs}, Wx::GBPosition->new(0,1));

  my %unique;
  foreach my $p (@paths) {
    ++$unique{$p->bvscat};
  };
  my $i = 0;
  foreach my $s (sort keys %unique) {
    $gbs -> Add( Wx::StaticText -> new($this, -1, get_symbol($s).' valence:'),  Wx::GBPosition->new($i,3));
    my @list = uniq map {(split(/:/, $_))[3]} available($abs, '.', $s); # find possible valences for scatterer
    $this->{"valence_scat$i"} = Wx::Choice -> new($this, -1, wxDefaultPosition, wxDefaultSize, [@list]);
    $gbs -> Add( $this->{"valence_scat$i"}, Wx::GBPosition->new($i,4));
    ++$i;
  };

  ## --- s02 value
  my $hbox = Wx::BoxSizer->new ( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  $hbox -> Add(Wx::StaticText->new($this, -1, $S02.":"), 0, wxGROW|wxALL, 5);
  $this->{s02} = Wx::TextCtrl->new($this, -1, "1");
  $this->{s02} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $hbox -> Add($this->{s02}, 0, wxGROW|wxALL, 5);

  ## --- compute button
  $this->{compute} = Wx::Button->new($this, -1, 'Compute');
  $vbox -> Add($this->{compute}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{compute}, sub{OnCompute(@_, @paths)});

  ## --- result
  $hbox = Wx::BoxSizer->new ( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  $hbox -> Add(Wx::StaticText->new($this, -1, "Bond valence sum:"), 0, wxGROW|wxALL, 5);
  $this->{bvs} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $hbox -> Add($this->{bvs}, 0, wxGROW|wxALL, 5);

  ## --- feedback
  my $fbbox      = Wx::StaticBox->new($this, -1, 'Feedback', wxDefaultPosition, wxDefaultSize);
  my $fbboxsizer = Wx::StaticBoxSizer->new( $fbbox, wxVERTICAL );
  $this->{feedback}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [120, 200], wxTE_MULTILINE|wxTE_READONLY);
  $fbboxsizer   -> Add($this->{feedback},  1, wxGROW|wxALL, 0);
  $vbox         -> Add($fbboxsizer, 1, wxGROW|wxLEFT|wxRIGHT, 5);


  ## --- document button
  $this->{doc} = Wx::Button->new($this, -1, q{Docmentation: BVS}, wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{doc}, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{doc}, sub{$::app->document('bvs')});

  ## --- OK button
  $this->{ok} = Wx::Button->new($this, wxID_OK, q{}, wxDefaultPosition, wxDefaultSize, 0, );
  $vbox -> Add($this->{ok}, 0, wxGROW|wxALL, 5);


  $this -> SetSizerAndFit( $vbox );
  return $this;
};

sub OnCompute {
  my ($this, $event, @paths) = @_;
  my $s02 = $this->{s02}->GetValue;
  return if not looks_like_number($s02);
  my $sum = 0;
  foreach my $p (@paths) {
    $p->valence_abs($this->{valence_abs}->GetStringSelection);
    $p->valence_scat($this->{valence_scat0}->GetStringSelection);
    $sum += $p->bv($s02);
  };
  $this->{bvs}->SetValue(sprintf("%.3f", $sum));

  my %seen;
  my $text = "Bond valence parameters:\n";
  foreach my $p (@paths) {
    next if $seen{$p->bvscat};
    $text .= "\t".bvdescribe($p).$/;
    ++$seen{$p->bvscat};
  };
  $this->{feedback}->SetValue($text);
};

1;
