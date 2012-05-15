package Demeter::UI::Athena::Series;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHOICE EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Scalar::Util qw(looks_like_number);

#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "Copy series";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [120,-1];

my %params = ('bkg_rbkg'  => 'Background removal R_bkg',
	      'bkg_e0'    => 'Background removal E0',
	      'bkg_kw'    => 'Background removal k-weight',
	      'bkg_pre1'  => 'Lower end of pre-edge range',
	      'bkg_pre2'  => 'Upper end of pre-edge range',
	      'bkg_nor1'  => 'Lower end of normalization range',
	      'bkg_nor2'  => 'Upper end of normalization range',
	      'bkg_spl1'  => 'Lower end of spline range',
	      'bkg_spl2'  => 'Upper end of spline range',
	      'fft_kmin'  => 'Fourier tranform minimum k',
	      'fft_kmax'  => 'Fourier tranform maximum k',
	      'fft_dk'    => 'Fourier tranform sill width',
	      'bft_rmin'  => 'Back tranform minimum R',
	      'bft_rmax'  => 'Back tranform maximum R',
	      'bft_dr'    => 'Back tranform sill width',
	      'Background removal R_bkg'	 => 'bkg_rbkg',
	      'Background removal E0'		 => 'bkg_e0',
	      'Background removal k-weight'	 => 'bkg_kw',
	      'Lower end of pre-edge range'	 => 'bkg_pre1',
	      'Upper end of pre-edge range'	 => 'bkg_pre2',
	      'Lower end of normalization range' => 'bkg_nor1',
	      'Upper end of normalization range' => 'bkg_nor2',
	      'Lower end of spline range'	 => 'bkg_spl1',
	      'Upper end of spline range'	 => 'bkg_spl2',
	      'Fourier tranform minimum k'	 => 'fft_kmin',
	      'Fourier tranform maximum k'	 => 'fft_kmax',
	      'Fourier tranform sill width'	 => 'fft_dk',
	      'Back tranform minimum R'		 => 'bft_rmin',
	      'Back tranform maximum R'		 => 'bft_rmax',
	      'Back tranform sill width'	 => 'bft_dr',
	     );

my @order = ('bkg_rbkg', 'bkg_e0', 'bkg_kw', 'bkg_pre1', 'bkg_pre2', 'bkg_nor1',
	     'bkg_nor2', 'bkg_spl1', 'bkg_spl2', 'fft_kmin', 'fft_kmax', 'fft_dk',
	     'bft_rmin', 'bft_rmax', 'bft_dr');
my @labels = map {$params{$_}} @order;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  my $label = Wx::StaticText->new($this, -1, "Group");
  $gbs->Add($label, Wx::GBPosition->new(0,0));
  $label = Wx::StaticText->new($this, -1, "Parameter");
  $gbs->Add($label, Wx::GBPosition->new(1,0));
  $label = Wx::StaticText->new($this, -1, "Current value");
  $gbs->Add($label, Wx::GBPosition->new(2,0));
  $label = Wx::StaticText->new($this, -1, "Beginning value");
  $gbs->Add($label, Wx::GBPosition->new(3,0));
  $label = Wx::StaticText->new($this, -1, "Number of copies");
  $gbs->Add($label, Wx::GBPosition->new(4,0));
  $label = Wx::StaticText->new($this, -1, "Increment");
  $gbs->Add($label, Wx::GBPosition->new(5,0));

  $this->{group}   = Wx::StaticText->new($this, -1, q{});
  $this->{param}   = Wx::Choice->new($this, -1, wxDefaultPosition, [240, -1], [@labels]);
  $this->{current} = Wx::StaticText->new($this, -1, q{});
  $this->{begin}   = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{number}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{increm}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{param}  -> SetSelection(0);
  $gbs->Add($this->{group},   Wx::GBPosition->new(0,1));
  $gbs->Add($this->{param},   Wx::GBPosition->new(1,1));
  $gbs->Add($this->{current}, Wx::GBPosition->new(2,1));
  $gbs->Add($this->{begin},   Wx::GBPosition->new(3,1));
  $gbs->Add($this->{number},  Wx::GBPosition->new(4,1));
  $gbs->Add($this->{increm},  Wx::GBPosition->new(5,1));
  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) ) foreach (qw(begin increm));
  $this->{number} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9]) ) );
  foreach my $x (qw(begin number increm)) {
    EVT_TEXT_ENTER($this, $this->{$x}, sub{make(@_, $app)});
  };

  EVT_CHOICE($this, $this->{param}, sub{OnChoice(@_, $app)});

  $box->Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $this->{make}  = Wx::Button->new($this, -1, 'Make series of copied data groups');
  $this->{clear} = Wx::Button->new($this, -1, 'Clear values');
  $box -> Add($this->{make}, 0, wxGROW|wxALL, 2);
  $box -> Add($this->{clear}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{make},  sub{make(@_, $app)});
  EVT_BUTTON($this, $this->{clear}, sub{clear(@_)});

  $box->Add(1,1,1);		# this spacer may not be needed, Journal.pm, for example

  $this->{document} = Wx::Button->new($this, -1, 'Document section: copy series');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("series")});

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
  $this->{group}->SetLabel($data->name);
  my $which = $params{$this->{param}->GetStringSelection};
  $this->{current}->SetLabel($data->$which);
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnChoice {
  my ($this, $event, $app) = @_;
  my $data = $app->current_data;
  my $which = $params{$this->{param}->GetStringSelection};
  $this->{current}->SetLabel($data->$which);
};

sub make {
  my ($this, $event, $app) = @_;

  my $start  = $this->{begin}->GetValue;
  my $n      = $this->{number}->GetValue;
  my $increm = $this->{increm}->GetValue;

  if ($start =~ m{\A\s*\z}) {
    $app->{main}->status("Cannot copy a series -- no beginning value given");
    return;
  };
  if (not looks_like_number($start)) {
    $app->{main}->status("Cannot copy a series -- beginning value \"$start\" is not a number");
    return;
  };
  if ($n =~ m{\A\s*\z}) {
    $app->{main}->status("Cannot copy a series -- number of copies not specified");
    return;
  };
  if ($increm =~ m{\A\s*\z}) {
    $app->{main}->status("Cannot copy a series -- no increment given");
    return;
  };
  if (not looks_like_number($increm)) {
    $app->{main}->status("Cannot copy a series -- increment \"$increm\" is not a number");
    return;
  };

  my @sequence = ();
  foreach my $i (0 .. $n-1) {
    push @sequence, $start+$i*$increm;
  };

  ## check for attribute type
  my $att = $params{$this->{param}->GetStringSelection};
  foreach my $val (reverse @sequence) {
    my $name = sprintf("%s, %s=%s", $app->current_data->name, $att, $val);
    my $new = $app->Copy($name);
    $new->$att($val);
  };
  $::app->modified(1);
};

sub clear {
  my ($this, $event) = @_;
  $this->{$_}->SetValue(q{}) foreach (qw{begin number increm});
};

1;


=head1 NAME

Demeter::UI::Athena::Series - A tool for copying series of groups in Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.10.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need better group names

=item *

Need to check that generated values won't fail attribute type checking

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
