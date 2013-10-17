package Demeter::PCA;

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

use Carp;
#use Demeter::Carp;
use autodie qw(open close);

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use Moose::Util qw(apply_all_roles);
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Empty );

use PDL::Lite;
use PDL::Stats::GLM;
use PDL::MatrixOps;

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

has 'xmin'    => (is => 'rw', isa => 'Num',    default => 0);
has 'xmax'    => (is => 'rw', isa => 'Num',    default => 0);
has 'ntitles' => (is => 'rw', isa => 'Int', default => 0);

enum 'PCASpaces' => [qw(e x d c k)];
coerce 'PCASpaces',
  from 'Str',
  via { lc($_) };
has space => (is => 'rw', isa => 'PCASpaces', coerce => 1,
	      trigger => sub{my ($self, $new) = @_;
	      		     if ($new =~ m{[xe]}) {
	      		       eval {apply_all_roles($self, 'Demeter::PCA::Xanes')};
	      		       $@ and die("PCA backend Demeter::PCA::Xanes could not be loaded");
	      		     } elsif ($new eq 'd') {
	      		       eval {apply_all_roles($self, 'Demeter::PCA::Deriv')};
	      		       print $@;
	      		       $@ and die("PCA backend Demeter::PCA::Deriv could not be loaded");
	      		     } elsif ($new =~ m{[ck]}) {
	      		       eval {apply_all_roles($self, 'Demeter::PCA::Chi')};
	      		       print $@;
	      		       $@ and die("PCA backend Demeter::PCA::Chi could not be loaded");
	      		     };
			     $self->update_stack(1);
			   }
	     );

has 'e0' => (is => 'rw', isa => 'Num', default => 0);
has 'data_matrix' => (is => 'rw', isa => 'PDL', default => sub {PDL::null});

has 'ndata' => (is => 'rw', isa => 'Int', default => 0);
has 'stack' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef[Demeter::Data]',
		default   => sub { [] },
		handles   => {
			      'push_stack'    => 'push',
			      'pop_stack'     => 'pop',
			      'shift_stack'   => 'shift',
			      'unshift_stack' => 'unshift',
			      'clear_stack'   => 'clear',
			     },
		trigger => sub{  my($self, $new) = @_; $self->ndata($#{ $self->stack } + 1);}
	       );
has 'stackgroups' => (
		      traits    => ['Array'],
		      is        => 'rw',
		      isa       => 'ArrayRef[Str]',
		      default   => sub { [] },
		      handles   => {
				    'push_stackgroups'    => 'push',
				    'pop_stackgroups'     => 'pop',
				    'shift_stackgroups'   => 'shift',
				    'unshift_stackgroups' => 'unshift',
				    'clear_stackgroups'   => 'clear',
				   },
		     );


has 'eigenvalues'  => (is => 'rw', isa => 'PDL', default => sub {PDL::null});
has 'eigenvectors' => (is => 'rw', isa => 'PDL', default => sub {PDL::null});
has 'loadings'     => (is => 'rw', isa => 'PDL', default => sub {PDL::null});
has 'pct_var'      => (is => 'rw', isa => 'PDL', default => sub {PDL::null});

has 'reconstructed' => (is => 'rw', isa => 'PDL', default => sub {PDL::null});
has 'ncompused'     => (is => 'rw', isa => 'Int', default => 0);

has 'update_stack'  => (is => 'rw', isa => 'Bool', default => 1,
			trigger => sub{ my($self, $new) = @_; $self->update_pdl(1) if $new });
has 'update_pdl'    => (is => 'rw', isa => 'Bool', default => 1,
			trigger => sub{ my($self, $new) = @_; $self->update_pca(1) if $new });
has 'update_pca'    => (is => 'rw', isa => 'Bool', default => 1);
has 'observations'  => (is => 'rw', isa => 'Int',  default => 0);
has 'undersampled'  => (is => 'rw', isa => 'Bool', default => 0);

has 'ttcoefficients' => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_PCA($self);
};

