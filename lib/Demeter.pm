package Demeter;  # http://xkcd.com/844/

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

require 5.008;

use version;
our $VERSION = version->new('0.9.11');
use feature "switch";

############################
## Carp
##
#use Demeter::Carp;
#use Carp::Always::Color;
use Carp;
############################

use Cwd;
##use DateTime;
use File::Basename qw(dirname);
use File::Spec;
use Ifeffit;
Ifeffit::ifeffit("\$plot_device=/gw\n") if (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
use List::MoreUtils qw(any minmax zip uniq);
#use Safe;
use Pod::POM;
use Regexp::Assemble;
use String::Random qw(random_string);
use Text::Template;
use Xray::Absorption;
Xray::Absorption->load('elam');

=for LiteratureReference
  Then, spent as they were from all their toil,
  they set out food, the bounty of Ceres, drenched
  in sea-salt, Ceres' utensils too, her mills and troughs,
  and bend to parch with fire the grain they had salvaged,
  grind it fine on stone.
                                Virgil, The Aeneid, 1:209-213

=cut

## why was this needed?
##
# Metaclass definition must come before Moose is used.
#use metaclass (
#	       metaclass   => 'Moose::Meta::Class',
#	       error_class => 'Moose::Error::Confess',
#	      );

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
with 'Demeter::Dispose';
with 'Demeter::Tools';
with 'Demeter::Files';
with 'Demeter::Project';
with 'Demeter::MRU';
use Demeter::Return;
with 'MooseX::SetGet';		# this is mine....
use Demeter::Constants qw($NUMBER $PI);

my %seen_group;
has 'group'     => (is => 'rw', isa => 'Str',     default => sub{shift->_get_group()},
		    trigger => sub{ my($self, $new);
				    ++$seen_group{$new} if (defined($new));
				  });
has 'name'      => (is => 'rw', isa => 'Str',     default => q{});
has 'plottable' => (is => 'ro', isa => 'Bool',    default => 0);
has 'pathtype'  => (is => 'ro', isa => 'Bool',    default => 0);
has 'frozen'    => (is => 'rw', isa => 'Bool',    default => 0);
has 'mark'      => (is => 'rw', isa => 'Bool',    default => 0);
has 'data'      => (is => 'rw', isa => 'Any',     default => q{},
		    trigger => sub{ my($self, $new) = @_; $self->set_datagroup($new->group) if $new});
has 'datagroup' => (is => 'rw', isa => 'Str',     default => q{});
has 'trouble'   => (is => 'rw', isa => 'Str',     default => q{});
has 'sentinal'  => (traits  => ['Code'],
		    is => 'rw', isa => 'CodeRef', default => sub{sub{1}}, handles => {call_sentinal => 'execute',});


use Demeter::Mode;
use vars qw($mode);
$mode = Demeter::Mode -> instance;
has 'mode' => (is => 'rw', isa => 'Demeter::Mode', default => sub{$mode});
$mode -> iwd(&Cwd::cwd);
with 'Demeter::Get';

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
  $self->mo->remove($self) if (defined($self) and ref($self) =~ m{Demeter} and defined($self->mo));
  return $self;
};

sub set_datagroup {
  my ($self, $group) = @_;
  $self->datagroup($group);
};

######################################################################
## conditional features
use vars qw($Gnuplot_exists $STAR_Parser_exists $XDI_exists $PDL_exists $PSG_exists $FML_exists);
$Gnuplot_exists     = eval "require Graphics::GnuplotIF" || 0;
$STAR_Parser_exists = 1;
use STAR::Parser;
$XDI_exists         = eval "require Xray::XDI" || 0;
$PDL_exists         = 0;
$PSG_exists         = 0;
$FML_exists         = eval "require File::Monitor::Lite" || 0;
######################################################################

