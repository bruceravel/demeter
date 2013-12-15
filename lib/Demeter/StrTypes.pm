package Demeter::StrTypes;

# predeclare our own types
use MooseX::Types -declare => [qw( Empty
				   FileName
				   IfeffitCommand
				   IfeffitFunction
				   IfeffitProgramVar
				   Window
				   PathParam
				   Element
				   ElementSymbol
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
				   PlotSpace
				   PlotType
				   DataType
				   TemplateProcess
				   TemplateFit
				   TemplatePlot
				   TemplateFeff
				   TemplateAnalysis
				   PgplotLine
				   MERIP
				   PlotWeight
				   Interp
				   GDS
				   NotReserved
                                   FitykFunction
				   IfeffitLineshape
                                   LarchLineshape
				   Lineshape
				   Rankings
				)];

## to do: modes

# import builtin types
use MooseX::Types::Moose 'Str';

use Chemistry::Elements qw(get_symbol);
use Xray::Absorption;
use Regexp::Assemble;

subtype Empty,
  as Str,
  where { lc($_) =~ m{\A\s*\z} },
  message { "That string ($_) is not an empty string" };

## -------- use a coercion to follow Windows shortcuts
subtype FileName, as   Str, where { 1 };
coerce  FileName, from Str, via { Demeter->follow_link($_) };


## -------- Ifeffit commands
use vars qw(@command_list $command_regexp);
@command_list = (qw{ f1f2 bkg_cl chi_noise color comment correl cursor
		     def echo erase exit feffit ff2chi fftf fftr
		     get_path guess history linestyle load
		     log macro minimize newplot path pause plot
		     plot_arrow plot_marker plot_text pre_edge print
		     quit random read_data rename reset restore
		     save set show spline sync unguess window
		     write_data zoom } );
$command_regexp = Regexp::Assemble->new()->add( @command_list )->re;
subtype IfeffitCommand,
  as Str,
  where { lc($_) =~ m{\A$command_regexp\z} },
  message { "That string ($_) is not an Ifeffit command" };


## -------- Ifeffit function
use vars qw(@function_list $function_regexp);
@function_list = qw{abs min max sign sqrt exp log ln log10 sin cos tan asin acos
		    atan sinh tanh coth gamma loggamma erf erfc gauss loren pvoight debye
		    eins npts ceil floor vsum vprod indarr ones zeros range deriv penalty
		    smooth interp qinterp splint eins debye };
$function_regexp = Regexp::Assemble->new()->add( @function_list )->re;
subtype IfeffitFunction,
  as Str,
  where { lc($_) =~ m{\A$function_regexp\z} },
  message { "That string ($_) is not an Ifeffit function" };

## -------- Ifeffit program variables
use vars qw(@program_list $program_regexp);
@program_list = qw(chi_reduced chi_square core_width correl_min
		   cursor_x cursor_y dk dr data_set data_total
		   dk1 dk2 dk1_spl dk2_spl dr1 dr2 e0 edge_step
		   epsilon_k epsilon_r etok kmax kmin kmax_spl
		   kmax_suggest kmin_spl kweight kweight_spl kwindow
		   n_idp n_varys ncolumn_label nknots norm1 norm2
		   norm_c0 norm_c1 norm_c2 path_index pi pre1 pre2
		   pre_offset pre_slope qmax_out qsp r_factor rbkg
		   rmax rmax_out rmin rsp rweight rwin rwindow toler);
$program_regexp = Regexp::Assemble->new()->add(@program_list)->re;
subtype IfeffitProgramVar,
  as Str,
  where { lc($_) =~ m{\A$program_regexp\z} },
  message { "That string ($_) is not an Ifeffit program variable" };

## -------- Window types
use vars qw(@window_list $window_regexp);
@window_list = qw(kaiser-bessel kaiser hanning welch parzen sine gaussian);
$window_regexp = Regexp::Assemble->new()->add(@window_list)->re;
subtype Window,
  as Str,
  where { lc($_) =~ m{\A$window_regexp\z} },
  message { "That string ($_) is not the name of Fourier transform window type" };

coerce Window, from Str, via { ($_ =~ m{[0-5]}) ? $window_list[$_] : $_ };


## -------- Path Parameters
use vars qw(@pathparam_list $pathparam_regexp);
@pathparam_list = qw(e0 ei sigma2 s02 delr third fourth dphase);
$pathparam_regexp = Regexp::Assemble->new()->add(@pathparam_list)->re;
subtype PathParam,
  as Str,
  where { lc($_) =~ m{\A$pathparam_regexp\z} },
  message { "That string ($_) is not a path parameter" };

