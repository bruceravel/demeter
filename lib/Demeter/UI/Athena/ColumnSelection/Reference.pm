package Demeter::UI::Athena::ColumnSelection::Reference;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON EVT_BUTTON);
use Wx::Perl::TextValidator;

sub new {
  my ($class, $parent, $data) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $this->{numerator}   ||= 3;
  $this->{denominator} ||= 4;
  $this->{reference}     = q{};

  my $box = Wx::BoxSizer->new( wxVERTICAL );
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 0, wxALL, 0);

  my @cols = split(" ", $data->columns);

  $this->{do_ref} = Wx::CheckBox->new($this, -1, "Import reference channel");
  $hbox -> Add($this->{do_ref}, 0, wxALL, 7);
  $hbox -> Add(1,1,1);
  $this->{controls} = [];
  EVT_CHECKBOX($this, $this->{do_ref}, sub{EnableReference(@_, $data)});

  my $columnbox = Wx::ScrolledWindow->new($this, -1, wxDefaultPosition, [300, -1], wxHSCROLL);
  $columnbox->SetScrollbars(30, 0, 50, 0);
  $box -> Add($columnbox, 0, wxGROW|wxALL, 10);
  push @{$this->{controls}}, $columnbox;

  my $gbs = Wx::GridBagSizer->new( 3, 3 );

  my $label    = Wx::StaticText->new($columnbox, -1, 'Numerator');
  $gbs -> Add($label, Wx::GBPosition->new(1,0));
  push @{$this->{controls}}, $label;
  $label    = Wx::StaticText->new($columnbox, -1, 'Denominator');
  $gbs -> Add($label, Wx::GBPosition->new(2,0));
  push @{$this->{controls}}, $label;


  my $count = 1;
  my @args = (wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  foreach my $c (@cols) {
    my $i = $count;
    $label    = Wx::StaticText->new($columnbox, -1, $c);
    $gbs -> Add($label, Wx::GBPosition->new(0,$count));
    push @{$this->{controls}}, $label;

    $this->{'n'.$i} = Wx::CheckBox->new($columnbox, -1, q{}, @args);
    $gbs -> Add($this->{'n'.$i}, Wx::GBPosition->new(1,$count));
    $this->{'n'.$i} -> SetValue($i==$this->{numerator});
    push @{$this->{controls}}, $this->{'n'.$i};
    EVT_CHECKBOX($parent, $this->{'n'.$i}, sub{OnNumerClick(@_, $this, $i, $#cols)});
    @args = ();
    ++$count;
  };

  $count = 1;
  #@args = (wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  foreach my $c (@cols) {
    my $i = $count;
    $this->{'d'.$i} = Wx::CheckBox->new($columnbox, -1, q{}); #, @args);
    $gbs -> Add($this->{'d'.$i}, Wx::GBPosition->new(2,$count));
    $this->{'d'.$i} -> SetValue($i==$this->{denominator});
    push @{$this->{controls}}, $this->{'d'.$i};
    EVT_CHECKBOX($parent, $this->{'d'.$i}, sub{OnDenomClick(@_, $this, $i, $#cols)});
    @args = ();
    ++$count;
  };

  $columnbox->SetSizer($gbs);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  $this->{replot} = Wx::Button->new($this, -1, "Replot reference", wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  #$this->{clear}  = Wx::Button->new($this, -1, "Clear denominator");
  $this->{ln}     = Wx::CheckBox->new($this, -1, "Natural log");
  $this->{same}   = Wx::CheckBox->new($this, -1, "Same element");
  $hbox -> Add($this->{replot}, 0, wxLEFT|wxRIGHT, 5);
  #$hbox -> Add($this->{clear},  0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox -> Add($this->{ln},     0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox -> Add($this->{same},   0, wxGROW|wxLEFT|wxRIGHT, 5);
  push @{$this->{controls}}, $this->{replot};
  #push @{$this->{controls}}, $this->{clear};
  push @{$this->{controls}}, $this->{ln};
  push @{$this->{controls}}, $this->{same};
  #EVT_BUTTON($this, $this->{clear}, sub{  $this->clear_denominator($parent, $#cols) });
  EVT_CHECKBOX($this, $this->{ln}, sub{OnLnClick(@_, $this)} );
  EVT_BUTTON($this, $this->{replot}, sub{  $this->display_plot($parent) });

  $this->{ln}   -> SetValue(1);
  $this->{same} -> SetValue(1);

  $box -> Add($hbox, 0, wxALL, 3);

  EnableReference($this, 0, $data);

  $this->SetSizerAndFit($box);
  return $this;
};

sub EnableReference {
  #print join("|", caller), $/;
  my ($this, $event, $data) = @_;
  my $onoff = $this->{do_ref}->GetValue;
  $_->Enable($onoff) foreach @{$this->{controls}};
  if ($onoff) {
    $this->{reference} ||= Demeter::Data->new(file => $data->file,
					      name => "  Ref " . $data->name);
    $this->{reference} -> set(energy	  => $data->energy,
			      numerator	  => '$'.$this->{numerator},
			      denominator => '$'.$this->{denominator},
			      ln          => $this->{ln}->GetValue,
			      is_col	  => 1,);
    $this->{reference} -> display(1);
  };
};

sub OnLnClick {
  my ($nb, $event, $this) = @_;
  $this->{reference} -> ln($this->{ln}->GetValue);
  $this->display_plot($nb->GetParent);
};
sub OnNumerClick {
  my ($nb, $event, $this, $i, $n) = @_;
  foreach my $j (1 .. $n+1) {
    next if ($j == $i);
    $this->{'n'.$j} -> SetValue(0);
  };
  if ($this->{'n'.$i}->GetValue) {
    $this->{numerator}   = $i;
    $this->{reference}  -> numerator('$'.$i);
  } else {
    $this->{numerator}   = 0;
    $this->{reference}  -> numerator('1');
  };
  $this->display_plot($nb);
};
sub OnDenomClick {
  my ($nb, $event, $this, $i, $n) = @_;
  foreach my $j (1 .. $n+1) {
    next if ($j == $i);
    $this->{'d'.$j} -> SetValue(0);
  };
  if ($this->{'d'.$i}->GetValue) {
    $this->{denominator} = $i;
    $this->{reference}  -> denominator('$'.$i);
  } else {
    $this->{denominator} = 0;
    $this->{reference}  -> denominator('1');
  };
  $this->display_plot($nb);
};

#sub clear_denominator {
#  my ($this, $parent, $n) = @_;
#  foreach my $i (1 .. $n+1) {
#    $this->{'d'.$i} -> SetValue(0);
#  };
#  $this->{reference} -> denominator('1');
#  $this->display_plot($parent);
#};

sub display_plot {
  my ($this, $parent) = @_;
  my $kev = $parent->GetParent->GetParent->{units}->GetSelection;
  $this->{reference}  -> set(datatype=>'xmu', update_columns=>1, is_col=>1, is_kev=>$kev);
  $this->{reference}  -> _update('normalize');
  $this->{reference}  -> po -> start_plot;
  $this->{reference}  -> po -> set(e_mu=>1, e_markers=>0, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0, e_smooth=>0);
  $this->{reference}  -> plot('e');
};


1;


=head1 NAME

Demeter::UI::Athena::ColumnSelection::Preprocess - column selection reference spectrum controls

=head1 VERSION

This documentation refers to Demeter version 0.9.10.

=head1 SYNOPSIS

This module provides controls for specifying a reference in Athena's
column selection dialog

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All
rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