use Demeter::Plot;
use vars qw($plot);
$plot = Demeter::Plot -> new() if not $mode->plot;
$plot -> toggle_echo(0);
my $backend = $config->default('plot', 'plotwith');
if ($backend eq 'gnuplot') {
  if (Demeter->is_windows) {
    my $message = Demeter->check_exe('gnuplot');
    exit $message if ($message);
  };
  $mode -> template_plot('gnuplot');
  $mode -> external_plot_object( Graphics::GnuplotIF->new(program => $config->default('gnuplot', 'program')) );
  require Demeter::Plot::Gnuplot;
  $mode -> plot( Demeter::Plot::Gnuplot->new() );
};

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
  #print join(" ", $class, caller), $/;

  my @load  = ();
  my @data  = (qw(Data XES Journal Data/Prj Data/Pixel Data/MultiChannel Data/BulkMerge));
  my @heph  = (qw(Data Data/Prj));
  my @fit   = (qw(Atoms Feff Feff/External ScatteringPath Path VPath SSPath ThreeBody FPath FSPath
		  GDS Fit Fit/Feffit StructuralUnit Feff/Distributions));
  my @atoms = (qw(Data Atoms Feff ScatteringPath Path));
  my @anal  = (qw(LCF LogRatio Diff PeakFit PeakFit/LineShape));
  my @xes   = (qw(XES));
  my @plot  = (qw(Plot/Indicator Plot/Style));
  my $colonanalysis = 0;
  my $doplugins     = 0;
  my $none          = 0;

 PRAG: foreach my $p (@pragmata) {
    given ($p) {
      when (m{:plotwith=(\w+)}) { # choose between pgplot and gnuplot
	$plot -> plot_with($1);
      }
      when (m{:ui=(\w+)}) {       # ui-specific functionality (screen is the most interesting one)
	$mode -> ui($1);
	#import Demeter::Carp if ($1 eq 'screen');
      }
      when (m{:template=(\w+)}) { # change template sets
	my $which = $1;
	$mode -> template_process($which);
	$mode -> template_fit($which);
	#$mode -> template_analysis($which);
      }

      ## all the rest of the "pragmata" control what parts of Demeter get imported

      when (':data') {
	@load = @data;
	$doplugins = 1;
      }
      when (':hephaestus') {
	@load = @heph;
	$doplugins = 0;
      }
      when (':fit') {
	@load = (@data, @fit);
      }
      when (':analysis') {
	@load = (@data, @anal);
	$doplugins     = 1;
	$colonanalysis = 1;	# verify PDL before loading PCA
      }
      when (':athena') {
	@load = (@data, @anal, @plot);
	$doplugins     = 0;     # delay registering plugins until after start-up
	$colonanalysis = 1;	# verify PDL before loading PCA
      }
      when (':artemis') {
	@load = (@heph, @fit, 'Plot/Indicator');
      }
      when (':atoms') {
	@load = @atoms;
      }
      when (':all') {
	@load = (@data, @fit, @anal, @xes, @plot);
	$doplugins     = 1;
	$colonanalysis = 1;
      }
      when (':none') {
	@load = ();
	$doplugins     = 0;
	$colonanalysis = 0;
	$none          = 1;
      }
    };
  };
  @load = (@data, @fit, @anal, @xes, @plot) if not @load;
  @load = () if $none;

  foreach my $m (uniq @load) {
    next if $INC{"Demeter/$m.pm"};
    #print join("|", caller, DateTime->now), "  Demeter/$m.pm\n";
    require "Demeter/$m.pm";
  };

  if ($colonanalysis) {
    $PDL_exists = eval "require PDL::Lite" || 0;
    $PSG_exists = eval "require PDL::Stats::GLM" || 0;
  };

  if ($PDL_exists and $PSG_exists) {
    ##print DateTime->now,  "  Demeter/PCA.pm\n";
    require "Demeter/PCA.pm" if not exists $INC{"Demeter/PCA.pm"};
  };
  $class -> register_plugins if $doplugins;
};