override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  foreach my $att (qw{eigenvalues eigenvectors loadings pct_var data_matrix reconstructed stack}) {
    delete $all{$att};
  };
  return %all;
};

## ======================================================================
## construction methods

sub add {
  my ($self, @groups) = @_;
  foreach my $g (@groups) {
    next if (ref($g) !~ m{Data\z});
    $self->push_stack($g);
    $self->push_stackgroups($g->group);
  };
  $self->update_stack(1);
  return $self;
};

sub make_pdl {
  my ($self) = @_;
  $self->interpolate_stack if $self->update_stack;
  my @list = ();
  foreach my $g (@{ $self->stack }) {
    push @list, $self->ref_array($g->group);
  };
  my $pdl = PDL->new(\@list);
  $self->data_matrix($pdl);
  $self->ndata($#{ $self->stack } + 1);
  $self->update_pdl(0);
  return $self;
};

sub refeig {
  my ($self) = @_;
  my @list = $self->pct_var->list;
  return \@list;
};

## ======================================================================
## linear algebra

sub do_pca {
  my ($self) = @_;
  $self->make_pdl if $self->update_pdl;
  my %result = $self->data_matrix->pca({PLOT=>0, CORR=>1});
  $self->eigenvalues($result{eigenvalue});
  $self->eigenvectors($result{eigenvector});
  $self->loadings($result{loadings});
  $self->pct_var($result{pct_var});

  ## create the decomposition vectors (these are piddles)
  my $decomposed = $self->eigenvectors x $self->data_matrix;
  ## write each decomposition vector to an array in the PCA object's group
  foreach my $row (0 .. $self->ndata-1) {
    my $this = $decomposed->slice(":,($row)");
    my @array = $this->list;
    $self->put_array("ev$row", \@array);
  };
  $self->update_pca(0);
  return $self;
};

sub reconstruct {
  my ($self, $ncomp) = @_;
  $ncomp ||= $self->ncompused;
  $ncomp ||= 2;
  $self->do_pca if $self->update_pca;
  $self->ncompused($ncomp);
  $ncomp = $ncomp-1;
  my $slice = $self->eigenvectors->slice(":,0:$ncomp");
  my $reproduced = $slice->transpose x $slice x $self->data_matrix;
  $self->reconstructed($reproduced);
  return $self;
};

sub tt {
  my ($self, $target, $ncomp) = @_;
  #$ncomp ||= $self->ndata;
  $ncomp ||= $self->ncompused;
  #$ncomp ||= 2;
  $self->ncompused($ncomp);
  my $nc = $ncomp-1;
  $self->interpolate_data($target);
  my $tarpdl = PDL->new($self->ref_array($target->group));
  # #$self->toggle_echo(1);
  # #$self->dispense('process', 'show', {items=> "\@group ".$self->group});

  $self->data($target);
  $self->dispense('analysis', 'save_pca_tt', {ncomp=>$ncomp});
  my @coef = ();
  foreach my $i (0 .. $self->ndata-1) {
    push @coef, $self->fetch_scalar("_p$i");
  };
  $self->ttcoefficients(\@coef);

  ## numbers in comments refer to equations in Malinowski, Chapter 3

#   my $row_matrix  = $self->eigenvectors->transpose x $self->data_matrix; # 3.66
#   my $data_dagger = $self->eigenvectors->slice("0:$nc,:") x $row_matrix->slice(":,0:$nc"); # 3.71
#   my $row_dagger  = $self->eigenvectors->transpose->slice(":,0:$nc") x $data_dagger;

#   my $lambda     = stretcher($self->eigenvalues->slice("0:$nc")); # matrix of eigenvalues on the diagonal
# #  my $tt         = $tarpdl x $row_matrix->slice(":,0:$nc")->transpose x $lambda->inv x $row_matrix->slice(":,0:$nc");
#   my $tt         = $tarpdl x $row_dagger->transpose x $lambda->inv x $row_dagger; # 3.84 and 3.97

#   my @array      = $tt->list;
#   $self->put_array("tt", \@array);
#   $self->data($target);
#   $self->dispense('analysis', 'pca_tt');
  return $self;
};






## ======================================================================
## plotting methods

sub plot_scree {
  my ($self, $do_log) = @_;
  $do_log ||= 0;
  my @array = $self->pct_var->list; # these is a piddle
  $self->put_array('index', [0 .. $#{ $self->stack }]);
  $self->put_array('scree', \@array);
  $self->po->start_plot;
  $self->chart('plot', 'pca_plot_scree', {log=>$do_log});
  return $self;
};

sub plot_variance {
  my ($self) = @_;
  my @array = $self->pct_var->list; # these is a piddle
  @array = map { List::Util::sum @array[0..$_] } (0 ..$#array);
  $self->put_array('index', [0 .. $#{ $self->stack }]);
  $self->put_array('cumvar', \@array);
  $self->po->start_plot;
  $self->chart('plot', 'pca_plot_variance');
  return $self;
};

sub plot_components {
  my ($self, @list) = @_;
  $self->po->start_plot;
  $self->e0($self->stack->[0]->bkg_e0);
  my $which = 'pca_new_component';
  @list = (0 .. $#{ $self->stack }) if not @list;
  foreach my $i (@list) {
    $self->chart('plot', $which, {component=>$i});
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
    $self->chart('plot', $which);
    $self->po->increment;
    $which = 'pca_over_stack';
    $self->data(q{});
  };
  return $self;
};

sub plot_reconstruction {
  my ($self, $index, $noplot) = @_;
  $self->po->start_plot;
  $self->e0($self->stack->[0]->bkg_e0);
  $self->data($self->stack->[$index]);
  my @data  = $self->data_matrix->slice(":,($index)")->list; # these are piddles
  my @recon = $self->reconstructed->slice(":,($index)")->list;
  my @diff  = pairwise {$a - $b} @recon, @data;
  $self->put_array("rec$index",  \@recon);
  $self->put_array("diff$index", \@diff);
  $self->chart('plot', 'pca_plot_reconstruction', {index=>$index}) if not $noplot;
  $self->data(q{});
  return $self;
};

sub plot_tt {
  my ($self, $target) = @_;
  $self->po->start_plot;
  $self->e0($self->stack->[0]->bkg_e0);
  my @data  = $self->get_array($target->group);
  my @tt    = $self->get_array('tt');
  my @diff  = pairwise {$a - $b} @tt, @data;
  $self->put_array("diff", \@diff);
  $self->data($target);
  $self->chart('plot', 'pca_plot_tt');
  $self->data(q{});
  return $self;
};

## ======================================================================
## reporting methods

sub report {
  my ($self) = @_;
  my $text = "Performed PCA using " . $self->space_description . "\n";
  $text   .= sprintf("Number of components: %d spectra\n", $#{$self->stack}+1);
  $text   .= sprintf("Number of observations: %d data points\n", $self->observations);
  return if $self->undersampled;
  $text   .= "\n      Eignevalues   Variance   Cumulative variance\n";
  my @ev   = $self->eigenvalues->list; # these are piddles
  my @vars = $self->pct_var->list;
  my @cumvar = map { List::Util::sum @vars[0..$_] } (0 ..$#vars);
  foreach my $i (0 .. $#{$self->stack}) {
    $text .= sprintf("%3d:   %.6f      %.6f    %.6f\n", $i+1, $ev[$i], $vars[$i], $cumvar[$i]);
  };
  return $text;
};

sub tt_report {
  my ($self, $target) = @_;
  my $i = 0;
  my $text = $target->name . ":\n";
  foreach my $c (@{$self->ttcoefficients}) {
    ++$i;
    last if $i > $self->ncompused;
    $text .= sprintf("%4d: %9.5f\n", $i, $c)
  };
  return $text;
};

sub header {
  my ($self) = @_;
  my $header = "Principle components for:\n";
  my $i = 0;
  foreach my $g (@{$self->stack}) {
    $header .= sprintf(". %3d: %s\n", $i++, $g->name);
  };
  $header .= $self->report;
  my @n = split(/\n/, $header);
  $self->ntitles($#n+1);
  return $header;
};

sub save_components {
  my ($self, $filename) = @_;
  $self->dispense('analysis', 'pca_header', {which=>'components'});
  $self->dispense('analysis', 'pca_save', {filename=>$filename});
  return $self;
};

sub save_stack {
  my ($self, $filename) = @_;
  $self->dispense('analysis', 'pca_header', {which=>'data stack'});
  $self->dispense('analysis', 'pca_save_stack', {filename=>$filename});
  return $self;
};

sub save_reconstruction {
  my ($self, $index, $filename) = @_;
  $self->reconstruct;
  $self->plot_reconstruction($index, 1);
  $self->data($self->stack->[$index]);
  $self->dispense('analysis', 'pca_header', {which=>'reconstruction'});
  $self->dispense('analysis', 'pca_save_reconstruction', {index=>$index, filename=>$filename});
  $self->data(q{});
  return $self;
};

sub save_tt {
  my ($self, $target, $filename) = @_;
  $self->data($target);
  $self->dispense('analysis', 'pca_header', {which=>'target transform'});
  $self->dispense('analysis', 'pca_save_tt', {filename=>$filename});
  $self->data(q{});
  return $self;
};

__PACKAGE__->meta->make_immutable;


# ## see http://mailman.jach.hawaii.edu/pipermail/perldl/2006-August/000588.html
# package PDL;

# =for ref

# Standardization (possibly weighted) of matrix over specified axis:

#                          a - mean
#         STANDARDIZED = ------------
#                         stdev(n-1)

# Uses arithmetic mean and standard deviation estimation if asked.
# Can use arbitrary values (PDL vector) and compute inplace.

# =for usage

# PDL = stdize(PDL, SCALAR(axis), SCALAR|PDL(center), SCALAR|PDL(scale), SCALAR(weight))
# axis   : threading's axis, generally observation, default = 1 unless a vector is given
# center : center data by variable NOCENTER = 0 | CENTER = 1  | PDL, DEFAULT = 1
# scale  : scale data by variable NOSCALE = 0 | SCALE = 1 | PDL, DEFAULT = 0
# weight : PDL of weights (size(entry matrix)), DEFAULT = ones(entry matrix)

# =for example

# my $a = random(10,10);
# my $standardized = stdize($a,1,1,1);

# =cut

# *stdize = \&PDL::stdize;

# sub PDL::stdize {
#   my($m, $obs, $center, $scale, $weight) = @_;
#   $obs = 1 unless defined($obs) ||  $m->getndims < 2;
#   $center = 1 unless defined $center;
#   my ($mean, $rms, $mm);

#   $m = $m->copy unless $m->is_inplace(0);

#   $mm = $m->mv($obs,0);
#   if ( !UNIVERSAL::isa($center,'PDL') || !UNIVERSAL::isa($scale,'PDL')) {
#     ($mean, $rms) = $mm->statsover($weight);
#     $center = $mean if (!UNIVERSAL::isa($center,'PDL') && $center);
#     $scale = $rms if (!UNIVERSAL::isa($scale,'PDL') && $scale);
#   }
#   $mm = $mm->mv(0,$m->getndims-1);
#   if (UNIVERSAL::isa($center,'PDL')){
#     $mm -=  $center;
#   }
#   if (UNIVERSAL::isa($scale,'PDL')){
#     $mm /=  $scale;
#   }
#   $m;
# }


1;

=head1 NAME

Demeter::PCA - Principle components analysis

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the C<pca> configuration group for the relevant parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Document me!

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

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


