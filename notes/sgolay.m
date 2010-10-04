## Copyright (C) 2001 Paul Kienzle
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

## F = sgolay (p, n [, m [, ts]])
##   Computes the filter coefficients for all Savitzsky-Golay smoothing
##   filters of order p for length n (odd). m can be used in order to
##   get directly the mth derivative. In this case, ts is a scaling factor.
##
## The early rows of F smooth based on future values and later rows
## smooth based on past values, with the middle row using half future
## and half past.  In particular, you can use row i to estimate x(k)
## based on the i-1 preceding values and the n-i following values of x
## values as y(k) = F(i,:) * x(k-i+1:k+n-i).
##
## Normally, you would apply the first (n-1)/2 rows to the first k
## points of the vector, the last k rows to the last k points of the
## vector and middle row to the remainder, but for example if you were
## running on a realtime system where you wanted to smooth based on the
## all the data collected up to the current time, with a lag of five
## samples, you could apply just the filter on row n-5 to your window
## of length n each time you added a new sample.
##
## Reference: Numerical recipes in C. p 650
##
## See also: sgolayfilt

## 15 Dec 2004 modified by Pascal Dupuis <Pascal.Dupuis@esat.kuleuven.ac.be>
## Author: Paul Kienzle <pkienzle@users.sf.net>
## Based on smooth.m by E. Farhi <manuf@ldv.univ-montp2.fr>

function F = sgolay (p, n, m, ts)

  if (nargin < 2 || nargin > 4)
    usage ("F = sgolay (p, n [, m [, ts]])");
  elseif rem(n,2) != 1
    error ("sgolay needs an odd filter length n");
  elseif p >= n
    error ("sgolay needs filter length n larger than polynomial order p");
  else
    if nargin < 3, m = 0; endif
    if nargin < 4, ts = 1; endif
    if length(m) > 1, error("weight vector unimplemented"); endif

    ## Construct a set of filters from complete causal to completely
    ## noncausal, one filter per row.  For the bulk of your data you
    ## will use the central filter, but towards the ends you will need
    ## a filter that doesn't go beyond the end points.
    F = zeros (n, n);
    k = floor (n/2);
    for row = 1:k+1
      ## Construct a matrix of weights Cij = xi ^ j.  The points xi are
      ## equally spaced on the unit grid, with past points using negative
      ## values and future points using positive values.
      C = ( [(1:n)-row]'*ones(1,p+1) ) .^ ( ones(n,1)*[0:p] );
      ## A = pseudo-inverse (C), so C*A = I; this is constructed from the SVD
      A = pinv(C);
      ## Take the row of the matrix corresponding to the derivative
      ## you want to compute.
      F(row,:) = A(1+m,:);
    end
    ## The filters shifted to the right are symmetric with those to the left.
    F(k+2:n,:) = (-1)^m*F(k:-1:1,n:-1:1);

  endif
  F =  F * ( prod(1:m) / (ts^m) );
endfunction

%!test
%! N=2^12;
%! t=[0:N-1]'/N;
%! dt=t(2)-t(1);
%! w = 2*pi*50;
%! offset = 0.5; # 50 Hz carrier
%! # exponential modulation and its derivatives
%! d = 1+exp(-3*(t-offset));
%! dd = -3*exp(-3*(t-offset));
%! d2d = 9*exp(-3*(t-offset));
%! d3d = -27*exp(-3*(t-offset));
%! # modulated carrier and its derivatives
%! x = d.*sin(w*t);
%! dx = dd.*sin(w*t) + w*d.*cos(w*t);
%! d2x = (d2d-w^2*d).*sin(w*t) + 2*w*dd.*cos(w*t);
%! d3x = (d3d-3*w^2*dd).*sin(w*t) + (3*w*d2d-w^3*d).*cos(w*t);
%!
%! y = sgolayfilt(x,sgolay(8,41,0,dt));
%! assert(norm(y-x)/norm(x),0,2e-6);
%!
%! y = sgolayfilt(x,sgolay(8,41,1,dt));
%! assert(norm(y-dx)/norm(dx),0,5e-6);
%!
%! y = sgolayfilt(x,sgolay(8,41,2,dt));
%! assert(norm(y-d2x)/norm(d2x),0,5e-6);
%!
%! y = sgolayfilt(x,sgolay(8,41,3,dt));
%! assert(norm(y-d3x)/norm(d3x),0,1e-4);
