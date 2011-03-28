package Demeter::Mode;

use MooseX::Singleton;
use MooseX::AttributeHelpers;
with 'MooseX::SetGet';
#use Demeter::Config;
use Demeter::StrTypes qw( Empty
			  TemplateProcess
			  TemplateFit
			  TemplatePlot
			  TemplateFeff
			  TemplateAnalysis
		       );
#use vars qw($singleton);	# Moose 0.61, MooseX::Singleton 0.12 seem to need this

## -------- disposal modes
has 'ifeffit'    => (is => 'rw', isa => 'Bool',                 default => 1);
has $_           => (is => 'rw', isa => 'Bool',                 default => 0)   foreach (qw(screen plotscreen repscreen));
has $_           => (is => 'rw', isa => 'Str',                  default => q{}) foreach (qw(file plotfile repfile));
has 'buffer'     => (is => 'rw', isa => 'ArrayRef | ScalarRef');
has 'plotbuffer' => (is => 'rw', isa => 'ArrayRef | ScalarRef');

has 'callback'     => (is => 'rw', isa => 'CodeRef');
has 'plotcallback' => (is => 'rw', isa => 'CodeRef');
has 'feedback'     => (is => 'rw', isa => 'CodeRef');

## -------- default objects for templates
has 'config'   => (is => 'rw', isa => 'Any');  #         Demeter::Config);
has 'plot'     => (is => 'rw', isa => 'Any');  #         Demeter::Plot);
has 'fit'      => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Fit');
has 'standard' => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Data');
has 'theory'   => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Feff');
has 'path'     => (is => 'rw', isa => 'Any');  # Empty.'|Demeter::Path');

## -------- templates sets
has 'template_process'  => (is => 'rw', isa => 'Str', default => 'ifeffit');
has 'template_fit'      => (is => 'rw', isa => 'Str', default => 'ifeffit');
has 'template_analysis' => (is => 'rw', isa => 'Str', default => 'ifeffit');
has 'template_plot'     => (is => 'rw', isa => 'Str', default => 'pgplot');
has 'template_feff'     => (is => 'rw', isa => 'Str', default => 'feff6');
# has 'template_process'  => (is => 'rw', isa => 'TemplateProcess',  default => 'ifeffit');
# has 'template_fit'      => (is => 'rw', isa => 'TemplateFit',      default => 'ifeffit');
# has 'template_analysis' => (is => 'rw', isa => 'TemplateAnalysis', default => 'ifeffit');
# has 'template_plot'     => (is => 'rw', isa => 'TemplatePlot',     default => 'pgplot');
# has 'template_feff'     => (is => 'rw', isa => 'TemplateFeff',     default => 'feff6');
# has 'template_test'     => (is => 'ro', isa => 'Str',              default => 'test');

## -------- class collector arrays for sentinel functionality
has 'Atoms' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Atoms',
			      'clear'   => 'clear_Atoms',
			      'splice'  => 'splice_Atoms',
			     }
	       );
has 'Data' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Data',
			      'clear'   => 'clear_Data',
			      'splice'  => 'splice_Data',
			     }
	       );
has 'Feff' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Feff',
			      'clear'   => 'clear_Feff',
			      'splice'  => 'splice_Feff',
			     }
	       );
has 'External' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_External',
			      'clear'   => 'clear_External',
			      'splice'  => 'splice_External',
			     }
	       );
has 'Fit' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Fit',
			      'clear'   => 'clear_Fit',
			      'splice'  => 'splice_Fit',
			     }
	       );
has 'Feffit' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Feffit',
			      'clear'   => 'clear_Feffit',
			      'splice'  => 'splice_Feffit',
			     }
	       );
has 'GDS' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_GDS',
			      'clear'   => 'clear_GDS',
			      'splice'  => 'splice_GDS',
			     }
	       );
has 'Path' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Path',
			      'clear'   => 'clear_Path',
			      'splice'  => 'splice_Path',
			     }
	       );
has 'ScatteringPath' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_ScatteringPath',
			      'clear'   => 'clear_ScatteringPath',
			      'splice'  => 'splice_ScatteringPath',
			     }
	       );
has 'VPath' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_VPath',
			      'clear'   => 'clear_VPath',
			      'splice'  => 'splice_VPath',
			     }
	       );
has 'SSPath' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_SSPath',
			      'clear'   => 'clear_SSPath',
			      'splice'  => 'splice_SSPath',
			     }
	       );
has 'ThreeBody' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_ThreeBody',
			      'clear'   => 'clear_ThreeBody',
			      'splice'  => 'splice_ThreeBody',
			     }
	       );
has 'FPath' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_FPath',
			      'clear'   => 'clear_FPath',
			      'splice'  => 'splice_FPath',
			     }
	       );
has 'FSPath' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_FSPath',
			      'clear'   => 'clear_FSPath',
			      'splice'  => 'splice_FSPath',
			     }
	       );
has 'StructuralUnit' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_StructuralUnit',
			      'clear'   => 'clear_StructuralUnit',
			      'splice'  => 'splice_StructuralUnit',
			     }
	       );
