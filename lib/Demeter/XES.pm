package Demeter::XES;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .transmission
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Carp;

use File::Basename;
use List::MoreUtils qw(minmax);
use List::Util qw(max);

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use MooseX::Aliases;
#use MooseX::AlwaysCoerce;   # this might be useful....
#use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Element
			  Edge
			  Clamp
			  FitSpace
			  Window
			  Empty
			  DataType
		       );
use Demeter::NumTypes qw( Natural
			  PosInt
			  PosNum
			  NonNeg
		       );

with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

has '+plottable'  => (default => 1);
has '+data'       => (isa => Empty.'|Demeter::XES');

has 'file'        => (is => 'rw', isa => 'Str',  default => q{},
		      trigger=>sub{my ($self, $new) = @_;
				   $self->update_file(1);
				   $self->name($new) if not $self->name;
				 });

has 'energy'   => (is => 'rw', isa => PosInt, default => 2,);
has 'emission' => (is => 'rw', isa => PosInt, default => 3,);
has 'sigma'    => (is => 'rw', isa => PosInt, default => 4,);
has 'e1'       => (is => 'rw', isa => 'Num',  default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'e2'       => (is => 'rw', isa => 'Num',  default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'e3'       => (is => 'rw', isa => 'Num',  default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'e4'       => (is => 'rw', isa => 'Num',  default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'slope'    => (is => 'rw', isa => 'Num',  default => 0,);
has 'yoff'     => (is => 'rw', isa => 'Num',  default => 0,);
has 'norm'     => (is => 'rw', isa => 'Num',  default => 0,);
has 'peak'     => (is => 'rw', isa => 'Num',  default => 0,);


has 'eshift'            => (is => 'rw', isa => 'Num',  default => 0, alias => 'bkg_eshift');
has 'plot_multiplier'   => (is => 'rw', isa => 'Num',  default => 1,);
has 'y_offset'          => (is => 'rw', isa => 'Num',  default => 0,);
has 'update_file'       => (is => 'rw', isa => 'Bool', default => 1, trigger=>sub{my ($self, $new) = @_; $self->update_background(1) if $new});
has 'update_background' => (is => 'rw', isa => 'Bool', default => 1);

sub BUILD {
  my ($self, @params) = @_;
  $self->data($self); # I do not know of a way to set the data attribute to this instance using "has"....
};

sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

sub _update {
  my ($self, $how) = @_;
  $self->_read       if ($self->update_file and ($how =~ m{background|plot}));
  $self->_background if ($self->update_background and ($how eq 'plot'));
};

sub _read {
  my ($self) = @_;
  die "no XES data file specified" if (not $self->file);
  die "cannot read XES data file ".$self->file if (not -r $self->file);
  my $text = $self->template('analysis', 'xes_read');
  $self->dispose($text);
  $self->update_file(0);
  return $self;
};

sub _background {
  my ($self) = @_;
  $self->_update('background');
  my $text = $self->template('analysis', 'xes_background');
  $self->dispose($text);
  $self->slope(Ifeffit::get_scalar('xes___slope'));
  $self->yoff(Ifeffit::get_scalar('xes___yoff'));
  $self->norm(Ifeffit::get_scalar('xes___norm'));
  $self->peak_position;
  $self->update_background(0);
  return $self;
};

## this should fit a lineshape to the 1,3 peak and report its centroid
sub peak_position {
  my ($self) = @_;
  my @x = $self->get_array('energy');
  my @y = $self->get_array('norm');
  my $ymax = max(@y);
  my $i = -1;
  foreach my $yy (@y) {
    ++$i;
    last if ($yy eq $ymax);
  };
  $self->peak($x[$i]);
  return $self;
};


sub plot {
  my ($self, $how) = @_;
  $how ||= 'norm';
  die "XES plot types are norm, sub, and raw" if ($how !~ m{norm|sub|raw});
  $self->_update('plot');
  my ($emin, $emax) = minmax($self->get_array('energy'));
  $self->po->emin($emin-10);
  $self->po->emax($emax+10);
  my $newold = ($self->po->New)  ? 'new'  : 'over';
  my $text = $self->template('plot', $newold.'xes', {suffix=>$how});
  $self->dispose($text, 'plotting');
  $self->po->increment;

  if (($how eq 'raw') and ($self->po->e_bkg)) {
    my $text = $self->template('plot', 'overxes', {suffix=>'line'});
    $self->dispose($text, 'plotting');
    $self->po->increment;
  };

  return $self;
};



1;
