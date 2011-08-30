package Demeter::PCA;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

use Carp;
#use Demeter::Carp;
use autodie qw(open close);

use Moose;
use Moose::Util qw(apply_all_roles);
use Moose::Util::TypeConstraints;
extends 'Demeter';
with 'Demeter::Data::Arrays';
use Demeter::StrTypes qw( Empty );

use PDL;
use PDL::Stats::GLM;

use List::Util;
use List::MoreUtils qw(pairwise);

with 'Demeter::PCA::Xanes';

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

has '+plottable'  => (default => 1);
has '+data'       => (isa => Empty.'|Demeter::Data');
has '+name'       => (default => 'PCA' );

has 'xmin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'xmax'  => (is => 'rw', isa => 'Num',    default => 0);

enum 'PCASpaces' => [qw(e x d c k)];
coerce 'PCASpaces',
  from 'Str',
  via { lc($_) };
has space => (is => 'rw', isa => 'PCASpaces', coerce => 1,
	      trigger => sub{my ($self, $new) = @_;
			     if ($new =~ m{[xe]}) {
			       eval {apply_all_roles($self, 'Demeter::PCA::Xanes')};
			       $@ and die("Histogram backend Demeter::PCA::Xanes could not be loaded");
			     } elsif ($new eq 'd') {
			       eval {apply_all_roles($self, 'Demeter::PCA::Deriv')};
			       print $@;
			       $@ and die("Histogram backend Demeter::PCA::Deriv does not exist");
			     } elsif ($new =~ m{[ck]}) {
			       eval {apply_all_roles($self, 'Demeter::PCA::Chi')};
			       print $@;
			       $@ and die("Histogram backend Demeter::PCA::Chi does not exist");
			     };
			   });

has 'e0' => (is => 'rw', isa => 'Num', default => 0);
has 'Piddle' => (is => 'rw', isa => 'PDL', default => sub {null});

has 'ndata' => (is => 'rw', isa => 'Int', default => 0);
has 'stack' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef[Demeter::Data]',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_stack',
			      'pop'     => 'pop_stack',
			      'shift'   => 'shift_stack',
			      'unshift' => 'unshift_stack',
			      'clear'   => 'clear_stack',
			     },
	       );

has 'eigenvalues'  => (is => 'rw', isa => 'PDL', default => sub {null});
has 'eigenvectors' => (is => 'rw', isa => 'PDL', default => sub {null});
has 'loadings'     => (is => 'rw', isa => 'PDL', default => sub {null});
has 'pct_var'      => (is => 'rw', isa => 'PDL', default => sub {null});

has 'reconstructed' => (is => 'rw', isa => 'PDL', default => sub {null});
has 'ncompused'     => (is => 'rw', isa => 'Int', default => 0);

sub add {
  my ($self, @groups) = @_;
  foreach my $g (@groups) {
    next if (ref($g) !~ m{Data\z});
    $self->push_stack($g);
  };
  return $self;
};

