package Demeter::Mode;

use Moose; #X::Singleton;
use MooseX::Aliases;
use MooseX::Types::LaxNum;


with 'MooseX::SetGet';
#use Demeter::Config;
use Demeter::StrTypes qw( Empty
			  TemplateProcess
			  TemplateFit
			  TemplatePlot
			  TemplateFeff
			  TemplateAnalysis
		       );
use List::MoreUtils qw(zip none);
#use vars qw($singleton);	# Moose 0.61, MooseX::Singleton 0.12 seem to need this

## -------- disposal modes
has 'group'      => (is => 'rw', isa => 'Str', default => q{Mode});
has 'name'       => (is => 'rw', isa => 'Str', default => q{Mode});

has 'backend'    => (is => 'rw', isa => 'Bool', default => 1, alias=>['ifeffit', 'larch']);
has $_           => (is => 'rw', isa => 'Bool', default => 0)   foreach (qw(screen plotscreen repscreen));
has $_           => (is => 'rw', isa => 'Str',                  default => q{}) foreach (qw(file plotfile repfile));
has 'buffer'     => (is => 'rw', isa => Empty.'|ArrayRef | ScalarRef');
has 'plotbuffer' => (is => 'rw', isa => 'ArrayRef | ScalarRef');

has 'callback'     => (is => 'rw', isa => 'CodeRef');
has 'plotcallback' => (is => 'rw', isa => 'CodeRef');
has 'feedback'     => (is => 'rw', isa => Empty.'|CodeRef', default=>q{});

## -------- default objects for templates
has 'config'   => (is => 'rw', isa => 'Any');  #         Demeter::Config);
has 'plot'     => (is => 'rw', isa => 'Any');  #         Demeter::Plot);
has 'fit'      => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Fit');
has 'standard' => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Data');
has 'current'  => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Data');
has 'theory'   => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Feff');
has 'path'     => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Path');

## -------- templates sets
has 'template_process'  => (is => 'rw', isa => 'Str', default => 'ifeffit');
has 'template_fit'      => (is => 'rw', isa => 'Str', default => 'ifeffit');
has 'template_analysis' => (is => 'rw', isa => 'Str', default => 'ifeffit');
has 'template_plot'     => (is => 'rw', isa => 'Str', default => 'pgplot');
has 'template_feff'     => (is => 'rw', isa => 'Str', default => 'feff6');
has 'template_report'   => (is => 'rw', isa => 'Str', default => 'standard');
has 'template_plugin'   => (is => 'rw', isa => 'Str', default => 'ifeffit');
# has 'template_process'  => (is => 'rw', isa => 'TemplateProcess',  default => 'ifeffit');
# has 'template_fit'      => (is => 'rw', isa => 'TemplateFit',      default => 'ifeffit');
# has 'template_analysis' => (is => 'rw', isa => 'TemplateAnalysis', default => 'ifeffit');
# has 'template_plot'     => (is => 'rw', isa => 'TemplatePlot',     default => 'pgplot');
# has 'template_feff'     => (is => 'rw', isa => 'TemplateFeff',     default => 'feff6');
# has 'template_test'     => (is => 'ro', isa => 'Str',              default => 'test');

## -------- class collector arrays for sentinel functionality
has 'Atoms' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Atoms'    => 'push',
			      'clear_Atoms'   => 'clear',
			      'splice_Atoms'  => 'splice',
			     }
	       );
has 'Data' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Data'    => 'push',
			      'clear_Data'   => 'clear',
			      'splice_Data'  => 'splice',
			     }
	       );
has 'Feff' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Feff'    => 'push',
			      'clear_Feff'   => 'clear',
			      'splice_Feff'  => 'splice',
			     }
	       );
has 'External' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_External'    => 'push',
			      'clear_External'   => 'clear',
			      'splice_External'  => 'splice',
			     }
	       );
