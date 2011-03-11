%module Ifeffit
%{
#include "ifeffit.h"
%}
%include cpointer.i
%include carrays.i
%include ifeffit.h
%pointer_functions(int,    Pint);
%pointer_functions(double, Pdbl);
%array_functions(double,   Parr);