sub make_pdl {
  my ($self) = @_;
  my @list = ();
  foreach my $g (@{ $self->stack }) {
    push @list, $self->ref_array($g->group);
  };
  my $pdl = pdl \@list;
  $self->Piddle($pdl);
  $self->ndata($#{ $self->stack } + 1);
  return $self;
};


sub do_pca {
  my ($self) = @_;
  my %result = $self->Piddle->pca({PLOT=>0});
  $self->eigenvalues($result{eigenvalue});
  $self->eigenvectors($result{eigenvector});
  $self->loadings($result{loadings});
  $self->pct_var($result{pct_var});

  ## create the decomposition vectors
  my $decomposed = $self->eigenvectors x $self->Piddle;

  ## write each decomposition vector to an Ifeffit array in the PCA object's group
  foreach my $row (0 .. $decomposed->getdim(1)-1) {
    my $this = $decomposed->slice(":,($row)");
    my @array = list $this;
    $self->put_array("ev$row", \@array);
  };
  #$self->dispose("\&screen_echo = 1");
  #$self->dispose("show \@group ".$self->group);
  return $self;
};

sub reconstruct {
  my ($self, $ncomp) = @_;
  $self->ncompused($ncomp);
  $ncomp = $ncomp-1;
  my $slice = $self->eigenvectors->slice(":,0:$ncomp");
  my $reproduced = ($slice->transpose x $slice) x $self->Piddle;
  $self->reconstructed($reproduced);
  return $self;
};

sub plot_scree {
  my ($self, $do_log) = @_;
  $do_log ||= 0;
  my @array = list $self->pct_var;
  $self->put_array('index', [0 .. $#{ $self->stack }]);
  $self->put_array('scree', \@array);
  $self->po->start_plot;
  $self->dispose($self->template('analysis', 'pca_plot_scree', {log=>$do_log}), 'plotting');
  return $self;
};

sub plot_variance {
  my ($self) = @_;
  my @array = list $self->pct_var;
  @array = map { List::Util::sum @array[0..$_] } (0 ..$#array);
  $self->put_array('index', [0 .. $#{ $self->stack }]);
  $self->put_array('cumvar', \@array);
  $self->po->start_plot;
  $self->dispose($self->template('analysis', 'pca_plot_variance'), 'plotting');
  return $self;
};

sub plot_components {
  my ($self, @list) = @_;
  $self->po->start_plot;
  $self->e0($self->stack->[0]->bkg_e0);
  my $which = 'pca_new_component';
  @list = (0 .. $#{ $self->stack }) if not @list;
  foreach my $i (@list) {
    $self->dispose($self->template('analysis', $which, {component=>$i}), 'plotting');
    $self->po->increment;
    $which = 'pca_over_component';
  };
  return $self;
};

sub plot_stack {
  my ($self, @list) = @_;
  $self->po->start_plot;
  $self->e0($self->stack->[0]->bkg_e0);
  my $which = 'pca_new_stack';
  @list = (0 .. $#{ $self->stack }) if not @list;
  foreach my $i (@list) {
    $self->data($self->stack->[$i]);
    $self->dispose($self->template('analysis', $which), 'plotting');
    $self->po->increment;
    $which = 'pca_over_stack';
    $self->data(q{});
  };
  return $self;
};

sub plot_reconstruction {
  my ($self, $index) = @_;
  $self->po->start_plot;
  $self->e0($self->stack->[0]->bkg_e0);
  $self->data($self->stack->[$index]);
  my @data  = list($self->Piddle->slice(":,($index)"));
  my @recon = list($self->reconstructed->slice(":,($index)"));
  my @diff  = pairwise {$a - $b} @data, @recon;
  $self->put_array("rec$index",  \@recon);
  $self->put_array("diff$index", \@diff);
  $self->dispose($self->template('analysis', 'pca_plot_reconstruction', {index=>$index}), 'plotting');
  $self->data(q{});
  return $self;
};

sub plot_tt {
  my ($self, $target) = @_;
  $self->po->start_plot;
  $self->e0($self->stack->[0]->bkg_e0);
  my @data  = $self->get_array($target->group);
  my @tt    = $self->get_array('tt');
  my @diff  = pairwise {$a - $b} @data, @tt;
  $self->put_array("diff", \@diff);
  $self->data($target);
  $self->dispose($self->template('analysis', 'pca_plot_tt'), 'plotting');
  $self->data(q{});
  return $self;
};

sub report {
  my ($self) = @_;
  my $text = sprintf("Observation set size: %d spectra\n", $#{$self->stack}+1);
  $text   .= "Eignevalues:\n";
  my @ev   = list $self->eigenvalues;
  my @vars = list $self->pct_var;
  foreach my $i (0 .. $#{$self->stack}) {
    $text .= sprintf("\t %d: %.3g   %.3g\n", $i+1, $ev[$i], $vars[$i]);
  };
  return $text;
};



## see http://mailman.jach.hawaii.edu/pipermail/perldl/2006-August/000588.html
package PDL;

=for ref

Standardization (possibly weighted) of matrix over specified axis:

                         a - mean
        STANDARDIZED = ------------
                        stdev(n-1)

Uses arithmetic mean and standard deviation estimation if asked.
Can use arbitrary values (PDL vector) and compute inplace.

=for usage

PDL = stdize(PDL, SCALAR(axis), SCALAR|PDL(center), SCALAR|PDL(scale), SCALAR(weight))
axis   : threading's axis, generally observation, default = 1 unless a vector is given
center : center data by variable NOCENTER = 0 | CENTER = 1  | PDL, DEFAULT = 1
scale  : scale data by variable NOSCALE = 0 | SCALE = 1 | PDL, DEFAULT = 0
weight : PDL of weights (size(entry matrix)), DEFAULT = ones(entry matrix)

=for example

my $a = random(10,10);
my $standardized = stdize($a,1,1,1);

=cut

*stdize = \&PDL::stdize;

sub PDL::stdize {
  my($m, $obs, $center, $scale, $weight) = @_;
  $obs = 1 unless defined($obs) ||  $m->getndims < 2;
  $center = 1 unless defined $center;
  my ($mean, $rms, $mm);

  $m = $m->copy unless $m->is_inplace(0);

  $mm = $m->mv($obs,0);
  if ( !UNIVERSAL::isa($center,'PDL') || !UNIVERSAL::isa($scale,'PDL')) {
    ($mean, $rms) = $mm->statsover($weight);
    $center = $mean if (!UNIVERSAL::isa($center,'PDL') && $center);
    $scale = $rms if (!UNIVERSAL::isa($scale,'PDL') && $scale);
  }
  $mm = $mm->mv(0,$m->getndims-1);
  if (UNIVERSAL::isa($center,'PDL')){
    $mm -=  $center;
  }
  if (UNIVERSAL::isa($scale,'PDL')){
    $mm /=  $scale;
  }
  $m;
}


1;