has 'Prj' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Prj',
			      'clear'   => 'clear_Prj',
			      'splice'  => 'splice_Prj',
			     }
	       );

has 'MultiChannel' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_MultiChannel',
			      'clear'   => 'clear_MultiChannel',
			      'splice'  => 'splice_MultiChannel',
			     }
	       );
has 'Pixel' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Pixel',
			      'clear'   => 'clear_Pixel',
			      'splice'  => 'splice_Pixel',
			     }
	       );
has 'Plot' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Plot',
			      'clear'   => 'clear_Plot',
			      'splice'  => 'splice_Plot',
			     }
	       );
has 'Indicator' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Indicator',
			      'clear'   => 'clear_Indicator',
			      'splice'  => 'splice_Indicator',
			     }
	       );
has 'Style' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Style',
			      'clear'   => 'clear_Style',
			      'splice'  => 'splice_Style',
			     }
	       );
has 'LCF' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_LCF',
			      'clear'   => 'clear_LCF',
			      'splice'  => 'splice_LCF',
			     }
	       );
has 'XES' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_XES',
			      'clear'   => 'clear_XES',
			      'splice'  => 'splice_XES',
			     }
	       );
has 'PeakFit' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_PeakFit',
			      'clear'   => 'clear_PeakFit',
			      'splice'  => 'splice_PeakFit',
			     }
	       );
has 'LogRatio' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_LogRatio',
			      'clear'   => 'clear_LogRatio',
			      'splice'  => 'splice_LogRatio',
			     }
	       );
has 'Diff' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Diff',
			      'clear'   => 'clear_Diff',
			      'splice'  => 'splice_Diff',
			     }
	       );
has 'LineShape' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_LineShape',
			      'clear'   => 'clear_LineShape',
			      'splice'  => 'splice_LineShape',
			     }
	       );
has 'Journal' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Journal',
			      'clear'   => 'clear_Journal',
			      'splice'  => 'splice_Journal',
			     }
	       );

has 'types' => (is => 'ro', isa => 'ArrayRef',
		default => sub{[qw(Atoms Data Feff External Fit Feffit GDS Path Plot Indicator Style
				   LCF XES PeakFit LogRatio Diff LineShape
				   ScatteringPath VPath SSPath ThreeBody FPath FSPath
				   StructuralUnit Prj Pixel MultiChannel Journal)]},);

has 'Plugins' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_Plugins',
			      'clear'   => 'clear_Plugins',
			      'splice'  => 'splice_Plugins',
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
  return q{} if ($type !~ m{(?:$re)});
  my $list = $self->$type;
  foreach my $o (@$list) {
    return $o if ($o->group eq $group);
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
  } elsif ($type eq 'Demeter') {
    return;
  } elsif ($type eq 'DL_POLY') {
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
	  @{ $self->Plot	   },
	  @{ $self->Indicator	   },
	  @{ $self->Style	   },
	  @{ $self->Feff	   },
	  @{ $self->LCF		   },
	  @{ $self->XES		   },
	  @{ $self->PeakFit	   },
	  @{ $self->LogRatio	   },
	  @{ $self->Diff	   },
	  @{ $self->LineShape      },
	  @{ $self->Journal        },
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
  my $text = q{};
  $which ||= 'all';
  foreach my $this (sort @{$self->types}) {
    my $n = 19 - length($this);
    $text .= sprintf("\n%s %s %d\n", $this, '.' x $n, $#{$self->$this}+1);
    if (($this eq $which) or ($which eq 'all')) {
      my $att = ($this eq 'ScatteringPath') ? 'intrpline'
	      : ($this eq 'Plot')           ? 'backend'
	      : ($this eq 'Indicator')      ? 'report'
	      : ($this eq 'GDS')            ? 'write_gds'
	      :                               'name';
      my $i = 0;
      foreach my $obj (@{$self->$this}) {
	$text .= sprintf("\t%3d (%s) : %s\n", ++$i, $obj->group, $obj->$att);
      };
    };
  };
  return $text
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Mode - Demeter's sentinel system

=head1 VERSION

This documentation refers to Demeter version 0.4.

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
objects (Atoms, Data, Data::Prj, Data::MultiChannel, Feff,
Feff::External, Fit, GDS, Path, Plot, Plot::Indicator, ScatteringPath,
SSPath, VPath, etc.) and provides methods which give a way for one
object to affect any other objects created during the instance of
Demeter.  For example, when the kweight value of the Plot object is
changed, it is necessary to signal all Data objects that they will
need to update their forward Fourier transforms.  This object is the
glue that allows things like that to happen.

=head1 ATTRIBUTES

=head2 Disposal modes

=over 4

=item C<ifeffit>

Dispose commands to Ifeffit when true.

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

A code ref for disposing of feedback from Ifeffit.

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

Each Demeter object (Atoms, Data, Data::Prj, Data::MultiChannel, Feff,
Feff::External, Fit, GDS, Path, Plot, Plot::Indicator, ScatteringPath,
SSPath, VPath, etc.) (Data::Prj is refered to just as Prj, other
Data::* classes are the same) has each of the following three function
associated with it.

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

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