has 'Fit' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Fit'    => 'push',
			      'clear_Fit'   => 'clear',
			      'splice_Fit'  => 'splice',
			     }
	       );
has 'Feffit' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Feffit'    => 'push',
			      'clear_Feffit'   => 'clear',
			      'splice_Feffit'  => 'splice',
			     }
	       );
has 'GDS' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_GDS'    => 'push',
			      'clear_GDS'   => 'clear',
			      'splice_GDS'  => 'splice',
			     }
	       );
has 'Path' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Path'    => 'push',
			      'clear_Path'   => 'clear',
			      'splice_Path'  => 'splice',
			     }
	       );
has 'ScatteringPath' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_ScatteringPath'    => 'push',
			      'clear_ScatteringPath'   => 'clear',
			      'splice_ScatteringPath'  => 'splice',
			     }
	       );
has 'VPath' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_VPath'    => 'push',
			      'clear_VPath'   => 'clear',
			      'splice_VPath'  => 'splice',
			     }
	       );
has 'SSPath' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_SSPath'    => 'push',
			      'clear_SSPath'   => 'clear',
			      'splice_SSPath'  => 'splice',
			     }
	       );
has 'ThreeBody' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_ThreeBody'    => 'push',
			      'clear_ThreeBody'   => 'clear',
			      'splice_ThreeBody'  => 'splice',
			     }
	       );
has 'FPath' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_FPath'    => 'push',
			      'clear_FPath'   => 'clear',
			      'splice_FPath'  => 'splice',
			     }
	       );
has 'FSPath' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_FSPath'    => 'push',
			      'clear_FSPath'   => 'clear',
			      'splice_FSPath'  => 'splice',
			     }
	       );
has 'StructuralUnit' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_StructuralUnit'    => 'push',
			      'clear_StructuralUnit'   => 'clear',
			      'splice_StructuralUnit'  => 'splice',
			     }
	       );
has 'Prj' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Prj'    => 'push',
			      'clear_Prj'   => 'clear',
			      'splice_Prj'  => 'splice',
			     }
	       );

has 'MultiChannel' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_MultiChannel'    => 'push',
			      'clear_MultiChannel'   => 'clear',
			      'splice_MultiChannel'  => 'splice',
			     }
	       );
has 'BulkMerge' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_BulkMerge'    => 'push',
			      'clear_BulkMerge'   => 'clear',
			      'splice_BulkMerge'  => 'splice',
			     }
	       );
has 'Pixel' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Pixel'    => 'push',
			      'clear_Pixel'   => 'clear',
			      'splice_Pixel'  => 'splice',
			     }
	       );
has 'Plot' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Plot'    => 'push',
			      'clear_Plot'   => 'clear',
			      'splice_Plot'  => 'splice',
			     }
	       );
has 'Indicator' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Indicator'    => 'push',
			      'clear_Indicator'   => 'clear',
			      'splice_Indicator'  => 'splice',
			     }
	       );
has 'Style' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Style'    => 'push',
			      'clear_Style'   => 'clear',
			      'splice_Style'  => 'splice',
			     }
	       );
has 'LCF' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_LCF'    => 'push',
			      'clear_LCF'   => 'clear',
			      'splice_LCF'  => 'splice',
			     }
	       );
has 'PCA' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_PCA'    => 'push',
			      'clear_PCA'   => 'clear',
			      'splice_PCA'  => 'splice',
			     }
	       );
has 'XES' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_XES'    => 'push',
			      'clear_XES'   => 'clear',
			      'splice_XES'  => 'splice',
			     }
	       );
has 'PeakFit' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_PeakFit'    => 'push',
			      'clear_PeakFit'   => 'clear',
			      'splice_PeakFit'  => 'splice',
			     }
	       );
has 'LogRatio' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_LogRatio'    => 'push',
			      'clear_LogRatio'   => 'clear',
			      'splice_LogRatio'  => 'splice',
			     }
	       );