## -------- Element symbols
use vars qw(@element_list $element_regexp);
@element_list = qw(h he li be b c n o f ne na mg al si p s cl ar k ca
		   sc ti v cr mn fe co ni cu zn ga ge as se br kr rb
		   sr y zr nb mo tc ru rh pd ag cd in sn sb te i xe cs
		   ba la ce pr nd pm sm eu gd tb dy ho er tm yb lu hf
		   ta w re os ir pt au hg tl pb bi po at rn fr ra ac
		   th pa u np pu am cm bk cf
		   nu); # es fm md no lr
$element_regexp = Regexp::Assemble->new()->add(@element_list)->re;
subtype Element,
  as Str,
  where { lc($_) =~ m{\A$element_regexp\z} },
  message { "That string ($_) is not an element symbol" };

#enum 'AllElements' => [ map {ucfirst $_} @element_list];

subtype ElementSymbol,
  as Str,
  where { lc(get_symbol($_)) =~ m{\A$element_regexp\z} },
  message { "That string ($_) is not an element symbol" };

coerce ElementSymbol,
  from Str,
  via { lc(get_symbol($_)) };


## -------- Edge symbols
use vars qw(@edge_list $edge_regexp);
@edge_list = qw(k l1 l2 l3 m1 m2 m3 m4 m5);
$edge_regexp = Regexp::Assemble->new()->add(@edge_list)->re;
subtype Edge,
  as Str,
  where { $_ =~ m{\A$edge_regexp\z} },
  message { "That string ($_) is not an edge symbol" };

coerce Edge,
  from Str,
  via { lc($_) };

## -------- Line symbols
use vars qw(@line_list $line_regexp);
@line_list = qw(ka1 ka2 ka3 kb1 kb2 kb3 kb4 kb5 lb3 lb4
		lg2 lg3 lb1 ln lg1 lg6 la1 lb2 la2 lb5 lb6
		ll ma mb mg mz); ##'lb2,15');
$line_regexp = Regexp::Assemble->new()->add(@line_list)->re;
subtype Line,
  as Str,
  where { lc(Xray::Absorption->get_Siegbahn($_)) =~ m{\A$line_regexp\z} },
  message { "That string ($_) is not an line symbol" };

coerce Line,
  from Str,
  via { lc(Xray::Absorption->get_Siegbahn($_)) };

## -------- Atoms Edge symbols
use vars qw(@atomsedge_list $atomsedge_regexp);
@atomsedge_list = qw(1 2 3 4 5 6 7 8 9 k l1 l2 l3 m1 m2 m3 m4 m5);
$atomsedge_regexp = Regexp::Assemble->new()->add(@atomsedge_list)->re;
subtype AtomsEdge,
  as Str,
  where { $_ =~ m{\A$atomsedge_regexp\z} },
  message { "That string ($_) is not an atoms edge symbol" };

coerce AtomsEdge,
  from Str,
  via { lc($_) };

## -------- Feff "cards"
use vars qw(@feffcard_list $feffcard_regexp);
@feffcard_list = qw(atoms control print title end rmultiplier
		    cfaverage overlap afolp edge hole potentials s02
		    exchange folp nohole rgrid scf unfreezef
		    interstitial ion spin exafs xanes ellipticity ldos
		    multipole polarization danes fprime rphases rsigma
		    tdlda xes xmcd xncd fms debye rpath rmax nleg
		    pcriteria ss criteria iorder nstar debye
		    corrections sig2);
$feffcard_regexp = Regexp::Assemble->new()->add(@feffcard_list)->re;
subtype FeffCard,
  as Str,
  where { lc($_) =~ m{\A$feffcard_regexp\z} },
  message { "That string ($_) is not a Feff keyword" };

## -------- Feff6 cards
use vars qw(@feff6card_list $feff6card_regexp);
@feff6card_list = qw(AFOLP ATOMS CONTROL CORRECTIONS CRITERIA DEBYE ELLIPTICITY END
		     EXCHANGE FOLP HOLE ION NEMAX NLEG NOGEOM OVERLAP PCRITERIA
		     POLARIZATION POTENTIALS PRINT RMAX RMULTIPLIER SIG2 SS TITLE
		     XANES);
$feff6card_regexp = Regexp::Assemble->new()->add(@feff6card_list)->re;
subtype Feff6Card,
  as Str,
  where { uc($_) =~ m{\A$feff6card_regexp\z} },
  message { "That string ($_) is not a Feff6 keyword" };


