#!/usr/bin/perl

## Test String and Numeric type constraints for Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::Simple tests => 580;

use Demeter qw(:none);
use Demeter::StrTypes qw( Empty
			  IfeffitCommand
			  IfeffitFunction
			  IfeffitProgramVar
			  Window
			  PathParam
			  Element
			  Edge
			  Line
			  AtomsEdge
			  FeffCard
			  Feff6Card
			  Feff9Card
			  Clamp
			  Config
			  Statistic
			  AtomsLattice
			  AtomsGas
			  AtomsObsolete
			  SpaceGroup
			  Plotting
			  DataPart
			  FitSpace
			  PgplotLine
			  MERIP
			  PlotWeight
			  Interp
			  NotReserved
			  FitSpace
			  PlotSpace
			  PlotType
			  FitykFunction
			  Rankings
		       );

use Demeter::NumTypes qw( Natural
			  PosInt
			  OneToFour
			  OneToTwentyNine
			  NegInt
			  PosNum
			  NegNum
			  NonNeg
		       );
use Xray::Absorption;

my $demeter = Demeter->new;

foreach my $f (@Demeter::StrTypes::command_list) {
  my $ff = scramble_case($f);
  ok( is_IfeffitCommand($ff), "command $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::function_list) {
  my $ff = scramble_case($f);
  ok( is_IfeffitFunction($ff), "function $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::program_list) {
  my $ff = scramble_case($f);
  ok( is_IfeffitProgramVar($ff), "program variable $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::window_list) {
  my $ff = scramble_case($f);
  ok( is_Window($ff), "window type $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::pathparam_list) {
  my $ff = scramble_case($f);
  ok( is_PathParam($ff), "path parameter $ff recognized" );
};

## skip elements

foreach my $f (@Demeter::StrTypes::edge_list) {
  my $ff = scramble_case($f);
  ok( to_Edge($ff), "edge symbol $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::line_list) {
  my $ff = scramble_case($f);
  ok( to_Line($ff), "line symbol $ff recognized" );
  $ff = scramble_case(Xray::Absorption->get_IUPAC($f));
  ok( to_Line($ff), "line symbol $ff recognized" );
  $ff = scramble_case(Xray::Absorption->get_Siegbahn_full($f));
  ok( to_Line($ff), "line symbol $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::atomsedge_list) {
  my $ff = scramble_case($f);
  ok( to_AtomsEdge($ff), "atoms edge symbol $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::feffcard_list) {
  my $ff = scramble_case($f);
  ok( is_FeffCard($ff), "Feff card $ff recognized" );
};
foreach my $f (@Demeter::StrTypes::feff6card_list) {
  my $ff = scramble_case($f);
  ok( is_Feff6Card($ff), "Feff6 card $ff recognized" );
};
foreach my $f (@Demeter::StrTypes::feff9card_list) {
  my $ff = scramble_case($f);
  ok( is_Feff9Card($ff), "Feff9 card $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::clamp_list) {
  my $ff = scramble_case($f);
  ok( is_Clamp($ff), "clamp strength $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::config_list) {
  my $ff = scramble_case($f);
  ok( is_Config($ff), "configuration parameter $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::stat_list) {
  my $ff = scramble_case($f);
  ok( is_Statistic($ff), "statistics parameter $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::lattice_list) {
  my $ff = scramble_case($f);
  ok( is_AtomsLattice($ff), "Atoms lattice parameter $ff recognized" );
};

## skip atoms gas and obsolete

foreach my $f (@Demeter::StrTypes::sg_list) {
  my $ff = scramble_case($f);
  ok( is_SpaceGroup($ff), "space group parameter $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::plotting_list) {
  my $ff = scramble_case($f);
  ok( is_Plotting($ff), "plotting backend $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::dataparts_list) {
  my $ff = scramble_case($f);
  ok( is_DataPart($ff), "data part $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::pgplotlines_list) {
  my $ff = scramble_case($f);
  ok( is_PgplotLine($ff), "PGPLOT linetype $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::notreserved_list) {
  my $ff = scramble_case($f);
  ok( !is_PgplotLine($ff), "reserved word $ff recognized" );
};

foreach my $f (qw(m e r i p)) {
  my $ff = scramble_case($f);
  ok( is_MERIP($ff), "complex function part $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::fitspace_list) {
  my $ff = scramble_case($f);
  ok( to_FitSpace($ff), "fit space $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::plotspace_list) {
  my $ff = scramble_case($f);
  ok( to_PlotSpace($ff), "plot space $ff recognized" );
};
foreach my $f (@Demeter::StrTypes::plottype_list) {
  my $ff = scramble_case($f);
  ok( to_PlotType($ff), "plot type $ff recognized" );
};
foreach my $f (@Demeter::StrTypes::fitykfunction_list) {
  my $ff = scramble_case($f);
  ok( is_FitykFunction($ff), "fityk function $ff recognized" );
};

foreach my $f (@Demeter::StrTypes::rankings_list) {
  my $ff = scramble_case($f);
  ok( is_Rankings($ff), "ranking $ff recognized" );
};


my ($int, $real) = (7, 7.7);
ok( is_Natural(0),		  "0 is a natural number");
ok( is_Natural($int),		  "$int is a natural number");
ok(!is_Natural(-$int),	          "-$int is not a natural number");
ok(!is_Natural($real),	          "$real is not a natural number");

ok(!is_PosInt(0),		  "0 is not a positive integer");
ok( is_PosInt($int),		  "$int is a positive integer");
ok(!is_PosInt(-$int),		  "-$int is not a positive integer");

ok(!is_NegInt(0),		  "0 is not a negative integer");
ok(!is_NegInt($int),		  "$int is not a negative integer");
ok( is_NegInt(-$int),		  "-$int is a negative integer");

ok(!is_OneToFour(0),		  "0 is not between 1 & 4");
ok( is_OneToFour(2),		  "2 is between 1 & 4");
ok(!is_OneToFour($int),	          "$int is not between 1 & 4");

ok(!is_OneToTwentyNine(0),	  "0 is not between 1 & 29");
ok( is_OneToTwentyNine(2),	  "2 is between 1 & 29");
ok(!is_OneToTwentyNine(5*$int),   "5*$int is not between 1 & 29");

ok(!is_PosNum(0),		  "0 is not a positive number");
ok( is_PosNum($real),		  "$real is a positive number");
ok(!is_PosNum(-$real),	          "-$real is not a positive number");

ok(!is_NegNum(0),		  "0 is not a negative number");
ok(!is_NegNum($real),		  "$real is not a negative number");
ok( is_NegNum(-$real),	          "-$real is a negative number");

ok( is_NonNeg(0),		  "0 is non-negative");
ok( is_NonNeg($real),		  "$real is non-negative");
ok(!is_NonNeg(-$real),	          "-$real is not non-negative");




## swiped from Text::Capitalize (copyright 2003 Joseph Brenner), which
## did not install properly out of the box
sub scramble_case {
   # Function to provide a special effect: sCraMBliNg tHe CaSe
   local $_;
   my $string = shift;
   my (@chars, $uppity, $newstring, $total, $uppers, $downers, $tweak);
   @chars = split /(?=.)/, $string;

   # Instead of initializing to zero, using fudged initial counts to
   #   (1) provide an initial bias against leading with uppercase,
   #   (2) eliminate need to watch for division by zero on $tweak below.

   $uppers = 2;
   $downers = 1;
   foreach (@chars) {

      # Rather than "int(rand(2))" which generates a 50/50 distribution of 0s and 1s,
      # we're using "int(rand(1+$tweak))" where $tweak will
      # provide a restoring force back to the average
      # So here we want $tweak:
      #    to go to 1 when you approach $uppers = $downers
      #    to be larger than 1 if $downers > $uppers
      #    to be less than 1 if $uppers > $downers
      # Simple formula that does this:

      $tweak = $downers/$uppers;
      $uppity = int( rand(1 + $tweak) );

      if ($uppity) {
         $_ = uc;
         $uppers++;
       } else { 
         $_ = lc;
         $downers++;
       }
   }
   $newstring = join '', @chars;
   return $newstring;
}