sub register_plugins {
  my ($class) = @_;
  my $here = dirname($INC{"Demeter.pm"});
  my $standard = File::Spec->catfile($here, 'Demeter', 'Plugins');
  my $private =  File::Spec->catfile(Demeter->dot_folder, 'Demeter', 'Plugins');
  require File::Spec->catfile($here, 'Demeter', 'Plugins', 'FileType.pm');
  my @folders = ($standard); #, $private);
  foreach my $f (@folders) {
    opendir(my $FL, $f);
    my @pm = grep {m{.pm\z}} readdir $FL;
    closedir $FL;
    foreach my $pm (@pm) {
      require File::Spec->catfile($f, $pm);
      $pm =~ s{\.pm\z}{};
      my $this = join('::', 'Demeter', 'Plugins', $pm);
      $mode->push_Plugins($this);
    };
  };

};


sub mo {
  return $mode;
};
sub co {
  return shift->mo->config;
};
sub po {
  return shift->mo->plot;
};
sub dd {
  my ($self) = @_;
  if (not $self->mo->datadefault) {
    $self->mo->datadefault(Demeter::Data->new(group	     => 'default___',
					      name	     => 'default___',
					      update_data    => 0,
					      update_columns => 0,
					      update_bkg     => 0,
					      update_bft     => 0,
					      update_fft     => 0,
					      fft_kmin => 3, fft_kmax => 15,
					      bft_rmin => 1, bft_rmax => 6,
					     ));
  };
  return shift->mo->datadefault;
};
sub fd {
  my ($self) = @_;
  if (not $self->mo->feffdefault) {
    $self->mo->feffdefault(Demeter::Feff->new(group=>'default___',
					      name=>'default___',
					     ));
  };
  return shift->mo->feffdefault;
};
alias config       => 'co';
alias plot_object  => 'po';
alias mode_object  => 'mo';
alias data_default => 'dd';
alias feff_default => 'fd';

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
  #return "copyright " . chr(169) . " 2006-2012 Bruce Ravel";
  return "copyright 2006-2012 Bruce Ravel";
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
  return 0 if (not defined $value);
  return 1 if ($value =~ m{^[ty]}i);
  return 0 if ($value =~ m{^[fn]}i);
  return 0 if (($value =~ m{$NUMBER}) and ($value == 0));
  return 1 if ($value =~ m{$NUMBER});
  return 0;
};

## organize obtaining a unique group name
## surely this could be more efficient than a plunder search!
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
  return if ($backend eq $self->mo->plot->backend);
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
      #$self -> dd -> standard;
      last SWITCH;
    };

    ($backend eq 'gnuplot') and do {
      $old_plot_object->remove;
      $old_plot_object->DEMOLISH if $old_plot_object;
      #print $self->co->default('gnuplot', 'program'), $/;
      #print $self->co->default('gnuplot', 'terminal'), $/;
      $self -> mo -> external_plot_object( Graphics::GnuplotIF->new(program => $self->co->default('gnuplot', 'program')) );
      require Demeter::Plot::Gnuplot;
      $self -> mo -> plot( Demeter::Plot::Gnuplot->new() );
      last SWITCH;
    };
  };
  $self -> po -> start_plot;
  $self -> po -> set(@to_set);
};