has 'Diff' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Diff'    => 'push',
			      'clear_Diff'   => 'clear',
			      'splice_Diff'  => 'splice',
			     }
	       );
has 'LineShape' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_LineShape'    => 'push',
			      'clear_LineShape'   => 'clear',
			      'splice_LineShape'  => 'splice',
			     }
	       );
has 'Journal' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Journal'    => 'push',
			      'clear_Journal'   => 'clear',
			      'splice_Journal'  => 'splice',
			     }
	       );

has 'Distributions' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Distributions'    => 'push',
			      'clear_Distributions'   => 'clear',
			      'splice_Distributions'  => 'splice',
			     }
	       );

has 'types' => (is => 'ro', isa => 'ArrayRef',
		default => sub{[qw(Atoms Data Feff External Fit Feffit GDS Path Plot Indicator Style
				   LCF PCA XES PeakFit LogRatio Diff LineShape
				   ScatteringPath VPath SSPath ThreeBody FPath FSPath
				   StructuralUnit Prj Pixel MultiChannel BulkMerge Journal Distributions)]},
	       );

has 'Plugins' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_Plugins'    => 'push',
			      'clear_Plugins'   => 'clear',
			      'splice_Plugins'  => 'splice',
			     }
	       );


## -------- The Professor and Mary Anne
has 'iwd' => (is => 'rw', isa => 'Str', default => q{});
has 'cwd' => (is => 'rw', isa => 'Str', default => q{});

has 'pathindex'  => (is => 'rw', isa => 'Int', default => 1);
has 'currentfit' => (is => 'rw', isa => 'Int', default => 1);
has 'datacount'  => (is => 'rw', isa => 'Int', default => 0);
has 'merge'      => (is => 'rw', isa => 'Str', default => 'importance');

has 'echo'		   => (is => 'rw', isa => 'Any');
has 'datadefault'	   => (is => 'rw', isa => 'Any', default => q{});
has 'feffdefault'	   => (is => 'rw', isa => 'Any', default => q{});
has 'external_plot_object' => (is => 'rw', isa => 'Any');
has 'plotting_initialized' => (is => 'rw', isa => 'Bool', default => 0);
has 'identity'             => (is => 'rw', isa => 'Str',  default => 'Demeter',);
has 'ui'                   => (is => 'rw', isa => 'Str',  default => 'none',);
has 'silently_ignore_unplottable' => (is => 'rw', isa => 'Bool', default => 0);
has 'throwaway_group'      => (is => 'rw', isa => 'Str',  default => 'dem__eter',);

has 'check_heap'   => (is => 'rw', isa => 'Bool',   default => 0);
has 'heap_free'	   => (is => 'rw', isa => 'LaxNum', default => 0);
has 'heap_used'	   => (is => 'rw', isa => 'LaxNum', default => 0);

sub increment_fit {
  my ($self) = @_;
  $self->currentfit($self->currentfit + 1);
  return $self->currentfit;
};

sub reset_path_index {
  my ($self) = @_;
  $self->pathindex(1);
  return $self->pathindex;
};

sub fetch {
  my ($self, $type, $group) = @_;
  my $re = join("|", @{$self->types});
  my @thesetypes = (ref($type) eq 'ARRAY') ? @$type : ($type);
  return q{} if (none {$_ =~ m{(?:$re)}} @thesetypes);
  my @objects = ();
  foreach my $t (@thesetypes) {
    my $list = $self->$t;
    push @objects, grep {defined($_)} @$list;
  }
  foreach my $o (@objects) {
    return $o if ($o->group eq $group);
  };
  return q{};
};

sub any {
  my ($self, $group) = @_;
  foreach my $t (@{$self->types}) {
    my $list = $self->$t;
    foreach my $o (@$list) {
      return $o if ($o->group eq $group);
    };
  };
  return q{};
};

