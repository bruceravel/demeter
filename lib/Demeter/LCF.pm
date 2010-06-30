package Demeter::LCF;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .transmission
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .-$self->data->bkg_e0
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Carp;

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use MooseX::Aliases;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Empty );

with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

has '+plottable'  => (default => 1);
has '+data'       => (isa => Empty.'|Demeter::Data');

has 'xmin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'xmax'  => (is => 'rw', isa => 'Num',    default => 0);
has 'space' => (is => 'rw', isa => 'Str',    default => q{norm},  # deriv chi
		trigger => sub{my ($self, $new) = @_;
			       $self->suffix(q{norm}) if ((lc($new) =~ m{\Anor}) and $self->data and (not $self->data->bkg_flatten));
			       $self->suffix(q{flat}) if ((lc($new) =~ m{\Anor}) and $self->data and ($self->data->bkg_flatten));
			       $self->suffix(q{der})  if  (lc($new) =~ m{\Ader});
			       $self->suffix(q{chi})  if  (lc($new) =~ m{\Achi});
			      });
has 'suffix' => (is => 'rw', isa => 'Str',    default => q{flat});
has 'noise'  => (is => 'rw', isa => 'Num',    default => 0);

has 'max_standards' => (is => 'rw', isa => 'Int', default => 4);

has 'linear'    => (is => 'rw', isa => 'Bool',    default => 0);
has 'inclusive' => (is => 'rw', isa => 'Bool',    default => 0);
has 'unity'     => (is => 'rw', isa => 'Bool',    default => 1);
has 'one_e0'    => (is => 'rw', isa => 'Bool',    default => 0);

has 'plot_components' => (is => 'rw', isa => 'Bool',    default => 0);
has 'plot_difference' => (is => 'rw', isa => 'Bool',    default => 0);

has 'nstan' => (is => 'rw', isa => 'Int', default => 0);
has 'standards' => (
		    metaclass => 'Collection::Array',
		    is        => 'rw',
		    isa       => 'ArrayRef[Demeter::Data]',
		    default   => sub { [] },
		    provides  => {
				  'push'    => 'push_standards',
				  'pop'     => 'pop_standards',
				  'shift'   => 'shift_standards',
				  'unshift' => 'unshift_standards',
				  'clear'   => 'clear_standards',
				 },
		   );
has 'options' => (
		  metaclass => 'Collection::Hash',
		  is        => 'rw',
		  isa       => 'HashRef[ArrayRef]',
		  default   => sub { +{} },
		  provides  => {
				set   => 'set_option',
				get   => 'get_option',
				keys  => 'get_option_list'
			       }
		 );

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_LCF($self);
};

## float_e0  require
sub add {
  my ($self, $stan, @params) = @_;
  my %hash = @params;
  $hash{float_e0} ||= 0;
  $hash{required} ||= 0;
  $hash{e0}       ||= 0;
  my @previous = @{ $self->standards };
  $self->push_standards($stan);

  my $n = $#{ $self->standards } + 1;
  $self->nstan($n);
  $hash{weight}   ||= sprintf("%.3f", 1/$n);

  my $key = $stan->group;
  $self->set_option($key, [$hash{float_e0}, $hash{required}, $hash{weight}, 0, $hash{e0}, 0]); ## other 2 are dweight and de0

  foreach my $prev (@previous) {
    $self->weight($prev, (1-$hash{weight})/($n-1));
  };
  return $self;
};

sub float_e0 {
  my ($self, $stan, $onoff) = @_;
  $onoff ||= 0;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  $params[0] = $onoff;
  return $self;
};

sub required {
  my ($self, $stan, $onoff) = @_;
  $onoff ||= 0;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  $params[1] = $onoff;
  $self->set_option(\@params);
  return $self;
};

sub weight {
  my ($self, $stan, $value, $error) = @_;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  return ($params[2], $params[3]) if (not defined($value));
  $params[2] = $value;
  $params[3] = $error || 0;
  $self->set_option($stan->group, \@params);
  return ($params[2], $params[3]);
};

sub e0 {
  my ($self, $stan, $value, $error) = @_;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  return ($params[4], $params[5]) if (not defined($value));
  $params[4] = $value;
  $params[5] = $error || 0;
  $self->set_option($stan->group, \@params);
  return ($params[4], $params[5]);
};

sub standards_list {
  my ($self) = @_;
  return map {$_->group} (@{$self->standards});
};

sub fit {
  ## check that data is set, check that 2 or more standards are set
  my ($self) = @_;
  #my ($how) = ($self->suffix eq 'chi') ? 'fft' : 'background';
  $self->data->_update('fft');
  $_ -> _update('fft') foreach (@{ $self->standards });

  ## prepare the data for LCF fitting
  my $n1 = $self->data->iofx('energy', $self->xmin);
  my $n2 = $self->data->iofx('energy', $self->xmax);
  $self -> dispose($self->template("analysis", "lcf_prep", {n1=>$n1, n2=>$n2}));

  ## interpolate all the standards onto the grid of the data
  $self->mo->standard($self);
  my @all = @{ $self->standards };
  foreach my $stan (@all[0..$#all-1]) {
    $stan -> dispose($stan->template("analysis", "lcf_prep_standard"));
  };
  if ($self->unity) {
    $all[-1] -> dispose($all[-1]->template("analysis", "lcf_prep_last"));
  } else {
    $all[-1] -> dispose($all[-1]->template("analysis", "lcf_prep_standard"));
  };

  ## create the array to minimize and perform the fit
  $self -> dispose($self->template("analysis", "lcf_fit"));

  my $sumsqr = 0;
  foreach my $st (@all) {
    my ($w, $dw) = $self->weight($st, Ifeffit::get_scalar("aa_".$st->group), Ifeffit::get_scalar("delta_a_".$st->group));
    $sumsqr += $dw**2;
    print join("  ", $st->group, $self->weight($st)), $/;
  };
  if ($self->unity) {		# propagate uncertainty for last amplitude
    my ($w, $dw) = $self->weight($all[-1]);
    $self->weight($all[-1], $w, sqrt($sumsqr));
  };
  print join("  ", $all[-1]->group, $self->weight($all[-1])), $/;


  $self->po->start_plot;
  $self->po->set(e_norm=>1, e_markers=>0);
  $self->data->plot('E');
  $self->dispose($self->template("plot", "overlcf"));
  $self->po->increment;

  #my @indic = (Demeter::Plot::Indicator->new(space=>'E', x=>$self->xmin-$self->data->bkg_e0),
 #	       Demeter::Plot::Indicator->new(space=>'E', x=>$self->xmax-$self->data->bkg_e0));
 # $self->data->standard;
 # $_->plot('E') foreach (@indic);

};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::VPath - Virtual paths for EXAFS visualization

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

gnuplot plotting not working

=item *

Test turning unity off

=item *

chi(k) completely undone

=item *

sanity checks

=item *

plot diff, plot components

=item *

write a report column data file, need results text method method

=item *

make a normal Data group

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


