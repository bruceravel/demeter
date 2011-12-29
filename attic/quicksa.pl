#!/usr/bin/perl

use strict;
use warnings;
use Chemistry::Formula;
use Term::ReadLine;
use Xray::Absorption;
use Xray::FluorescenceEXAFS;


#my $clear   = `clear`;
my $term    = new Term::ReadLine 'demeter';

my $matrix   = "SiO2";
my $sample   = "Fe2O3";
my $fraction =  0.01;
my $absorber = "Fe";
my $edge     = "K";


my $prompt = "Change a parameter by letter or q=quit > ";
&display;
while ( defined ($_ = $term->readline($prompt)) ) {
 DISPATCH: {
    exit if ($_ =~ m{\Aq}i);
    set("matrix"),   last DISPATCH if ($_ =~ m{\Am}i);
    set("sample"),   last DISPATCH if ($_ =~ m{\As}i);
    set("absorber"), last DISPATCH if ($_ =~ m{\Aa}i);
    set("edge"),     last DISPATCH if ($_ =~ m{\Ae}i);
    set("fraction"), last DISPATCH if ($_ =~ m{\Af}i);
  };
  &display;
};

sub display {
  #print $clear;
  print $/ x 5;
  print "(M)atrix   = ", $matrix, $/;
  print "(S)ample   = ", $sample, $/;
  print "(A)bsorber = ", $absorber, $/;
  print "(E)dge     = ", $edge, $/;
  print "(F)raction = ", $fraction, $/, $/;
  print &result, $/;
};

sub result {
  my $formula = sprintf("(%s)%.4f (%s)%.4f", $sample, $fraction, $matrix, 1-$fraction);
  my %count;
  my $ok = parse_formula($formula, \%count);
  return ("absorber is not in sample") if ($sample !~ m{$absorber});
  return ("Could not interpret formula \"$formula\".") if not $ok;
  my ($self_amp, $self_sigsqr) = Xray::FluorescenceEXAFS->self($absorber, $edge, \%count);
  return sprintf("%s\n%s : attenuation = %.4f\n", summary(\%count), $formula, $self_amp);
};


sub set {
  my ($which) = @_;
  my $prompt = "New value for $which > ";
  my $value  = $term->readline($prompt);
  if ($which eq 'fraction') {
    eval "\$$which = $value";
  } else {
    eval "\$$which = \"$value\"";
  };
  $absorber = ucfirst(lc($absorber));
  $edge = ucfirst(lc($edge));
  return;
};

sub summary {
  my ($rcount) = @_;
  my $text = sprintf "%s %s edge, edge energy = %.1f\n", ucfirst($absorber), ucfirst($edge), Xray::Absorption->get_energy($absorber, $edge);
  $text .= "  Element   number\n";
  $text .= " ---------------------\n";
  foreach my $el (sort(keys(%$rcount))) {
    $text .= sprintf("    %2s      %.4f\n", $el, $rcount->{$el});
  };
  return $text;
};

__END__


# The "quicksa.pl" script is really bare bones.  Here's the run-down.

# This program works on soichiometric fractions.  *You* will have to
# convert those to weight percentages, or whatever unit is convenient
# for sample prep.  For instance, in the first example below, the
# calculation is done for 1% stoichiometrically Fe2O3 in 99% SiO2, or a
# sample that has 201 O atoms, 2 iron atoms, and 99 Si atoms.

# The calculation is only strictly valid for the EXAFS wiggles.  For
# materials with particlarly large white lines (e.g. the La sample), you
# might want to be extra conservative in order to preserve the entire
# height of the white line.

# The calculation assumes an infinately thick sample and is insensitive
# to entrance/exit angle.  In that sense, it is a slightly conservative
# calculation given your interest in a grazing angle geometry.

# To use the program, open the Command Prompt on your windows machine.
# cd to the folder containing the file.  Once there, type 

#     perl quicksa.pl

# Upon starting, the following gets written to the screen:

#     (M)atrix   = SiO2
#     (S)ample   = Fe2O3
#     (A)bsorber = Fe
#     (E)dge     = K
#     (F)raction = 0.01

#     Fe K edge, edge energy = 7112.0
#       Element   number
#      ---------------------
#         Fe      0.0200
#          O      2.0100
#         Si      0.9900

#     (Fe2O3)0.0100 (SiO2)0.9900 : attentuation = 1.0523

#     Change a parameter by letter or q=quit >

# This shows the attenuation approximation for the default values of the
# parameters.  In this case, having 1% by stoichioemtry of Fe2O3 in
# silica would result in about a 5% attenuation of the wiggles.

# To quit the program, type "q" and hit return.

# To change a parameter, type "m", "s", "a", "e", or "f".  I am guessing
# you can figure out the secret code.  You will then get a prompt like
# this:

#     Change a parameter by letter or q=quit > s
#     New value for sample > ZrO2

#     (M)atrix   = SiO2
#     (S)ample   = ZrO2
#     (A)bsorber = Fe
#     (E)dge     = K
#     (F)raction = 0.01

#     absorber is not in sample
#     Change a parameter by letter or q=quit >

# The attenuation won't be calculated until you change the absorber

#     Change a parameter by letter or q=quit > a
#     New value for absorber > Zr

#     (M)atrix   = SiO2
#     (S)ample   = ZrO2
#     (A)bsorber = Zr
#     (E)dge     = K
#     (F)raction = 0.01

#     Zr K edge, edge energy = 17998.0
#       Element   number
#      ---------------------
#           O      2.0000
#          Si      0.9900
#          Zr      0.0100

#     (ZrO2)0.0100 (SiO2)0.9900 : attentuation = 1.1376

#     Change a parameter by letter or q=quit >

# In the case of ZrO2, you need to set the stoichiometric fraction (by
# typing "f" followed by the value) to 0.001 or less to get <1%
# atentuation.

# Error checking is not extensive.  If you tell the program to calculate
# the B7 edge, the program will die.  For the sample and matrix, you
# must write the formulas using the same rules as in Athena's
# self-absorption tool, i.e. "ZrO2" is ok, but "zro2" is not, nor are
# "ZRo2" or zRo2".  In short, element symbols must be first letter
# capitalized.

# Since the program operates in a loop, you can run through all your
# samples in one instance of the program.  The old-skool, command-line,
# single character interaction is certainly clunky, but it took me a
# half hour to write and debug.

# Enjoy!
