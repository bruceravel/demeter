package Demeter::XES;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use Chemistry::Elements qw(get_symbol get_Z);
use File::Basename;
use List::MoreUtils qw(minmax);
use List::Util qw(max);


use Demeter::Constants qw{$EPSILON3};

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';
#with 'Demeter::Data::Athena';

use MooseX::Aliases;
#use MooseX::AlwaysCoerce;   # this might be useful....
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Element
			  Line
			  FileName
			  Empty
		       );
use Demeter::NumTypes qw( Natural
			  PosInt
			  PosNum
			  NonNeg
		       );

with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

has '+plottable' => (default => 1);
has '+data'      => (isa => Empty.'|Demeter::XES');
has '+name'      => (default => 'XES' );

has 'file'       => (is => 'rw', isa => FileName,  default => q{},
		     trigger=>sub{my ($self, $new) = @_;
				  $self->update_file(1);
				  $self->name($new) if ((not $self->name) or ($self->name eq 'XES'));
				});
has 'plotkey'     => (is => 'rw', isa => 'Str',    default => q{});

has 'energy'   => (is => 'rw', isa => PosInt,   default => 2,);
has 'emission' => (is => 'rw', isa => PosInt,   default => 3,);
has 'sigma'    => (is => 'rw', isa => PosInt,   default => 4,);
has 'e1'       => (is => 'rw', isa => 'LaxNum',    default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'e2'       => (is => 'rw', isa => 'LaxNum',    default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'e3'       => (is => 'rw', isa => 'LaxNum',    default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'e4'       => (is => 'rw', isa => 'LaxNum',    default => 0, trigger=>sub{my ($self, $new) = @_; $self->update_background(1)});
has 'slope'    => (is => 'rw', isa => 'LaxNum',    default => 0,);
has 'yint'     => (is => 'rw', isa => 'LaxNum',    default => 0,);
has 'norm'     => (is => 'rw', isa => 'LaxNum',    default => 0,);
has 'peak'     => (is => 'rw', isa => 'LaxNum',    default => 0,);

has 'z'        => (is => 'rw', isa =>  Element, default => 'H');
has 'line'     => (is => 'rw', isa =>  Line,    default => 'Ka1');

has 'eshift'            => (is => 'rw', isa => 'LaxNum',  default => 0, alias => 'bkg_eshift');
has 'plot_multiplier'   => (is => 'rw', isa => 'LaxNum',  default => 1,);
has 'y_offset'          => (is => 'rw', isa => 'LaxNum',  default => 0,);
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
  $self->slope($self->fetch_scalar('xes___slope'));
  $self->yint($self->fetch_scalar('xes___yoff'));
  $self->norm($self->fetch_scalar('xes___norm'));
  $self->peak_position;
  $self->find_line;
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
    $self->plotkey('baseline');
    my $text = $self->template('plot', 'overxes', {suffix=>'line'});
    $self->dispose($text, 'plotting');
    $self->plotkey(q{});
    $self->po->increment;
  };

  return $self;
};

sub find_line {
  my ($self, $energy) = @_;
  ##return ('H', 'K') unless ($absorption_exists);
  my $input = $energy || $self->peak;
  my ($line, $answer, $this) = ("K", 1, 0);
  my $diff = 100000;
  foreach my $li (sort @Demeter::StrTypes::line_list) {
  Z: foreach (1..104) {
      last Z unless (Xray::Absorption->in_resource($_));
      my $e = Xray::Absorption -> get_energy($_, $li);
      next Z unless $e;
      $this = abs($e - $input);
      last Z if (($this > $diff) and ($e > $input));
      if ($this < $diff) {
	$diff = $this;
	$answer = $_;
	$line = $li;
	#print "$answer  $line\n";
      };
    };
  };
  $self->z(get_symbol($answer));
  ($line = 'kb1') if ($line eq 'kb3');
  $self->line($line);
  return ($answer, $line);;
};

sub prep_peakfit {
  my ($self, $xmin, $xmax) = @_;
  $self->_update('plot');
  my @e = $self->get_array("energy");
  if (abs($xmin) < $EPSILON3) {
    $xmin = $e[0];
  };
  if (abs($xmax) < $EPSILON3) {
    $xmax = $e[$#e];
  };
  return ($xmin, $xmax);
};

## this appends the actual data to the base class serialization
override 'serialization' => sub {
  my ($self) = @_;
  my $string = $self->SUPER::serialization;
  $string .= YAML::Tiny::Dump($self->ref_array("energy"));
  $string .= YAML::Tiny::Dump($self->ref_array("raw"));
  if ($self->sigma) {
    $string .= YAML::Tiny::Dump($self->ref_array("sigma"));
  }
  return $string;
};

override 'deserialize' => sub {
  my ($self, $fname) = @_;
  my @stuff = YAML::Tiny::LoadFile($fname);

  ## load the attributes
  my %args = %{ $stuff[0] };
  delete $args{plottable};
  my @args = %args;
  $self -> set(@args);
  $self -> group($self->_get_group);
  $self -> update_file(0);

  my @x  = @{ $stuff[1] };
  my @y  = @{ $stuff[2] };
  my @i0 = @{ $stuff[3] };

  $self->place_array($self->group.".energy",    \@x);
  $self->place_array($self->group.".raw", \@y);
  if ($self->sigma) {
    $self->place_array($self->group.".sigma",   \@i0);
  };

  $self->update_background(1);
  return $self;
};
alias thaw => 'deserialize';


# override '_write_record' => sub {
#   my ($self) = @_;
#   local $Data::Dumper::Indent = 0;
#   my ($string, $arraystring) = (q{}, q{});
#
#   my @array = ();
#
# }


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Data - Rudimentary processing of XES data

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

  my @common = (energy => 2,
                emission => 3,
                e1=>7610, e2=>7620, e3=>7660, e4=>7691
               );

  my $xes = Demeter::XES->new(file=>"xes.dat", @common, name => 'My XES data');
  $xes -> plot('norm');

=head1 DESCRIPTION

This subclass of the L<Demeter> class is used to perform simple
processing of XES data, i.e. data that contains emission as function
of energy at a specific indicent energy.

=head1 ATTRIBUTES

=over 4

=item C<file> (string)

This contains the name of the file containing the XES data.

=item C<plotkey>

Like in the Data object, this is used to temperarily override the
string used in a plot legend.

=item C<energy> (integer) I<[2]>

The column in the data file containing the energy axis.

=item C<emission> (integer) I<[3]>

The column in the data file containing the emmission intensity.

=item C<sigma> (intensity) I<[4]>

The column in the data file containing the uncertainty in the emmission intensity.

=item C<e1> (number) I<[0]>

The first boundary of the energy range used to determine the baseline.

=item C<e2> (number) I<[0]>

The second boundary of the energy range used to determine the baseline.

=item C<e3> (number) I<[0]>

The third boundary of the energy range used to determine the baseline.

=item C<e4> (number) I<[0]>

The fourth boundary of the energy range used to determine the baseline.

=item C<slope> (number)

The slope of the fitted baseline.

=item C<yoff> (number)

The y-offset value of the fitted baseline.

=item C<norm> (number)

The normalization value, i.e. the maximum value of the baseline subtracted data.

=item C<peak> (number)

The position of the largest peak in the meission data.

=item C<eshift> (number) I<[0]>

An energy shift used for plotting.

=item C<plot_multiplier> (number) I<[1]>

A plot multiplier used for plotting.

=item C<y_offset> (number) I<[0]>

A y-axis offset used from plotting.

=item C<update_file> (boolean)

A boolean that is true when the file needs to be reimported.

=item C<update_background> (boolean)

A boolean that is true when the data needs to be renormalized.

=back

=head1 METHODS

=over 4

=item C<plot>

Make a plot of the data.  The data willbe imported and normalized as
needed.  Plots my be made as C<raw>, C<sub>, or C<norm>:

  $xes -> plot($how);

C<raw> means to plot the raw data.  If the C<e_bkg> attribute of the
Plot object is true, then the fitted baseline will also be plotted.

C<sub> means to plot the baseline subtracted data.  C<norm> means to
plot the normalized data.  C<norm> is the default kind of plot,
i.e. the plot that is made when no argument is given.

In most ways, plotting XES data works like any other plotting in
Demeter.

=item C<peak_position>

Find the location of the peak of the main fluorescence line in the XES
data.

  $xes -> peak_position;

=item C<find_line>

Determine the element and emission line from the peak position and a
look-up table of emission lines.

  my ($element, $line) = $xes -> find_line;

In this form, it uses the value of the C<peak> attribute.  You can
also explicitly specify an energy:

  my ($element, $line) = $xes -> find_line($energy);

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.
Many attributes of a Data object can be configured via the
configuration system.  See, among others, the C<bkg>, C<fft>, C<bft>,
and C<fit> configuration groups.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 SERIALIZATION AND DESERIALIZATION

An XES object and be frozen to and thawed from a YAML file in the same
manner as a Data object.  The attributes and data arrays are read to
and from YAMLs with a single object perl YAML.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Peak fitting is currently broken for XES data

=back

Please report problems to the Ifeffit Mailing List
(http://cars9.uchicago.edu/mailman/listinfo/ifeffit/)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut



