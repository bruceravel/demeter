package Demeter::PCA::Xanes;
use Moose::Role;

has 'emin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'emax'  => (is => 'rw', isa => 'Num',    default => 0);

has 'suffix' => (is => 'rw', isa => 'Str',    default => q{flat});
has 'space_description' => (is => 'rw', isa => 'Str',    default => q{normalized mu(E)});

sub interpolate {
  my ($self) = @_;

  $self->xmin($self->emin);
  $self->xmax($self->emax);

  my @groups = @{ $self->stack };
  @groups = grep {ref($_) =~ m{Data\z}} @groups;
  foreach my $g (@groups) {
    $g -> _update('fft');
  };
  my $first = shift @groups;

  my $e1 = $first->bkg_e0 + $self->xmin;
  my $i1 = $first->iofx('energy', $e1);
  my $e2 = $first->bkg_e0 + $self->xmax;
  my $i2 = $first->iofx('energy', $e2);
  $first->standard;

  my $suff = ($first->bkg_flatten) ? 'flat' : 'norm';
  $self->dispose($self->template('analysis', 'pca_prep', {suff=>$suff , i1=>$i1, i2=>$i2}));

  foreach my $g (@groups) {
    $self->data($g);
    $suff = ($g->bkg_flatten) ? 'flat' : 'norm';
    $self->dispose($self->template('analysis', 'pca_interpolate', {suff=>$suff}));
    $self->data(q{});
  };

  $first->unset_standard;

};



1;