sub remove {
  my ($self, $object) = @_;
  my $type = (split(/::/, ref $object))[-1];
  my $orig = $type;
  if (($type eq 'Gnuplot') or ($type eq 'SingleFile')) {
    $object->end_plot;
    $type = 'Plot';
  } elsif ($type eq 'External') {
    $type = 'Feff';
  } elsif ($type eq 'Aggregate') {
    $type = 'Feff';
  } elsif ($type eq 'Demeter') {
    return;
  };
  my $group = $object->group;
  my ($i, $which) = (0, -1);
  return if ($#{$self->$type} == -1);
  foreach my $o (@{$self->$type}) {
    if (defined($o) and ($o->group eq $group)) {
      $which = $i;
      last;
    };
    ++$i;
  };
  return if ($which == -1);
  my $method = "splice_".$type;
  local $| = 1;
  #print join("|", $#{$self->$type}, $method, $type, $orig, $which), $/;
  $self->$method($which, 1);
};

sub everything {
  my ($self) = @_;
  return (@{ $self->Atoms	   },
	  @{ $self->Data	   },
	  @{ $self->External	   },
	  @{ $self->Fit		   },
	  @{ $self->Feffit	   },
	  @{ $self->Path	   },
	  @{ $self->ScatteringPath },
	  @{ $self->VPath	   },
	  @{ $self->SSPath	   },
	  @{ $self->ThreeBody	   },
	  @{ $self->FPath	   },
	  @{ $self->FSPath	   },
	  @{ $self->StructuralUnit },
	  @{ $self->Prj		   },
	  @{ $self->Pixel          },
	  @{ $self->MultiChannel   },
	  @{ $self->BulkMerge      },
	  @{ $self->Plot	   },
	  @{ $self->Indicator	   },
	  @{ $self->Style	   },
	  @{ $self->Feff	   },
	  @{ $self->LCF		   },
	  @{ $self->PCA		   },
	  @{ $self->XES		   },
	  @{ $self->PeakFit	   },
	  @{ $self->LogRatio	   },
	  @{ $self->Diff	   },
	  @{ $self->LineShape      },
	  @{ $self->Journal        },
	  @{ $self->Distributions  },
	  @{ $self->GDS		   },
	 );
};

sub destroy_all {
  my ($self) = @_;
  foreach my $obj ($self->everything) {
    #print $obj, $/;
    next if not defined $obj;
    $obj -> DEMOLISH; #DESTROY;
  };
};

sub report {
  my ($self, $which) = @_;
  my $text = "Mode object\n\n";
  $which ||= 'all';
  foreach my $this (sort @{$self->types}) {
    my $n = 19 - length($this);
    #$text .= sprintf("\n%s %s %d\n", $this, '.' x $n, $#{$self->$this}+1);
    if (($this eq $which) or ($which eq 'all')) {
      my $att = ($this eq 'ScatteringPath') ? 'intrpline'
	      : ($this eq 'Plot')           ? 'backend'
	      : ($this eq 'Indicator')      ? 'report'
	      : ($this eq 'GDS')            ? 'write_gds'
	      :                               'name';
      my $i = 0;
      foreach my $obj (@{$self->$this}) {
	$text .= sprintf("%-14s %4d (%s) : %s\n", $this, ++$i, $obj->group, $obj->$att);
	chop $text if ($this eq 'GDS');
      };
      $text .= "\n" if $i;
    };
  };
  return $text
};

sub serialization {
  my ($self) = @_;
  my @keys = sort {$a cmp $b} grep{$_ if ($_ =~ m{\A[a-z]})} map {$_->name} $self->meta->get_all_attributes;
  my @values = map { my $foo = (ref($_) =~ m{CODE})             ? 'Code reference'
		             : (ref($_) =~ m{SCALAR})           ? $$_
		             : (ref($_) =~ m{Demeter|Graphics}) ? ref($_).' object'
			     :                                    $_;
		     $foo||q{};
		   } map {$self->$_} @keys;
  my %hash   = zip(@keys, @values);
  return YAML::Tiny::Dump(\%hash);
};



__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Mode - Demeter's sentinel system

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 DESCRIPTION

This special object is used to store global attributes of an instance
of Demeter in a way that makes those attributes available to any
Demeter object.

Access to this object is via the C<get_mode> and C<set_mode> methods
of the Demeter base class.  The convenience methods C<co> and C<po> of
the Demeter base class are used to gain access to the Config and Plot
objects.  Any of these methods can be called by any Demeter object:

  $to_screen = $data_object     -> get_mode('screen');
  $to_screen = $gds_object      -> get_mode('screen');
  $to_screen = $path_object     -> get_mode('screen');
  $to_screen = $scattering_path -> get_mode('screen');
  $to_screen = $prj_object      -> get_mode('screen');
    ## and so on ...

This object also monitors the creation and destruction of Demeter
objects (Atoms, Data, Data::Prj, Data::MultiChannel, Data::BulkMerge,
Feff, Feff::External, Fit, GDS, Path, Plot, Plot::Indicator,
ScatteringPath, SSPath, VPath, etc.) and provides methods which give a
way for one object to affect any other objects created during the
instance of Demeter.  For example, when the kweight value of the Plot
object is changed, it is necessary to signal all Data objects that
they will need to update their forward Fourier transforms.  This
object is the glue that allows things like that to happen.

=head1 ATTRIBUTES

=head2 Disposal modes

=over 4

=item C<backend>

Dispose commands to Larch or Ifeffit, as appropriate, when true.

=item C<screen>

Dispose commands to STDOUT when true.

=item C<plotscreen>

Dispose plotting commands to STDOUT when true.

=item C<repscreen>

Dispose reprocessed commands to STDOUT when true.

=item C<file>

Dispose commands to a file when a filename is given.

=item C<plotfile>

Dispose plotting commands to a file when a filename is given.

=item C<repfile>

Dispose reprocessed commands to a file when a filename is given.

=item C<buffer>

Dispose commands to a string or array when given a reference to a
string or array.

=item C<plotbuffer>

Optionally dispose of plotting commands to a difference string or
array reference.

=item C<callback>

Dispose commands by sending them as the argument to a user-supplied
code rerference.

=item C<plotcallback>

Optionally dispose of plotting commands to a difference code
reference.

=item C<feedback>

A code ref for disposing of feedback from Ifeffit or Larch.

=back

=head2 Template objects

=over 4

=item C<config>

A reference to the singleton Config object.  C<$C> is the special
template variable.

=item C<plot>

A reference to the current Plot object.  C<$P> is the special
template variable.

=item C<fit>

A reference to the current Fit object.  C<$F> is the special
template variable.

=item C<standard>

A reference to the current Data object used as a data processing
standard.  C<$DS> is the special template variable.

=item C<theory>

A reference to the current Feff object.  C<$T> is the special
template variable.

=item C<path>

A reference to the current Path object.  C<$PT> is the special
template variable.

=back

=head2 Template sets

=over 4

=item C<template_process>

The template set to use for processing data.

=item C<template_fit>

The template set to use for fitting data.

=item C<template_analysis>

The template set to use for analyzing mu(E) data.

=item C<template_plot>

The template set to use for plotting data.

=item C<template_feff>

The template set to use for writing F<feff.inp> files.

=item C<template_test>

A special template set used for testing Demeter.

=back

=head2 Object collections

=over 4

=item C<Atoms>

A list of all Atoms objects created during this instance of Demeter.

=item C<Data>

A list of all Data objects created during this instance of Demeter.

=item C<Feff>

A list of all Feff objects created during this instance of Demeter.

=item C<External>

A list of all Feff::External objects created during this instance of Demeter.

=item C<Fit>

A list of all Fit objects created during this instance of Demeter.

=item C<GDS>

A list of all GDS objects created during this instance of Demeter.

=item C<Path>

A list of all Path objects created during this instance of Demeter.

=item C<Plot>

A list of all Plot objects created during this instance of Demeter.

=item C<ScatteringPath>

A list of all ScatteringPath objects created during this instance of Demeter.

=item C<VPath>

A list of all VPath objects created during this instance of Demeter.

=item C<SSPath>

A list of all SSPath objects created during this instance of Demeter.

=item C<Prj>

A list of all Data::Prj objects created during this instance of Demeter.

=back

=head2 Other attributes

=over 4

=item C<iwd>

The initial working directory when Demeter starts.

=item C<cwd>

Demeter's current working directory.

=item echo

???

=item C<datadefault>

This is a Data object used as a fallback.  For instance, one might
want to process and plot Path objects without having imported a Data
object.  This global attribute will be used in that case to properly
process and plot the Path.

=item C<feffdefault>

This is a Feff object used as a fallback in some Path-like objects.

=item C<external_plot_object>

For plotting backends that have an objective interface, this global
attribute carried the refernece to that object.  For example, in the
gnuplot backend, this contains a reference to the
L<Graphics::GnuplotIF> object.

=item C<ui>

This is a string identifying the user interface backend.  At this
time, its only use is to tell the Fit object to import the
curses-based methods in L<Demeter::UI::Screen::Interview> and
L<Demeter::UI::Screen::Progress> when it is set to C<screen>.  Future
possibilities might include C<wx> or C<rpc>.

=item C<silently_ignore_unplottable>

When true, this averts croaking in certain situations where an attempt
is made to plot an object in a way that it cannot be plotted (for
example, attempting to plot in energy a Data object of datatype chi).
This is useful in the context of a GUI, but is stringly discouraged in
a command line script.

=back

=head1 SENTINEL FUNCTIONALITY

It should rarely be necessary that a user script needs to access this
part of this object.  Mostly the sentinel functionality is handled
behind the scenes, during object creation or destruction or at the end
of a script.  The details are documented here for those times when one
needs to see under the hood.

Each Demeter object (Atoms, Data, Data::Prj, Data::MultiChannel,
Data::BulkMerge, Feff, Feff::External, Fit, GDS, Path, Plot,
Plot::Indicator, ScatteringPath, SSPath, VPath, etc.) (Data::Prj is
refered to just as Prj, other Data::* classes are the same) has each
of the following three function associated with it.

All of my examples use the Data object.

=over 4

=item I<Object>

This is the accessor for the attribute which holds the list of all
Data objects created during this instance of Demeter.

  my @list = @{ $object->mo->Data };

=item C<push_>I<Object>

This is the method used to append an object to the list;

  $data_object->push_Data($data_object);

This happens automatically when a Data object is created.

=item C<clear_>I<Object>

This method is used to clear the contents of the list.

  $data_object->clear_Data;

This is not used for anything at this time, but it seemed useful.

=back

=head2 Sentinel methods

=over 4

=item C<fetch>

This method returns an object reference given its group name.

  $object = $demeter_object->mo->fetch("ScatteringPath", $group);

In this example, the ScatteringPath object whose group name is $group
will be returned.  The first argument is one of the Demeter object
types.  This method was written to facilitate drag and drop in the Wx
version of Artemis.  Wx's drag and drop capability does not easily do
DND on blessed references.  It was much easier to do DND on an array
of group names, which are simple strings.  I then needed this method
to convert the list of group names back into a list of object
references.

=item C<reset_path_index>

This resets the path counter to 1.  This is used when closing one
project and starting a new one so that path indexing can start at 1 in
the new fit.  See C<close_project> in L<Demeter::UI::Artemis::Project>.

=back

=head1 DIAGNOSTICS

Moose type constraints are used on several of the GDS object
attributes.  Error messages appropriate to the type constrain will be
generated.

=head1 SERIALIZATION AND DESERIALIZATION

See the discussion of serialization and deserialization in
C<Demeter::Fit>.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Errors should be propagated into def parameters

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

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