## the type constraints aren't working as I expect...?
sub template_set {
  my ($self, $which) = @_;
  my $template_regexp = Regexp::Assemble->new()->add(qw(demeter ifeffit iff_columns feffit))->re;
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

sub what_isa {
  my ($self, $att) = @_;
  return $self->meta->get_attribute($att)->{isa};
};


## pushed   Index parent sp    fft_pcpath is_mc
## down into override methods in extended classes
sub all {
  my ($self) = @_;
  my @keys   = map {$_->name} grep {$_->name !~ m{\A(?:data|reference|plot|plottable|pathtype|mode|highlight|hl|prompt|sentinal|progress|rate|thingy)\z}} $self->meta->get_all_attributes;
  my @values = map {$self->$_} @keys;
  my %hash   = zip(@keys, @values);
  return %hash;
};

sub get_params_of {
  my ($self) = @_;
  return $self->meta->get_attribute_list;
};
alias get_attributes => 'get_params_of';

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
    if ($trouble =~ m{~}) {
      ($match, $pp, $token) = split(/~/, $trouble);
    };
    if ($this =~ m{$match}) {
      my $content = $item->content();
      $content =~ s{\n}{ }g;
      $content =~ s{\s+\z}{};
      ## write a sensible message when exceeding ifeffit's compiled in
      ## limits on things
      if ($content =~ m{\((\&\w+)\)}) {
	my $var = $1;
	my $subst = $self->fetch_scalar($var);
	$content =~ s{$var}{$subst};
      };
      $text = $content;
    };
  };
  $text =~ s{C<\$pp>}{$pp};
  $text =~ s{C<\$token>}{"$token"};
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
  die("cannot write serialization to $fname\n") if not -w dirname($fname);
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

  my $mo       = Demeter->mo;
  my $data     = ($self eq 'Demeter') ? 0 : $self->data;
  my $pf       = $mo->plot;
  my $config   = $mo->config;
  my $fit      = $mo->fit;
  my $standard = $mo->standard;
  my $theory   = $mo->theory;
  my $path     = $mo->path;

  # try personal templates first
  my $tmpl = File::Spec->catfile($self->dot_folder,
				 "templates",
				 $category,
				 $self->get_mode("template_$category") || q{xxx},
				 "$file.tmpl");
  if (not -e $tmpl) {		# then try system templates
    $tmpl = File::Spec->catfile(dirname($INC{"Demeter.pm"}),
				"Demeter",
				"templates",
				$category,
				$self->get_mode("template_$category") || q{xxx},
				"$file.tmpl");
  };
  if (not -e $tmpl) {		# fall back to default templates
    my $set = ($category eq 'plot')   ? "pgplot"   :
              ($category eq 'feff')   ? "feff6"    :
              ($category eq 'report') ? 'standard' :
              ($category eq 'test')   ? 'test'     :
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
  undef $template;
  return $string;
};

sub pause {};
alias sleep => 'pause';

sub Croak {
  my ($self, $arg) = @_;
  if (lc($self->mo->ui) eq 'wx') {
    Wx::Perl::Carp::warn($arg);
  } else {
    croak $arg;
  };
};

