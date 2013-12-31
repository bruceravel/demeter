package Demeter::UI::Athena::Prefs;

use strict;
use warnings;

use Demeter::UI::Wx::Config;
use Demeter::StrTypes qw(AbsorptionTables);

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON);

use List::MoreUtils qw(none);

use vars qw($label $tag);
$label = "Preferences";
$tag = 'Prefs';

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{parent} = $parent;

  my $config = Demeter::UI::Wx::Config->new($this, \&target);
  $config->populate([qw(absorption athena bft bkg clamp convolution dispersive
			edgestep fft file fit gnuplot indicator interpolation
			lcf marker merge operations pca peakfit plot rebin
			smooth whiteline xanes)]);
  $box->Add($config, 1, wxGROW|wxALL, 5);
  $config->{params}->Expand($config->{params}->GetRootItem);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: preferences');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("other.prefs")});

  $this->SetSizerAndFit($box);
  return $this;
};

sub target {
  my ($self, $parent, $param, $value, $save) = @_;

 SWITCH: {
    ($parent eq 'lcf') and do {
      last SWITCH if none {$param eq $_} qw(components difference unity inclusive);
      my $p = (($param eq 'components') or ($param eq 'difference')) ? "plot_".$param : $param;
      $::app->{main}->{LCF}->{LCF}->$p($value);
      $::app->{main}->{LCF}->{$param}->SetValue($value);
      last SWITCH;
    };
    ($param eq 'plotwith') and do {
      $Demeter::UI::Athena::demeter->plot_with($value);
      last SWITCH;
    };
    ($param eq 'rmax_out') and do {
      foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
	my $this = $::app->{main}->{list}->GetIndexedData($i);
	$this->rmax_out($value);
      };
      last SWITCH;
    };
    (($parent eq 'absorption') and ($param eq 'tables')) and do {
      Xray::Absorption->load($value) if is_AbsorptionTables($value);
      last SWITCH;
    };
  };

  $value = Demeter->truefalse($value) if Demeter->co->Type($parent, $param) eq 'boolean';

  ($save)
    ? $::app->{main}->status("Now using $value for $parent-->$param and an ini file was saved")
      : $::app->{main}->status("Now using $value for $parent-->$param");

};

sub pull_values {
  my ($this, $data) = @_;
  1;
};
sub push_values {
  my ($this, $data) = @_;
  1;
};
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

1;



=head1 NAME

Demeter::UI::Athena::Prefs - A preferences tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

This module wraps up L<Demeter::UI::Wx::Config> for use in Athena.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