## -------- Feff9 cards
use vars qw(@feff9card_list $feff9card_regexp);
@feff9card_list = qw(ABSOLUTE AFOLP ATOMS BANDSTRUCTURE CFAVERAGE CHBROAD CHBROAD
		     CHSHIFT CHWIDTH CIF CONFIG CONTROL COORDINATES COREHOLE
		     CORRECTIONS CRITERIA DANES DEBYE DEBYE DIMS EDGE EGAP EGRID
		     ELLIPTICITY ELNES END EPS0 EQUIVALENCE EXAFS EXCHANGE EXELFS
		     EXTPOT FMS FOLP FPRIME HOLE INTERSTITIAL ION IORDER JUMPRM KMESH
		     LATTICE LDEC LDOS LJMAX MAGIC MBCONV MPSE MULTIPOLE NLEG NOHOLE
		     NRIXS NSTAR NUMDENS OPCONS OVERLAP PCRITERIA PLASMON PMBSE
		     POLARIZATION POTENTIALS PREPS PRINT RCONV REAL RECIPROCAL RESTART
		     RGRID RMULTIPLIER RPATH RPHASES RSIGMA S02 SCF SCREEN SELF
		     SETEDGE SFCONV SFSE SGROUP SIG2 SIG3 SPIN SS STRFACTORS SYMMETRY
		     TARGET TDLDA TITLE UNFREEZEF XANES XES XNCD);
$feff9card_regexp = Regexp::Assemble->new()->add(@feff9card_list)->re;
subtype Feff9Card,
  as Str,
  where { uc($_) =~ m{\A$feff9card_regexp\z} },
  message { "That string ($_) is not a Feff9 keyword" };

## -------- Clamp words
use vars qw(@clamp_list $clamp_regexp);
@clamp_list = qw(none slight weak medium strong rigid);
$clamp_regexp = Regexp::Assemble->new()->add(@clamp_list)->re;
subtype Clamp,
  as Str,
  where { lc($_) =~ m{\A$clamp_regexp\z} },
  message { "That string ($_) is not a clamp strength" };


## -------- Configuration keywords
use vars qw(@config_list $config_regexp);
@config_list = qw(type default minint maxint options units onvalue offvalue);
$config_regexp = Regexp::Assemble->new()->add(@config_list)->re;
subtype Config,
  as Str,
  where { lc($_) =~ m{\A$config_regexp\z} },
  message { "That string is ($_) not a Demeter configuration keyword" };

## -------- Statistics keywords
use vars qw(@stat_list $stat_regexp);
@stat_list = qw(n_idp n_varys chi_square chi_reduced r_factor epsilon_k
		epsilon_r data_total happiness);
$stat_regexp = Regexp::Assemble->new()->add(@stat_list)->re;
subtype Statistic,
  as Str,
  where { lc($_) =~ m{\A$stat_regexp\z} },
  message { "That string ($_) is not a Demeter statistical parameter" };


## -------- Atoms lattice keywords
use vars qw(@lattice_list $lattice_regexp);
@lattice_list = qw(a b c alpha beta gamma space shift);
$lattice_regexp = Regexp::Assemble->new()->add(@lattice_list)->re;
subtype AtomsLattice,
  as Str,
  where { lc($_) =~ m{\A$lattice_regexp\z} },
  message { "That string ($_) is not an Atoms lattice keyword" };

## -------- Atoms gas keywords
use vars qw(@gas_list $gas_regexp);
@gas_list = qw(nitrogen argon helium krypton xenon);
$gas_regexp = Regexp::Assemble->new()->add(@gas_list)->re;
subtype AtomsGas,
  as Str,
  where { lc($_) =~ m{\A$gas_regexp\z} },
  message { "That string ($_) is not an Atoms gas keyword" };

## -------- Atoms obsolete keywords
use vars qw(@obsolete_list $obsolete_regexp);
@obsolete_list = qw(output geom fdat nepoints xanes modules message
		    noanomalous self i0 mcmaster dwarf reflections
		    refile egrid index corrections emin emax estep
		    egrid qvec dafs );
$obsolete_regexp = Regexp::Assemble->new()->add(@obsolete_list)->re;
subtype AtomsObsolete,
  as Str,
  where { lc($_) =~ m{\A$obsolete_regexp\z} },
  message { "That string ($_) is not an Atoms obsolete keyword" };

## -------- Spacegroup database keys
use vars qw(@sg_list $sg_regexp);
@sg_list = qw(number full new_symbol thirtyfive schoenflies bravais
	      shorthand positions shiftvec npos);
$sg_regexp = Regexp::Assemble->new()->add(@sg_list)->re;
subtype SpaceGroup,
  as Str,
  where { lc($_) =~ m{\A$sg_regexp\z} },
  message { "That string ($_) is not a spacegroup database key" };

