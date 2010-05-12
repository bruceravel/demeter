package Demeter;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

BEGIN {
  $ENV{PGPLOT_DEV} = (($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? '/GW' : '/xserve';
};

require 5.8.0;

use version;
our $VERSION = version->new('0.4.1');
use vars qw($Gnuplot_exists);

#use Demeter::Carp;
use Carp;
use Cwd;
use File::Basename qw(dirname);
use File::Spec;
use List::MoreUtils qw(any minmax zip);
#use Safe;
use Pod::POM;
use String::Random qw(random_string);
use Text::Template;
use Xray::Absorption;
Xray::Absorption->load('elam');

use Regexp::Common;
#use Regexp::List;
use Regexp::Optimizer;
my $opt  = Regexp::List->new;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};

=for LiteratureReference
  Then, spent as they were from all their toil,
  they set out food, the bounty of Ceres, drenched
  in sea-salt, Ceres' utensils too, her mills and troughs,
  and bend to parch with fire the grain they had salvaged,
  grind it fine on stone.
                                Virgil, The Aeneid, 1:209-213

=cut

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
use Ifeffit;
with 'Demeter::Dispose';
with 'Demeter::Tools';
with 'Demeter::Files';
with 'Demeter::Project';
with 'Demeter::MRU';

with 'MooseX::SetGet';		# this is mine....

#use MooseX::Storage;
#with Storage('format' => 'YAML', 'io' => 'File');


my %seen_group;
has 'group'     => (is => 'rw', isa => 'Str',  default => sub{shift->_get_group()});
has 'name'      => (is => 'rw', isa => 'Str',  default => q{});
has 'plottable' => (is => 'ro', isa => 'Bool', default => 0);
has 'pathtype'  => (is => 'ro', isa => 'Bool', default => 0);
has 'mark'      => (is => 'rw', isa => 'Bool', default => 0);
has 'frozen'    => (is => 'rw', isa => 'Bool', default => 0);
has 'data'      => (is => 'rw', isa => 'Any',  default => q{},
		    trigger => sub{ my($self, $new) = @_; $self->datagroup($new->group) if $new});
has 'datagroup' => (is => 'rw', isa => 'Str',  default => q{});
has 'trouble'   => (is => 'rw', isa => 'Str',  default => q{});


use Demeter::Mode;
use vars qw($mode);
$mode = Demeter::Mode -> instance;
has 'mode' => (is => 'rw', isa => 'Demeter::Mode', default => sub{$mode});
$mode -> iwd(&Cwd::cwd);

###$SIG{__WARN__} = sub {die(Demeter->_ansify($_[0], 'warn'))};
###$SIG{__DIE__}  = sub {die(Demeter->_ansify($_[0], 'die' ))};


use Demeter::Config;
use vars qw($config);
$config = Demeter::Config -> new;

sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

sub alldone {
  my ($self) = @_;
  $self->remove;
  return $self;
};
sub remove {
  my ($self) = @_;
  $self->mo->remove($self) if (defined($self) and ref($self) =~ m{Demeter});;
  return $self;
};

use Demeter::Plot;
use vars qw($plot);
$plot = Demeter::Plot -> new() if not $mode->plot;
$plot -> screen_echo(0);

$Gnuplot_exists = ($plot->is_windows) ? 0 : (eval "require Graphics::GnuplotIF");
use Demeter::StrTypes qw( Empty
			  IfeffitCommand
			  IfeffitFunction
			  IfeffitProgramVar
			  Window
			  PathParam
			  Element
			  Edge
			  FeffCard
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
			  TemplateProcess
			  TemplateFit
			  TemplatePlot
			  TemplateFeff
			  TemplateAnalysis
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

#use Demeter::Templates;

sub import {
  my ($class, @pragmata) = @_;
  strict->import;
  warnings->import;
  #Ifeffit->import;

  ##print join(" ", $class, caller), $/;
 PRAG: foreach my $p (@pragmata) {
    $plot -> plot_with($1),        next PRAG if ($p =~ m{:plotwith=(\w+)});
    if ($p =~ m{:ui=(\w+)}) {
      $mode -> ui($1);
      #import Demeter::Carp if ($1 eq 'screen');
      next PRAG;
    };
    if ($p =~ m{:template=(\w+)}) {
      my $which = $1;
      $mode -> template_process($which);
      $mode -> template_fit($which);
      #$mode -> template_analysis($which);
      next PRAG;
    };
  };

  foreach my $m (qw(Data Plot Plot/Indicator Config Data/Prj Data/MultiChannel GDS Path VPath SSPath FSPath
		    Fit Fit/Feffit Atoms Feff Feff/External ScatteringPath StructuralUnit)) {
    next if $INC{"Demeter/$m.pm"};
    ##print "Demeter/$m.pm\n";
    require "Demeter/$m.pm";
  };

  $class -> register_plugins;
};

sub register_plugins {
  my ($class) = @_;
  my $here = dirname($INC{"Demeter.pm"});
  my $standard = File::Spec->catfile($here, 'Demeter', 'Plugins');
  require File::Spec->catfile($here, 'Demeter', 'Plugins', 'FileType.pm');
  my @folders = ($standard);
  foreach my $f (@folders) {
    opendir(my $FL, $f);
    foreach my $pm (readdir $FL) {
      next if ($pm !~ m{\.pm\z});
      require File::Spec->catfile($f, $pm);
      my $this = join('::', 'Demeter', 'Plugins', $pm);
      $mode->push_Plugins();
    };
    closedir $FL;
  };

};


sub co {
  return shift->mo->config;
};
sub po {
  return shift->mo->plot;
};
sub mo {
  return $mode;
};
sub dd {
  my ($self) = @_;
  if (not $self->mo->datadefault) {
    $self->mo->datadefault(Demeter::Data->new(group=>'default___',
					      name=>'default___',
					      fft_kmin=>3, fft_kmax=>15,
					      bft_rmin=>1, bft_rmax=>6,
					     ));
  };
  return shift->mo->datadefault;
};
alias config       => 'co';
alias plot_object  => 'po';
alias mode_object  => 'mo';
alias data_default => 'dd';

sub finish {
  my ($self) = @_;
  foreach my $class (qw(Atoms Data Prj Feff Fit GDS Path Plot ScatteringPath VPath StructuralUnit)) {
    foreach my $obj (@{ $self->mo->$class}) {
      $obj->alldone;
    };
  };
};

=for LiteratureReference (clone)
  For the Jews, on the other hand, the apparition of the Double was
  not a foreshadowing of death, but rather a proof that the person to
  whom it appeared had achieved the rank of prophet.  This is the
  explanation offered by Gershom Scholem.  A tradition included in the
  Talmud tells the story of a man, searching for God, who met
  himself.
                                Jorge Luis Borges
                                The Book of Imaginary Beings

=cut

## return a new object initialized to the values of $self.  @arguments
## is a list of attributes for the new object
##
## this is a poor example of OO -- there is too much downward
## reference to derived objects.  boo!

sub clone {
  my ($self, @arguments) = @_;

  my $new = ref($self) -> new();
  my %hash = $self->all;
  delete $hash{group};
  $new -> set(%hash);
  $new -> set(@arguments);

  ## the cloned object needs its own group name
  #$new->group($self->_get_group());

  return $new;
};


sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
sub location {
  my ($self) = @_;
  return identify_self();
};

sub identify {
  my ($self, $full) = @_;
  $full ||= 0;
  my $string = sprintf("Demeter %s, %s", $self->version, $self->copyright);
  #if ($full) {};
  return $string;
};
sub version {
  my ($self) = @_;
  return $VERSION
};
sub copyright {
  my ($self) = @_;
  #return "copyright " . chr(169) . " 2006-2010 Bruce Ravel";
  return "copyright 2006-2010 Bruce Ravel";
};
sub hashes {
  my ($self) = @_;
  my $hashes = "###__";
  return $hashes;
};

sub yesno {
  my ($self, $attribute) = @_;
  my $value = (any {$attribute eq $_} $self->meta->get_attribute_list)
    ? $self->is_true($self->$attribute) # is an attribute t/f?
      : $self->is_true($attribute); # is this word t/f?
  #my $value = $self->is_true($self->$attribute);
  return ($value) ? 'yes' : 'no';
};
sub truefalse {
  my ($self, $attribute) = @_;
  my $value = (any {$attribute eq $_} $self->meta->get_attribute_list)
    ? $self->is_true($self->$attribute) # is an attribute t/f?
      : $self->is_true($attribute); # is this word t/f?
  return ($value) ? 'true' : 'false';
};
sub onezero {
  my ($self, $attribute) = @_;
  my $value = (any {$attribute eq $_} $self->meta->get_attribute_list)
    ? $self->is_true($self->$attribute) # is an attribute t/f?
      : $self->is_true($attribute); # is this word t/f?
  #my $value = $self->is_true($self->$attribute);
  return ($value) ? '1' : '0';
};
sub is_true {
  my ($self, $value) = @_;
  return 1 if ($value =~ m{^[ty]}i);
  return 0 if ($value =~ m{^[fn]}i);
  return 0 if (($value =~ m{$NUMBER}) and ($value == 0));
  return 1 if ($value =~ m{$NUMBER});
  return 0;
};

## organize obtaining a unique group name
sub _get_group {
  my ($self) = @_;
  my $propose = random_string('ccccc');
  while ($seen_group{$propose}) {
    $propose = random_string('ccccc');
  };
  ++$seen_group{$propose};
  return $propose;
};


## -------- Mode accessor methods

## return undef for an undefined mode
sub get_mode {
  my ($self, @which) = @_;
  my $mode = $self->mo;
  my @val;
  foreach my $w (@which) {             ##     vvvvvvv    wow, that works!
    $mode->meta->has_method($w) ? push @val, $mode->$w
                                : push @val, undef;
  };
  return wantarray ? @val : $val[0];
};

sub set_mode {
  my ($self, @which) = @_;
  my $mode = $self->mo;
  my %which = @which; ## coerce the group list to a hash for convenience
  foreach my $k (keys %which) {
    next if not $mode->meta->has_method($k);
    #print ">>>>>>> $k   $which{$k}\n";
    $mode -> $k($which{$k});
  };
  1;
};


sub plot_with {
  my ($self, $backend) = @_;
  $backend = lc($backend);
  if (! is_Plotting($backend)) {
    carp("'$backend' is not a valid plotting backend for Demeter -- reverting to pgplot\n\n");
    $backend = 'pgplot';
  };
  if ((not $Gnuplot_exists) and (lc($backend) eq 'gnuplot')) {
    carp("The gnuplot backend is not available -- reverting to pgplot\n\n");
    $backend = 'pgplot';
  };
  $self->po->alldone;
  $self->mo->template_plot($backend);

  my @atts = $self->po->clonable; # preserve parameter values when switching plotting backends
  my @vals = $self->po->get(@atts);
  my @to_set = zip(@atts, @vals);

  my $old_plot_object = $self -> mo -> plot;
 SWITCH: {
    ($backend eq 'pgplot') and do {
      $old_plot_object->DEMOLISHALL if $old_plot_object;
      $self -> mo -> plot(Demeter::Plot->new);
      last SWITCH;
    };

    ($backend eq 'singlefile') and do {
      $old_plot_object->DEMOLISHALL if $old_plot_object;
      require Demeter::Plot::SingleFile;
      $self -> mo -> plot(Demeter::Plot::SingleFile->new);
      $self -> dd -> standard;
      last SWITCH;
    };

    ($backend eq 'gnuplot') and do {
      $old_plot_object->remove;
      $old_plot_object->DEMOLISHALL if $old_plot_object;
      $self -> mo -> external_plot_object( Graphics::GnuplotIF->new );
      require Demeter::Plot::Gnuplot;
      $self -> mo -> plot( Demeter::Plot::Gnuplot->new() );
      last SWITCH;
    };
  };
  $self -> po -> set(@to_set);
};

## the type constraints aren't working as I expect...?
sub template_set {
  my ($self, $which) = @_;
  my $template_regexp = $opt->list2re(qw(demeter ifeffit iff_columns feffit));
  if ($which !~ m{$template_regexp}) {
    carp("$which is not a valid template set, using ifeffit.\n\n");
    return $self;
  };
  $self -> mo -> template_process($which);
  $self -> mo -> template_fit($which);
  #$self -> mode -> template_analysis($which);
  return $self;
};

sub reset_path_indeces {
  my ($self) = @_;
  $self -> mo -> pathindex(1);
  return $self;
};

## -------- introspection methods


## pushed   Index parent sp    fft_pcpath is_mc
## down into override methods in extended classes
sub all {
  my ($self) = @_;
  my @keys   = map {$_->name} grep {$_->name !~ m{\A(?:data|plot|plottable|pathtype|mode)\z}} $self->meta->get_all_attributes;
  my @values = map {$self->$_} @keys;
  my %hash   = zip(@keys, @values);
  return %hash;
};

sub get_params_of {
  my ($self) = @_;
  return $self->meta->get_attribute_list;
};

sub matches {
  my ($self, $regexp, $attribute) = @_;
  $attribute ||= 'name';
  return 1 if ($self->$attribute =~ m{$regexp});
  return 0;
};

sub add_trouble {		# |-separated list of trouble codes, see Demeter::Fit::Sanity
  my ($self, $new) = @_;
  my $tr = $self->trouble;
  if (not $tr) {
    $self->trouble($new);
  } else {
    $self->trouble($tr . '|' . $new);
  };
  return $self;
};

sub translate_trouble {
  my ($self, $trouble) = @_;
  return q{} if (ref($self) !~ m{(?:Data|Fit|GDS|Path)\z});
  my $obj = (ref($self) =~ m{Data}) ? 0
          : (ref($self) =~ m{Path}) ? 1
          : (ref($self) =~ m{GDS})  ? 2
          : (ref($self) =~ m{Fit})  ? 3
	  :                          -1;
  return q{} if ($obj == -1);

  my $parser = Pod::POM->new();
  my $pom = $parser->parse($INC{'Demeter/Fit/Sanity.pm'});

  my $sections = $pom->head1();
  my $troubles_section;
  foreach my $s (@$sections) {
    next unless ($s->title() eq 'TROUBLE REPORTING');
    $troubles_section = $s;
    last;
  };

  my $text = q{};
  my ($pp, $token) = (q{}, q{});
  foreach my $item ($troubles_section->head2->[$obj]->over->[0]->item) { # ick! Pod::POM is confusing!
    my $this = $item->title;
    my $match = $trouble;
    ($pp, $token) = (q{}, q{});
    if ($trouble =~ m{_}) {
      ($match, $pp, $token) = split(/_/, $trouble);
    };
    if ($this =~ m{$match}) {
      my $content = $item->content();
      $content =~ s{\n}{ }g;
      $content =~ s{\s+\z}{};
      ## write a sensible message when exceeding ifeffit's compiled in
      ## limits on things
      if ($content =~ m{\((\&\w+)\)}) {
	my $var = $1;
	my $subst = Ifeffit::get_scalar($var);
	$content =~ s{$var}{$subst};
      };
      $text = $content;
    };
  };
  $text =~ s{C<\$pp>}{$pp};
  $text =~ s{C<\$token>}{$token};
  $text =~ s{C<([^>]*)>}{$1}g;
  undef $parser;
  undef $pom;
  return $text || $self->trouble;
};

## -------- serialization tools
sub serialization {
  my ($self) = @_;
  my %hash = $self->all;
  return YAML::Tiny::Dump(\%hash);
};

sub serialize {
  my ($self, $fname) = @_;
  open my $F, '>'.$fname;
  print $F $self->serialization;
  close $F;
  return $self;
};
sub deserialize {
  my ($self, $fname) = @_;
  my $r_args = YAML::Tiny::LoadFile($fname);
  $self->set(@$r_args);
  return $self;
};
alias freeze => 'serialize';
alias thaw   => 'deserialize';



##-----------------------------------------------------------------
## basic ifeffit chores, import data, FTs

=for LiteratureReference (template)
  In time, the locution 'iungentur iam grypes equis', or "cross
  Gryphons with horses," became a common saying; in the early
  sixteenth century, Ludovico Ariosto recalled the phrase, and
  invented the Hippogriff.  Eagle and lion commingle in the Gryphon of
  the ancients; in the Ariostan Hippogriff it is horse and Gryphon --
  a second degree monster, or second degree feat of imagination.
                               Jorge Luis Borges
                               The Book of Imaginary Beings

=cut


## common supplied hash elements: filename, kweight, titles, plot_object
sub template {
  my ($self, $category, $file, $rhash) = @_;

  my $data     = $self->data;
  my $pf       = $self->mo->plot;
  my $config   = $self->mo->config;
  my $fit      = $self->mo->fit;
  my $standard = $self->mo->standard;
  my $theory   = $self->mo->theory;
  my $path     = $self->mo->path;

  my $tmpl = File::Spec->catfile(dirname($INC{"Demeter.pm"}),
				 "Demeter",
				 "templates",
				 $category,
				 $self->get_mode("template_$category") || q{xxx},
				 "$file.tmpl");
  if (not -e $tmpl) {		# fall back to ifeffit/pgplot template
    my $set = ($category eq 'plot') ? "pgplot" :
              ($category eq 'feff') ? "feff6"  :
              ($category eq 'test') ? 'test'   :
                                      "ifeffit";
    $tmpl = File::Spec->catfile(dirname($INC{"Demeter.pm"}),
				"Demeter", "templates", $category, $set, "$file.tmpl");
  };
  croak("Unknown Demeter template file: group $category; type $file; $tmpl") if (not -e $tmpl);

  my $template = Text::Template->new(TYPE => 'file', SOURCE => $tmpl)
    or die "Couldn't construct template: $Text::Template::ERROR";
  $rhash ||= {};

  #my $compartment = new Safe;
  my $string = $template->fill_in(HASH => {S  => \$self,
					   D  => \$data,
					   P  => \$pf,
					   C  => \$config,
					   F  => \$fit,
					   DS => \$standard,
					   T  => \$theory,
					   PT => \$path,
					   %$rhash},
				  PACKAGE => "Demeter::Templates",
				  #SAFE => $compartment,
				 );
  $string ||= q{};
  $string =~ s{^\s+}{};		      # remove leading white space
  $string =~ s{\n(?:[ \t]+\n)+}{\n};  # regularize white space between blocks of text
  $string =~ s{\s+$}{\n};	      # remove trailing white space
  $string =~ s{<<nl>>}{\n}g;	      # convert newline token into a real newline
  $string =~ s{<<( +)>>}{$1}g;	      # convert white space token into real white space
  return $string;
};

sub pause {};
alias sleep => 'pause';

__PACKAGE__->meta->make_immutable;
1;


#   my $opt  = Regexp::List->new;
#   my %regexp = (
# 		commands   => $opt->list2re(qw{ f1f2 bkg_cl chi_noise color comment correl cursor
#                                                 def echo erase exit feffit ff2chi fftf fftr
#                                                 get_path guess history linestyle load
#                                                 log macro minimize newplot path pause plot
#                                                 plot_arrow plot_marker plot_text pre_edge print
#                                                 quit random read_data rename reset restore
#                                                 save set show spline sync unguess window
#                                                 write_data zoom } ), # }),
# 		function   => $opt->list2re(qw{abs min max sign sqrt exp log
#    		                               ln log10 sin cos tan asin acos
#    		                               atan sinh tanh coth gamma loggamma
#    		                               erf erfc gauss loren pvoight debye
#    		                               eins npts ceil floor vsum vprod
#    		                               indarr ones zeros range deriv penalty
#   		                               smooth interp qinterp splint eins debye } ), # }),
# 		program    => $opt->list2re(qw(chi_reduced chi_square core_width correl_min
#                                                cursor_x cursor_y dk dr data_set data_total
#                                                dk1 dk2 dk1_spl dk2_spl dr1 dr2 e0 edge_step
#                                                epsilon_k epsilon_r etok kmax kmin kmax_spl
#                                                kmax_suggest kmin_spl kweight kweight_spl kwindow
#                                                n_idp n_varys ncolumn_label nknots norm1 norm2
#                                                norm_c0 norm_c1 norm_c2 path_index pi pre1 pre2
#                                                pre_offset pre_slope qmax_out qsp r_factor rbkg
#                                                rmax rmax_out rmin rsp rweight rwin rwindow toler)),
# 		window     => $opt->list2re(qw(kaiser-bessel hanning welch parzen sine gaussian)),
# 		pathparams => $opt->list2re(qw(e0 ei sigma2 s02 delr third fourth dphase)),
# 		element    => $opt->list2re(qw(h he li be b c n o f ne na mg al si p s cl ar
#                                                k ca sc ti v cr mn fe co ni cu zn ga ge as se
#                                                br kr rb sr y zr nb mo tc ru rh pd ag cd in sn
#                                                sb te i xe cs ba la ce pr nd pm sm eu gd tb dy
#                                                ho er tm yb lu hf ta w re os ir pt au hg tl pb
#                                                bi po at rn fr ra ac th pa u np pu)),
# 		edge      => $opt->list2re(qw(k l1 l2 l3)),
# 		modes     => $opt->list2re(keys %mode),
# 		feffcards => $opt->list2re(qw(atoms control print title end rmultiplier
#                                               cfaverage overlap afolp edge hole potentials
#                                               s02 exchange folp nohole rgrid scf unfreezef
#                                               interstitial ion spin exafs xanes ellipticity ldos
#                                               multipole polarization danes fprime rphases rsigma
#                                               tdlda xes xmcd xncd fms debye rpath rmax nleg pcriteria
#                                               ss criteria iorder nstar debye corrections sig2)),
# 		separator => '[ \t]*[ \t=,][ \t]*',
# 		clamp     => $opt->list2re(qw(none slight weak medium strong rigid)),
# 		config    => $opt->list2re(qw(type default minint maxint options
# 					      units onvalue offvalue)),
# 		stats     => $opt->list2re(qw(n_idp n_varys chi_square chi_reduced 
# 					      r_factor epsilon_k epsilon_r data_total
# 					      happiness)),
# 		atoms_lattice  => $opt->list2re(qw(a b c alpha beta gamma space shift)),
# 		atoms_gas      => $opt->list2re(qw(nitrogen argon helium krypton xenon)),
# 		atoms_obsolete => $opt->list2re(qw(output geom
# 						   fdat nepoints xanes modules
# 						   message noanomalous self i0
# 						   mcmaster dwarf reflections refile
# 						   egrid index corrections
# 						   emin emax estep egrid qvec dafs
# 						  )),
# 		spacegroup     => $opt->list2re(qw(number full new_symbol thirtyfive
# 						   schoenflies bravais shorthand positions
# 						   shiftvec npos)),
# 		plotting_backends => $opt->list2re(qw(pgplot gnuplot)),
# 		data_parts => $opt->list2re(qw(fit bkg res)),
# 	       );


=head1 NAME

Demeter -  An object oriented EXAFS data analysis system using Ifeffit

=head1 VERSION

This documentation refers to Demeter version 0.4.0

=head1 SYNOPSIS

Import Demeter components into your program:

  use Demeter;

This will import all Demeter components into your program.  The
components are:

   Atoms Data Path VPath Fit Feff  and so on...

Using Demeter automatically turns on L<strict> and L<warnings>.

=head1 EXAMPLE

Here is a complete script for analyzing copper data:

  #!/usr/bin/perl
  use Demeter;  # automatically turn on L<strict> and L<warnings>
  #
  ## make a Data object
  my $dobject = Demeter::Data -> new({group => 'data0',});
  #
  print "Sample fit to copper data using Demeter " . $dobject->version . "\n";
  $dobject->set_mode(screen=>1, ifeffit=>1);
  #
  ## set the processing and fit parameters
  $dobject ->set(file      => "example/cu/cu10k.chi",
		 name      => 'My copper data',
                 is_chi    => 1,
		 fft_kmin  => 3,    fft_kmax  => 14,
		 bft_rmin  => 1,    bft_rmax  => "4.3",
		 fit_space => 'K',
		 fit_k1    => 1,    fit_k3    => 1,
	        );
  #
  ## GDS objects for isotropic expansion + correlated Debye model
  my @gdsobjects =
    (Demeter::GDS ->
        new(type => 'guess', name => 'alpha', mathexp => 0),
     Demeter::GDS ->
        new(type => 'guess', name => 'amp',   mathexp => 1),
     Demeter::GDS ->
        new(type => 'guess', name => 'enot',  mathexp => 0),
     Demeter::GDS ->
        new(type => 'guess', name => 'theta', mathexp => 500),
     Demeter::GDS ->
        new(type => 'set',   name => 'temp',  mathexp => 300),
     Demeter::GDS ->
        new(type => 'set',   name => 'sigmm', mathexp => 0.00052),
    );
  #
  ## Path objects for the first 5 paths in copper (3 shell fit)
  my @pobjects = ();
  foreach my $i (0 .. 4) {
    $pobjects[$i] = Demeter::Path -> new();
    $pobjects[$i ]->set(data     => $dobject,
		        folder   => 'example/cu/',
		        file     => sprintf("feff%4.4d.dat", $i+1),
		        s02      => 'amp',
		        e0       => 'enot',
		        delr     => 'alpha*reff',
		        sigma2   => 'debye(temp, theta) + sigmm',
		       );
  };
  #
  ## Fit object: collection of GDS, Data, and Path objects
  my $fitobject = Demeter::Fit -> new(gds   => \@gdsobjects,
				      data  => [$dobject],
				      paths => \@pobjects,
				     );
  ## do the fit (or the sum of paths)
  $fitobject -> fit;
  #
  ## plot the data + fit + paths in a space
  $dobject -> po -> set(plot_data => 1, plot_fit  => 1,
                        plot_res  => 0, plot_win  => 1,);
  foreach my $obj ($dobject, @pobjects,) {
    $obj -> plot("r");
  };
  #
  ## save the results of the fit and write a log file
  $dobject -> save("fit", "cufit.fit");
  my ($header, $footer) = ("Simple fit to copper data\n", q{});
  $fitobject -> logfile("cufit.log", $header, $footer);

This example starts by defining each of the data objects.  There is
one data object, 5 path objects, and 6 GDS objects and these are
gathered into one fit object.  The C<set_mode> method defines how the
Ifeffit commands generated will be dispatched -- in this case, to the
screen and to the Ifeffit process.  After the fit is defined by
creating the Fit object, the fit is preformed calling the C<fit>
method.  This performs the fit; retrieves the best fit values, error
bars, and correlations; and evaluates all path parameters.  Then plots
are made, the results of the fit are saved as an ASCII data file, and
a log file is written.

When a Demeter script exits, care is taken to clean up all temporary
file that may have been generated during the run.

=head1 DESCRIPTION

This module provides an object oriented interface to the EXAFS data
analysis capabilities of the popular and powerful Ifeffit package.
Mindful that the Ifeffit API involves streams of text commands, this
package is, at heart, a code generator.  Many methods of this package
return text.  All actual interaction with Ifeffit is handled through a
single method, C<dispose>, which is described below.  The internal
structure of this package involves accumulating text in a scalar
variable through successive calls to the various code generating
methods.  This text is then disposed to Ifeffit, to a file, or
elsewhere.  The outward looking methods, as shown in the example
above, organize all of the complicated interactions of your data with
Ifeffit.

This package is aimed at many targets.  It can be the back-end of a
graphical data analysis program, providing the glue between the
on-screen representation of the fit and the actual command executed by
Ifeffit.  It can be used for one-off data analysis chores -- indeed
most of the examples that come with the package can be reworked into
useful one-off scripts.  It can also be the back-end to sophisticated
data analysis chores such as high-throughout data processing and
analysis or complex physical modeling.

Demeter is a parent class for the objects that are directly
manipulated in any real program using Demeter.  These are
several subclasses:

=over 4

=item L<Demeter::Data>

The Data object used to import mu(E) or chi(k) data from a column data
file or an Athena project file.  It organizes parameters for Fourier
transforms, fitting range, and other aspects of the fit.

=item L<Demeter::Data::Prj>

This object is used to interact with the records of an Athena project
file.

=item L<Demeter::Path>

The Path object used to define a path for use a fit and to set math
expressions for its path parameters.  This object is typically
associated with a F<feffNNNN.dat> file from a Feff calculation.  That
F<feffNNNN.dat> may have been generated by Feff in the normal manner
or via the methods of Demeter's Feff object.

=item L<Demeter::VPath>

A virtual path object is a collection of Path objects which can be
summed and plotted as a summation.

=item L<Demeter::SSPath>

This is a way of generating an arbitrary sungle scattering path at an
arbitrary distance using the potentials of a Feff object.

=item L<Demeter::GDS>

The object used to define a guess, def or set parameter for use in the
fit.  This is also used to define restraints and a few other kinds of
parameters.

=item L<Demeter::Fit>

This object is the collection of Data, Path, and GDS objects which
compromises a fit.

=item L<Demeter::Atoms>

A crystallography object which is used to generate the structure data
for a Feff object.

=item L<Demeter::Feff>

A object defining the contents of a Feff calculation and providing
methods for running parts of Feff.  This object provide a flexible
interface to Feff which is intended to address many of Feff's
shortcomings and obviate the need to interact directly with Feff via
its input file.

=item L<Demeter::ScatteringPath>

An object defining a scattering path from a Feff object.  This may be
linked to a Path object used in a fit.

=item L<Demeter::Plot>

The object which controls how plots are made from the other Demeter
objects.  As described in its document, access to this object is
provided in a consistent manner and is available to all other Demeter
objects.

=item L<Demeter::Config>

The object which controls configuraton of the the Demeter system and
its components.  This is a singleton object (i.e. only one exists in
any instance of Demeter).  As described in its document, access to
this object is provided in a consistent manner and is available to all
other Demeter objects.

=back

Each of these objects is implemented using Moose, the amazing
meta-object system for Perl.  Although Moose adds some overhead at
start-up for any application using Demeter, its benefits are legion.
See L<Moose> and L<http://www.iinteractive.com/moose> for more
information.

=head1 PRAGMATA

Demeter pragmata are ways of affecting the run-time behavior of a
Demeter program by specfying that behavior at compile-time.

     use Demeter qw(:plotwith=gnuplot)
   or
     use Demeter qw(:ui=screen)
   or
     use Demeter qw(:plotwith=gnuplot :ui=screen)

=over 4

=item C<:plotwith=XX>

Specify the plotting backend.  The default is C<pgplot>.  The other
option is C<gnuplot>.  A C<demeter> option will be available soon for
generating perl scripts which plot.

This can also be set during run-time using the C<plot_with> method
during run-time.

=item C<:ui=XX>

Specify the user interface.  Currently the only option is C<screen>.
Setting the UI to screen does two things:

=over 4

=item 1.

Uses L<Demeter::UI::Screen::Interview> as a role for the Fit
object.  This imports the C<interview> method for use with the Fit
object, allowing you to interact with the results of a fit in a simple
manner at the console.

=item 2.

Uses L<Term::Twiddle> to provide some visual feedback on the screen
while the fit or summation is happening.  This adds no real
functionality, but serves to make it clear that I<something> is
happening during the potentially lengthy fit.

=back

The interview method uses L<Term::ReadLine>.  This is made into a
pragmatic interaction in Demeter in case you want to use
L<Term::ReadLine> in some other way in your program.  Not importing
the interview method by default allows you to avoid this error message
from Term::ReadLine when you are using it in some other capacity:
C<Cannot create second readline interface, falling back to dumb.>

Also L<Term::Twiddle> is not imported until it is needed, allowing
this dependeny to be relaxed from a requirement to a suggestion.

Future UI options might include C<tk>, C<wx>, or C<rpc>.

=item C<:template=XX>

Specify the template set to use for data processing and fitting
chores.  The options are

=over 4

=item C<ifeffit>

The default -- a concise set of command tempates for Ifeffit 1.2.10.

=item C<iff_columns>

An alternate set of command teampates for Ifeffit 1.2.10 which attempt
to line everything up in easy-to-read columnar formatting.

=item C<feffit>

Generate text suitable for the old Feffit program

=item C<demeter>

Generate text in the form of valid perl using Demeter.  This is
intended to allow a GUI to export a valid demeter script.  Note: this
template set has not been written yet.

=back

In the future, a template set will be written when Ifeffit 2 becomes
available.

These can also be set during run-time using the C<set_mode> method -- see
L<Demeter::Mode>.

=back


=head1 METHODS

An object of this class represents a part of the problem of EXAFS data
processing and analysis.  That component might be data, a path from
Feff, a parameter, a fit, or a plot.  Moose provides a sane, solid,
and consistent way of interacting with these objects.

Not every method shown in the example above is described here.  You
need to see the subclass documentation for methods specific to those
subclasses.

=head2 Constructor and accessor methods

These are the basic methods for constructing objects and accessing
their attributes.

=over 4

=item C<new>

This the constructor method.  It builds and initializes new objects.

  use Demeter;
  my $data_object = Demeter::Data -> new;
  my $path_object = Demeter::Path -> new;
  my $gds_object  = Demeter::GDS  -> new;
    ## and so on ...

New can optionally take an array of attributes and values with the
same syntax as the C<set> method.

=item C<clone>

This method clones an object, returning the reference to the new object.

  $newobject = $oldobject->clone(@new_arguments);

Cloning returns the reference and sets all attributes of the new
object to the values for the old object.  The optional argument is a
reference to a hash of those attributes which you wish to change for
the new object.  Passing this hash reference is equivalent to cloning
the object, then calling the C<set> method on the new object with that
hash reference.

=item C<set>

This method sets object attributes.  This is a convenience wrapper
around the accessors provided by L<Moose>.

  $data_object -> set(fft_kmin=>3.1, fft_kmax=>12.7);
  $path_object -> set(file=>'feff0123.dat', s0=>'amp');
  $gds_object  -> set(Type=>'set', name=>'foo', mathexp=>7);

The set method of each subclass behaves slightly differently for each
subclass in the sense that error checking is performed appropriately
for each subclass.  Each subclass takes a hash reference as its
argument, as shown above.  An exception is thrown is you attempt to
C<set> an undefined attribute for every subclass except for the Config
subclass.

The argument are simply a list (remember that the =E<gt> symbol is
sytactically equivalent to a comma). The following are equivalent:

    $data_object -> set(file => "my.data", kmin => 2.5);
  and
    @atts = (file => "my.data", kmin => 2.5);
    $data_object -> set(@atts);

The sense in which this is a convenience wrapper is in that the
following are equivalent:

    $data_object -> set(fft_kmin=>3.1, fft_kmax=>12.7);
  and
    $data_object -> fft_kmin(3.1);
    $data_object -> fft_kmax(12.7);

The latter two lines use the accessors auto-generated by Moose.  With
Moose, accessors to attributes have names that are the same as the
attributes.  The C<set> method simply loops over its arguments, calling
the appropriate accessor.


=item C<get>

This is the accessor method.  It "does the right thing" in both scalar
and list context.

  $kmin = $data_object -> get('fft_kmin');
  @window_params = $data_object -> get(qw(fft_kmin fft_kmax fft_dk fft_kwindow));

See the documentation for each subclass for complete lists of what
attributes are available for each subclass.  An exception is thrown if
you attempt to C<get> an undefined attribute for all subclasses except
for the Config subclass, which is specifically intended to store
user-defined parameters.

=item C<serialize>

Returns the YAML serialization string for the object.  See the Fit
objects serialize method for complete details of serialization of a
fitting model.

=item C<matches>

This is a gneeralized way of testing to see if an attribute value
matches a regular expression.  By default it tries to match the
supplied regular expression again the C<name> attribute.

  $is_match = $object->matches($regexp);

You can supply a second argument to match against some other
attribute.  For instance, to match the C<group> attribute against a
regular expression:

  $group_matches = $object->matches($regexp, 'group');

=back

=head2 Data processing methods

A system is built into Demeter for keeping track of the state of your
objects.  It is, therefore, rarely necessary to explicitly invoke the
data processing methods.  If you call the C<plot>, Demeter will call
the C<read_data>, C<normalize>, C<fft>, and C<bft> methods as needed
to correctly make the plot.  As you change the attributes of the Data
object, Demeter will keep track of which data processing stages need
to be redone.  Consequently, the C<plot> method may be the only data
processing method you ever need to call.

This section, then, is included in the documentation for the sake of
completeness and to give you a sense of what Demeter is doing behind
the scenes when you ask it to make a plot.

These methods call the corersponding code generating methods then
dispose of that code.  The code generators are not explicitly
documented and should rarely be necessary to call directly.

=over 4

=item C<read_data>

This method returns the Ifeffit command for importing data into
Ifeffit

  $command = $data_object->read_data;

This method is more commonly used for Data objects.  Calling this
method on a Path object will import the raw C<feffNNNN.dat> file.  See
the C<write_path> method of the Path subclass for importing a
C<feffNNNN.dat> file and turning it into chi(k) data.

=item normalization and background removal

See L<Demeter::Data::Mu>.

=item C<fft>

This method performs a forward Fourier transform on your chi(k) data
using parameters that have been established using the C<set> method.

  $object -> fft;

If the data need to be imported, they will be automatically.

=item C<bft>

This method performs a backward Fourier transform on your chi(R) data
using parameters that have been established using the C<set> method.

  $object -> bft;

If the data need to be imported or forward transformed, they will be
automatically.

=back

=head2 I/O methods

=over 4

=item C<plot>

This method plots your data in the indicated space, where the space is
one of E, k, R, or q.  The details of how that plot is made are
determined by the Plot object.

  $object -> plot($space);

If the data need to be imported, forward transformed, or backward
transformed, they will be automatically.

Only Data and Path objects can be plotted.  Attempting to plot other
object types will throw and exception.

=item C<save>

This saves data or a path as a column data file.

   $command = $object -> save($argument);

The types of saved file, indicated by the argument, are

=over 4

=item xmu

7 columns: energy, mu(E), bkg(E), pre-edge line, post-edge line,
derivative of mu(E), second derivative of mu(E).

=item norm

7 columns: energy, norm(E), bkg(E), flattened mu(E), flattened
background, derivative of norm(E), second derivative of norm(E).

=item chi

6 or 7 columns: k, chi(k), window, k*chi(k), k^2*chi(k), k^3*chi(k).
If an arbitrary k-weighting is used, an additional column with that
k-weighting will be written.

=item R

6 columns: R, real part, imaginary part, magnitude, phase, R window

=item q

7 columns: q, real part, imaginary part, magnitude, phase, k window,
k-weighted chi(k) using the k-weighting of the Fourier transform.
This last column can be plotted with the real part to make a kq plot.

=item fit

6 or 7 columns: k, chi(k), fit(k), residual, background (if fitted),
window.

=back

=back

=head2 C<dispose>

This method is used to dispatch Ifeffit commands by hand.  It is used
internally by many of the methods typically invoked in your programs.

  $object -> dispose($ifeffit_command);

See the document page for L<Demeter::Dispose> for complete details.

=head2 Operation modes

There are a few attributes of a Demeter application that apply to all
Demeter objects in use in that application.  Most of these attributes
have to do with how the command generated by the various Demeter
methods get disposed of by the C<dispose> method.  The special Mode
subclass keeps track of these global attributes.  The Mode methods
described below are the way you will typically intract with the Mode
object.

Here is a list of all these global attributes:

=over 4

=item ifeffit

This is a boolean attribute.  When true, the C<dispose> method sends commands
to the Ifeffit process.  By default this is true.

=item screen

This is a boolean attribute.  When true, the C<dispose> method sends
commands to STDOUT, which is probably displayed of the screen in a
terminal emulator.  This is very handy for examining the details of
how Demeter is interacting with Ifeffit, either for understanding
Ifeffit's behavior or for debugging Demeter.  By default this is
false.

=item file

When true, the C<dispose> method sends commands to a file.  The true
value of this attribute is interpreted as the file name.  The file is
opened and closed each time C<dispose> is called.  Therefore it is
probably prudent to give this attribute a value starting with an open
angle bracket, such as ">filename".  This will result in commands
being appended to the end of t he named file.  Note also that you will
need to unlink the file at the beginning of your script if you do not
want your commands appended to the end of an existing file.  (That is,
indeed, awkward behavior wich needs to be improved in future versions
of Demeter.) By default this is false.

=item buffer

When true, the C<dispose> method stores commands in a memory buffer.
The true value of this attribute can either be a reference to a scalar
or a reference to an array.  If the value is a scalar reference, the
commands will be concatinated to the end of the scalar.  If the value
is an array reference, each command line (where a line is terminated
with a carriage return) will become an entry in the array.  (A future
improvement would be to allow this to take a reference to an arbitrary
object so that the commands can beprocessed in some domain-specific
manner.  By default this is false.

=item plot

This attribute is the reference to the current Plot object.  A plot
object is created as the Demeter package is loaded into your program,
so it is rarely necessary to set this attribute or to create a Plot
object by hand.  However, if you need to maintain two or more Plot
objects, this attribute is the mechanism for controlling which gets
used when plots are made.

=item config

This attribute is the reference to the singletoin Config object, which
serves two puproses.  It is Demeter's mechanism for handling
system-wide and user configuration.  It is also the tool provided for
user-defined parameters.  This latter capacity is used extensively in
many of the data processing chores for transmitting particular
parameters to the template files used to generate Ifeffit and plotting
commands.

=item template_process

Set the template set for data processing.  Currently in the
distribution are C<feffit>, C<ifeffit> and C<iff_columns>.

=item template_fit

Set the template set for data analysis.  Currently in the
distribution are C<feffit>, C<ifeffit> and C<iff_columns>.

=item template_plot

Set the template set for plotting.  Currently in the distribution are
C<pgplot> and C<gnuplot>.

=item template_feff

Set the template set for generating feff files.  Currently in the
distribution are C<feff6>, C<feff7>, and C<feff8>.

=back

The methods for accessing the operation modes are:

=over 4

=item C<set_mode>

This is the method used to set the attributes described above.  Any Demeter
object can call this method.

   $object -> set_mode(ifeffit => 1,
                       screen  => 1,
                       buffer  => \@buffer_array
                      );

See L<Demeter:Dispose> for more details.

=item C<get_mode>

When called with no arguments, this method returns a hash of all attributes
their values.  When called with an argument (which must be one of the
attributes), it returns the value of that attribute.  Any Demeter object can
call this method.

   %hash = $object -> get_mode;
   $value = $object -> get_mode("screen");

See L<Demeter:Dispose> for more details.

=back

=head2 Convenience methods

=over

=item C<co>

This returns the Config object.  This is a wrapper around C<get_mode>
and is intended to be used in a method call chain with any Demeter
object.  The following are equivalent:

  my $config = $data->get_mode("params");
  $config -> set_default("clamp", "medium", 20);

and

  $data -> co -> set_default("clamp", "medium", 20);

The latter involves much less typing!

=item C<po>

This returns the Plot object.  Like the C<co> method, this is a
wrapper around C<get_mode> and is intended to be used in a method call
chain with any Demeter object.

  $data -> po -> set("c9", 'yellowchiffon3');

=item C<mo>

This returns the Mode object.  This is intended to be used in a method
call chain with any Demeter object.

  print "on screen!" if ($data -> mo -> ui eq 'screen');

=item C<dd>

This returns the default Data object.  When a Path object is created,
if it is created without having its C<data> attribute set to an
existing Data object, a new Data object with sensible default values
for all of its attributs is created and stored as the C<datadefault>
attribute of the Mode object.

Path objects always rely on their associated Data objects for plotting
and processing parameters.  So every Path object B<must> have an
associated Data object.  If the C<data> attribute is not specified by
the user, the default Data object will be used.

  print ref($object->dd);
       ===prints===> Demeter::Data

=back

=head2 Utility methods

Here are a number of methods used internally, but which are available
for your use.

=over 4

=item C<hashes>

This returns a string which can be used as a comment character in
Ifeffit.  The idea is that every comment included in the commands
generated by methods of this class use this string.  That provides a
way of distinguishing comments generated by the methods of this class
from other comment lines sent to Ifeffit.  This is a user interface
convenience.

   print $object->hashes, "\n";
       ===prints===> ###___

=item C<group>

This returns a unique five-character string for the object.  For Data
and Path objects, this is used as the Ifeffit group name for this
object.

=item C<name>

This returns a short, user-supplied, string identifying the object.
For a GDS object, this is the parameter name.  For Path and Data
objects, this is the string that will be put in a plot legend.

=item C<data>

Path objects (also VPath and SSPath) are associated with Data objects.
This method returns the reference to the associated Data object.  For
Data objects, this returns a reference to itself.  For other object
types this returns a false value.

=item C<plottable>

This returns a true value if the object is one that can be plotted.
Currently, Data, Path, VPath, and SSPath objects return a true value.
All others return false.

   $can_plot = $object -> plottable;

=back

=head2 Utility methods

Demeter provides a generic mechanism for reporting on errors in a
fitting model.  When using Demeter non-interactively, useful messages
about problems in the fitting model will be written to standard
output.  Critical problems in a non-interactive mode will be cause the
script to croak (see L<Carp>).

In an interactive mode (such as with the Wx interface), the
C<add_trouble> method is used to fill the C<trouble> attribute, which
is inherited by all Demeter objects.  In the default, untroubled
state, an object will have the C<trouble> attribute set to an empty
string (i.e. something logically false).  As problems are found in the
fitting model (see L<Demeter::Fit::Sanity>), the C<trouble> attribute
gets short text strings appended to it.  The list of problems an
object has are separated by pipe characters (C<|>).

See L<Demeter::Fit::Sanity> for a complete description of these
problem codes.  The Fit, Data, Path, and GDS objects each have their
own set of problem codes.


=head1 DIAGNOSTICS

 zip
=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for details about the configuration
system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Template evaluation is a potential security hole in the sense that
someone could put something like C<system 'rm -rf *'> in one of the
templates.  L<Text::Template> supports using a L<Safe> compartment.

=item *

Serialization is incompletely implemented at this time.

=item *

You can switch plotting backends on the fly, but all parameter values
get reset to their defaults.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 VERSIONS

=over 4

=item 0.4.2

Cloning a Feff object now deeply copies the array references in an
overridden clone method.

Added showlegend attribute to Plot object

=item 0.4.1

Now supplying the C<bootstrap> script in an attempt to ease initial
installation.  Also building the DPG with a PL_file at build time.

Fixed a bug setting the Plot object space attribute in quad, stddev,
and variance plots.  Added stddev and variance plots to the merge
example in C<harness>.

=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
