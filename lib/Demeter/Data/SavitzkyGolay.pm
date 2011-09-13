package Demeter::Data::SavitzkyGolay;
use Moose::Role;

use PDL::Lite;

sub _sgolay {
  my ($self, $p, $n, $m, $ts) = @_;
  die "sgolay needs an odd filter length n" if ($n%2 != 1);
  die "sgolay needs filter length n larger than polynomial order p" if ($p >- $n);
  $m ||= 0;
  $ts ||= 1;

  my $filter = PDL->zeros($p, $n);
  my $f = PDL->zeros($n, $n);
  my $k = int($n/2);
  foreach my $row (0 .. $k) {
    ## Construct a matrix of weights Cij = xi ^ j.  The points xi are
    ## equally spaced on the unit grid, with past points using negative
    ## values and future points using positive values.
    #    C = ( [(1:n)-row]'*ones(1,p+1) ) .^ ( ones(n,1)*[0:p] );
    my $seq = PDL->sequence($n)+1-$row;
    my $prod = $seq->transpose x ones($p+1);
    my $exp = PDL->ones(1, $n) * sequence($p+1);
    my $c = $prod ** $exp;

    ## A = pseudo-inverse (C), so C*A = I; this is constructed from the SVD
    # A = pinv(C);
    my ($u, $s, $v, $info) = $c->svd;
    my $a = $v x stretcher(1/$s) x $u->transpose;

    ## Take the row of the matrix corresponding to the derivative
    ## you want to compute.
    # F(row,:) = A(1+m,:);
    $filter(:,$row) .= $a->slice(":,$m")
  };
  ## The filters shifted to the right are symmetric with those to the left.
  #F(k+2:n,:) = (-1)^m*F(k:-1:1,n:-1:1);
  #$filter(:,$k+2)
  return $filter;
};

sub sgolayfilt {

};

1;