## -------- Plotting backends
use vars qw(@plotting_list $plotting_regexp);
@plotting_list = qw(pgplot gnuplot demeter singlefile);
$plotting_regexp = Regexp::Assemble->new()->add(@plotting_list)->re;
subtype Plotting,
  as Str,
  where { lc($_) =~ m{\A$plotting_regexp\z} },
  message { "That string ($_) is not a Demeter plotting backend" };

## -------- Data parts
use vars qw(@dataparts_list $dataparts_regexp);
@dataparts_list = qw(fit bkg res);
$dataparts_regexp = Regexp::Assemble->new()->add(@dataparts_list)->re;
subtype DataPart,
  as Str,
  where { lc($_) =~ m{\A$dataparts_regexp\z} },
  message { "That string ($_) is not a Demeter data part" };

## -------- Data types
use vars qw(@datatype_list $datatype_regexp);
@datatype_list = qw(xmu chi xmudat xanes);
$datatype_regexp = Regexp::Assemble->new()->add(@datatype_list)->re;
subtype DataType,
  as Str,
  where { lc($_) =~ m{\A$datatype_regexp\z} },
  message { "That string ($_) is not a Demeter data type" };

## -------- Fitting spaces
use vars qw(@fitspace_list $fitspace_regexp);
@fitspace_list = qw(k r q);
$fitspace_regexp = Regexp::Assemble->new()->add(@fitspace_list)->re;
subtype FitSpace,
  as Str,
  where { $_ =~ m{\A$fitspace_regexp\z} },
  message { "That string ($_) is not a Demeter fitting space" };

coerce FitSpace,
  from Str,
  via { lc($_) };

## -------- Plotting spaces
use vars qw(@plotspace_list $plotspace_regexp);
@plotspace_list = qw(e k r q);
$plotspace_regexp = Regexp::Assemble->new()->add(@plotspace_list)->re;
subtype PlotSpace,
  as Str,
  where { $_ =~ m{\A$plotspace_regexp\z} },
  message { "That string ($_) is not a Demeter plotting space" };

coerce PlotSpace,
  from Str,
  via { lc($_) };

## -------- Plotting types
use vars qw(@plottype_list $plottype_regexp);
@plottype_list = qw(e k r q rmr kq k123 r123);
$plottype_regexp = Regexp::Assemble->new()->add(@plottype_list)->re;
subtype PlotType,
  as Str,
  where { $_ =~ m{\A$plottype_regexp\z} },
  message { "That string ($_) is not a Demeter plot type" };

coerce PlotType,
  from Str,
  via { lc($_) };


## -------- Mode object type contstraints
##
## is it a good idea to define these type constraints?  if precludes
## the user adding new template sets...
## Possibly, the validation should look for the template set on disk...?
subtype TemplateProcess,
  as Str,
  where { $_ =~ m{\A(?:demeter|ifeffit|iff_columns|feffit)\z}i },
  message { "That ($_) is not a valid processing template group" };
subtype TemplateFit,
  as Str,
  where { $_ =~ m{\A(?:demeter|ifeffit|iff_columns|feffit)\z}i },
  message { "That ($_) is not a valid fitting template group" };
subtype TemplatePlot,
  as Str,
  where { $_ =~ m{\A(?:demeter|gnuplot|pgplot)\z}i },
  message { "That ($_) is not a valid plotting template group" };
subtype TemplateFeff,
  as Str,
  where { $_ =~ m{\Afeff[68]\z}i },
  message { "That ($_) is not a valid Feff template group" };
subtype TemplateAnalysis,
  as Str,
  where { $_ =~ m{\A(?:demeter|ifeffit|iff_columns)\z}i },
  message { "That ($_) is not a valid plotting template group" };


## -------- Line types in PGPLOT
use vars qw(@pgplotlines_list $pgplotlines_regexp);
@pgplotlines_list = qw(solid dashed dotted dot-dash points lines linespoints);
$pgplotlines_regexp = Regexp::Assemble->new()->add(@pgplotlines_list)->re;
subtype PgplotLine,
  as Str,
  where { lc($_) =~ m{\A$pgplotlines_regexp\z} },
  message { "That string ($_) is not a PGPLOT line type" };

subtype MERIP,
  as Str,
  where { lc($_) =~ m{\A(?:[merip]|rmr)\z} },
  message { "That string ($_) is not a complex function part" };

subtype PlotWeight,
  as Str,
  where { lc($_) =~ m{\A(?:1|2|3|arb)\z} },
  message { "That string ($_) is not a plotting k-weight" };