sub conditional_features {
  my ($self) = @_;
  my $text = "The following conditional features are available:\n\n";
  $text .= "Graphics::GnuplotIF: " . $self->yesno($Gnuplot_exists);
  $text .= ($Gnuplot_exists)     ? " -- plotting with Gnuplot\n" : "  -- plotting with Gnuplot is disabled.\n";
  $text .= "STAR::Parser:        " . $self->yesno($STAR_Parser_exists);
  $text .= ($STAR_Parser_exists) ? " -- importing CIF files\n"   : "  -- importing CIF files is disabled.\n";
  $text .= "Xray::XDI:           " . $self->yesno($XDI_exists);
  $text .= ($XDI_exists)         ? " -- file metadata\n"         : "  -- file metadata is disabled.\n";
  $text .= "PDL:                 " . $self->yesno($PDL_exists);
  $text .= ($PDL_exists)         ? " -- PCA\n"                   : "  -- PCA is disabled.\n";
  $text .= "File::Monitor::Lite: " . $self->yesno($FML_exists);
  $text .= ($FML_exists)         ? " -- data watcher\n"          : "  -- data watcher is disabled.\n";
  return $text;
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter - A comprehensive XAS data analysis system using Feff and Ifeffit

=head1 VERSION

This documentation refers to Demeter version 0.9.11

=head1 SYNOPSIS

Import Demeter components into your program:

  use Demeter;

This will import all Demeter components into your program.
Using Demeter automatically turns on L<strict> and L<warnings>.

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
manipulated in any real program using Demeter.  Each of these objects
is implemented using Moose, the amazing meta-object system for Perl.
Although Moose adds some overhead at start-up for any application
using Demeter, its benefits are legion.  See L<Moose> and
L<http://www.iinteractive.com/moose> for more information.

=head1 IMPORT

Subsets of Demeter can be imported to shorted loading time.

=over 4

=item C<:data>

Import just enough of Demeter to perform data processing chores like
those of Athena.

  use Demeter qw(:data)

=item C<:analysis>

Import all the data processing chores as well as non-Feff data
analysis modules for things like linear combination fitting and peak
fitting.

  use Demeter qw(:analysis)

=item C<:hephaestus>

Import a bare bones set of data processing modules. This will not
allow much more than the plotting of mu(E) data.

  use Demeter qw(:hephaestus)

=item C<:xes>

Import the XES processing and peak fitting modules.

  use Demeter qw(:xes)

=item C<:fit>

Import everything needed to do data analysis with Feff.

  use Demeter qw(:fit)

=back

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
Setting the UI to screen does four things:

=over 4

=item 1.

Provides L<Demeter::UI::Screen::Interview> as a role for the Fit
object.  This imports the C<interview> method for use with the Fit
object, offering a CLI interface to the results of a fit.

=item 2.

Uses L<Term::Twiddle> or C<Term::Sk> to provide some visual feedback
on the screen while something time consuming is happening.

=item 3.

Makes the CLI prompting tool from L<Demeter::UI::Screen::Pause>
available.

=item 4.

Turns on colorization of output using L<Term::ASCIIColor>.

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
chores.  See L<Demeter::templates>.

In the future, a template set will be written for L<Ifeffit
2|http://cars9.uchicago.edu/ifeffit/tdl> when it becomes available.

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

=head2 Main methods

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

Write the serialization of an object to a file.  C<freeze> is an alias
for C<serialize>.  More complex objects override this method.  For
instance, see the Fit objects serialize method for complete details of
serialization of a fitting model.

  $object -> freeze('save.yaml');

=item C<serialization>

Returns the YAML serialization string for the object as text.

=item C<matches>

This is a generalized way of testing to see if an attribute value
matches a regular expression.  By default it tries to match the
supplied regular expression again the C<name> attribute.

  $is_match = $object->matches($regexp);

You can supply a second argument to match against some other
attribute.  For instance, to match the C<group> attribute against a
regular expression:

  $group_matches = $object->matches($regexp, 'group');

=item C<dispose>

This method sends data processing and plotting commands off to their
eventual destinations.  See the document page for L<Demeter::Dispose>
for complete details.

=item C<set_mode>

This is the method used to set the attributes described in
L<Demeter::Dispose>.  Any Demeter object can call this method.

   $object -> set_mode(ifeffit => 1,
                       screen  => 1,
                       buffer  => \@buffer_array
                      );

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
For a GDS object, this is the parameter name.  For Data, Path,
Path-like objects, and other plottable objects this is the string that
will be put in a plot legend.

=item C<data>

Path and Path-like objects are associated with Data objects for chores
like Fourier transforming.  That is, the Path or Path-like object will
use the processing parameters of the associated Data object.  This
method returns the reference to the associated Data object.  For Data
objects, this returns a reference to itself.  For other object types
this returns a false value.

=item C<plottable>

This returns a true value if the object is one that can be plotted.
Currently, Data, Path, VPath, and SSPath objects return a true value.
All others return false.

   $can_plot = $object -> plottable;

=item C<sentinal>

This attribute is inherited by all Demeter objects and provides a
completely generic way for interactivity to be built into any process
that a Demeter program undertakes.  It is used, for example, in the
L<Demeter::LCF> C<combi> method and in several of the histogram
processing methods.  This attribute takes a code reference.  At the
beginning of each fit in the combinatorial sequence, this is
dereference and called.  This allows a GUI to provide status updates
during a potentially long-running process.

The dereferencing and calling of the sentinal is handled by C<call>

  $object -> call_sentinal;

=back


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
someone could put something like C<{system 'rm -rf *'}> in one of the
templates.  L<Text::Template> supports using a L<Safe> compartment.

=item *

Serialization is incompletely implemented at this time.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 VERSIONS

=over 4

=item 0.5.4

New numbering scheme: 0.5 is the beta version with a windows
installer, the third number corresponds to the release number.  So
Windows installer release 4 contains the code from version 0.5.4 and
so on.

=item 0.4.7

Things mostly working on Windows.

=item 0.4.6

We now have a mostly functional Athena.

=item 0.4.5

Fit history in Artemis is mostly functional.  Reordering of Plot list
in Artemis now possible by mouse.  Added rudimentary XES support.

=item 0.4.4

Added fit history to Artemis

=item 0.4.3

Added LCF fitting

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

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
