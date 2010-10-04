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

## y = sgolayfilt (x, p, n [, m [, ts]])
##    Smooth the data in x with a Savitsky-Golay smoothing filter of
##    polynomial order p and length n, n odd, n > p.  By default, p=3
##    and n=p+2 or n=p+3 if p is even.
##
## y = sgolayfilt (x, F)
##    Smooth the data in x with smoothing filter F computed by sgolay.
##
## These filters are particularly good at preserving lineshape while
## removing high frequency squiggles. Particularly, compare a 5 sample
## averager, an order 5 butterworth lowpass filter (cutoff 1/3) and
## sgolayfilt(x, 3, 5), the best cubic estimated from 5 points:
##
##    [b, a] = butter(5,1/3);
##    x=[zeros(1,15), 10*ones(1,10), zeros(1,15)];
##    plot(sgolayfilt(x),"r;sgolayfilt;",...
##         filtfilt(ones(1,5)/5,1,x),"g;5 sample average;",...
##         filtfilt(b,a,x),"c;order 5 butterworth;",...
##         x,"+b;original data;");
##
## See also: sgolay

## 15 Dec 2004 modified by Pascal Dupuis <Pascal.Dupuis@esat.kuleuven.ac.be>
## Author: Paul Kienzle <pkienzle@users.sf.net>

## TODO: Patch filter.cc so that it accepts matrix arguments

function y = sgolayfilt (x, p, n, m, ts)

  if nargin < 1 || nargin > 5
    usage("y = sgolayfilt(x,p,n [, m [, ts]]) or y = sgolayfilt(x,F)");
  endif

  if (nargin < 2)
    p = 3;
  endif
  if nargin < 4, m = 0; endif
  if nargin < 5, ts = 1; endif
  if (nargin >= 3)
    F = sgolay(p, n, m, ts);
  elseif (prod(size(p)) == 1)
    n = p+3-rem(p,2);
    F = sgolay(p, n);
  else
    F = p;
    n = size(F,1);
    if (size(F,1) != size(F,2))
      error("sgolayfilt(x,F): F is not a Savitzsky-Golay filter set");
    endif
  endif

  transpose = (size(x,1) == 1);
  if (transpose) x = x.'; endif;
  len = size(x,1);
  if (len < n)
    error("sgolayfilt: insufficient data for filter");
  endif

  ## The first k rows of F are used to filter the first k points
  ## of the data set based on the first n points of the data set.
  ## The last k rows of F are used to filter the last k points
  ## of the data set based on the last n points of the dataset.
  ## The remaining data is filtered using the central row of F.
  ## As the filter coefficients are used in the reverse order of what
  ## seems the logical notation, reverse F(k+1, :) so that antisymmetric
  ## sequences are used with the right sign.

  k = floor(n/2);
  z = filter(F(k+1,n:-1:1), 1, x);
  y = [ F(1:k,:)*x(1:n,:) ; z(n:len,:) ; F(k+2:n,:)*x(len-n+1:len,:) ];

  if (transpose) y = y.'; endif

endfunction

%!demo
%! [b, a] = butter(5,1/3);
%! x=[zeros(1,15), 10*ones(1,10), zeros(1,15)];
%! subplot(121); title("boxcar");
%! axis([1 40 -2 15]);
%! plot(sgolayfilt(x),"r;sgolay(3,5);",...
%!      filtfilt(ones(1,5)/5,1,x),"g;5 sample average;",...
%!      filtfilt(b,a,x),"c;order 5 butterworth;",...
%!      x,"+b;original data;"); title("");
%!
%! x=x+randn(size(x))/2;
%! subplot(122); title("boxcar+noise");
%! plot(sgolayfilt(x,3,5),"r;sgolay(3,5);",...
%!      filtfilt(ones(1,5)/5,1,x),"g;5 sample average;",...
%!      filtfilt(b,a,x),"c;order 5 butterworth;",...
%!      x,"+b;original data;"); title("");

%!demo
%! [b, a] = butter(5,1/3);
%! t = 0:0.01:1.0;                         % 1 second sample
%! x=cos(2*pi*t*3);                        % 3 Hz sinusoid
%! subplot(121); title("sinusoid");
%! axis([0 1 -1.5 2.5]);
%! plot(t,sgolayfilt(x,3,5),"r;sgolay(3,5);",...
%!      t,filtfilt(ones(1,5)/5,1,x),"g;5 sample average;",...
%!      t,filtfilt(b,a,x),"c;order 5 butterworth;",...
%!      t,x,"+b;original data;"); title("");
%!
%! x=x+0.2*randn(size(x));                % signal+noise
%! subplot(122); title("sinusoid+noise");
%! plot(t,sgolayfilt(x',3,5),"r;sgolay(3,5);",...
%!      t,filtfilt(ones(1,5)/5,1,x),"g;5 sample average;",...
%!      t,filtfilt(b,a,x),"c;order 5 butterworth;",...
%!      t,x,"+b;original data;"); title("");
%!
%! oneplot();