## -------- Ifeffit interpolation functions
use vars qw(@interp_list $interp_regexp);
@interp_list = qw(interp qinterp splint);
$interp_regexp = Regexp::Assemble->new()->add(@interp_list)->re;
subtype Interp,
  as Str,
  where { lc($_) =~ m{\A$interp_regexp\z} },
  message { "That string ($_) is not an interpolation type" };

## -------- Parameter types
use vars qw(@gds_list $gds_regexp);
@gds_list = qw(guess def set lguess restrain after skip penalty merge);
$gds_regexp = Regexp::Assemble->new()->add(@gds_list)->re;
subtype GDS,
  as Str,
  where { lc($_) =~ m{\A$gds_regexp\z} },
  message { "That string ($_) is not a parameter type" };

## -------- Reserved words cannot be parameter names
use vars qw(@notreserved_list $notreserved_regexp);
@notreserved_list = qw(reff pi etok cv);
$notreserved_regexp = Regexp::Assemble->new()->add(@notreserved_list)->re;
subtype NotReserved,
  as Str,
  where { lc($_) !~ m{\A$notreserved_regexp\z} },
  message { "reff, pi, etok, and cv are reserved words in Ifeffit or Demeter" };

coerce NotReserved,
  from Str,
  via { $_=lc($_); $_=~s{\A\s+}{}; $_=~s{\s+\z}{} };


## -------- Ifeffit lineshapes
use vars qw(@ifeffitlineshape_list $ifeffitlineshape_regexp);
@ifeffitlineshape_list = qw(linear gaussian lorentzian pvoigt atan erf);
$ifeffitlineshape_regexp = Regexp::Assemble->new()->add(map {lc($_)} @ifeffitlineshape_list)->re;
subtype IfeffitLineshape,
  as Str,
  where { lc($_) =~ m{\A$ifeffitlineshape_regexp\z} },
  message { "$_ is not a defined lineshape in Ifeffit" };

## -------- Larch lineshapes  skipped: lognormal breit_wigner
use vars qw(@larchlineshape_list $larchlineshape_regexp);
@larchlineshape_list = qw(linear gaussian lorentzian voigt pvoigt pseudo_voigt pearson7
			  logistic students_t
			  atan erf);
$larchlineshape_regexp = Regexp::Assemble->new()->add(map {lc($_)} @larchlineshape_list)->re;
subtype LarchLineshape,
  as Str,
  where { lc($_) =~ m{\A$larchlineshape_regexp\z} },
  message { "$_ is not a defined lineshape in Larch" };

## -------- Fityk defined functions
use vars qw(@fitykfunction_list $fitykfunction_regexp);
@fitykfunction_list = qw(Constant Linear Quadratic Cubic Polynomial4 Polynomial5 Polynomial6
			 Gaussian SplitGaussian Lorentzian Pearson7 SplitPearson7 PseudoVoigt
			 Voigt VoigtA EMG DoniachSunjic PielaszekCube LogNormal Spline Polyline
			 ExpDecay GaussianA LogNormalA LorentzianA Pearson7A PseudoVoigtA
			 SplitLorentzian SplitPseudoVoigt SplitVoigt
			 Atan Erf);
$fitykfunction_regexp = Regexp::Assemble->new()->add(map {lc($_)} @fitykfunction_list)->re;
subtype FitykFunction,
  as Str,
  where { lc($_) =~ m{\A$fitykfunction_regexp\z} },
  message { "$_ is not a defined function in Fityk" };


## -------- all lineshapes of all possible backends
use vars qw(@lineshape_list $lineshape_regexp);
@lineshape_list = (@ifeffitlineshape_list, @fitykfunction_list, @larchlineshape_list);
$lineshape_regexp = Regexp::Assemble->new()->add(map {lc($_)} @lineshape_list)->re;
subtype Lineshape,
  as Str,
  where { lc($_) =~ m{\A$lineshape_regexp\z} },
  message { "$_ is not a defined lineshape" };

## -------- all ranking criterion names
use vars qw(@rankings_list $rankings_regexp);
@rankings_list = qw(feff akc aknc sqkc sqknc mft sft); #  mkc mknc
$rankings_regexp = Regexp::Assemble->new()->add(map {lc($_)} @rankings_list)->re;
subtype Rankings,
  as Str,
  where { lc($_) =~ m{\A$rankings_regexp\z} },
  message { "$_ is not a defined ranking criterion" };



1;

=head1 NAME

Demeter::StrTypes - String type constraints

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 DESCRIPTION

This module implements string type constraints for Moose using
L<MooseX::Types>.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

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
