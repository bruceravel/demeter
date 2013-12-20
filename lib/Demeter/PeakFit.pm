package Demeter::PeakFit;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use Carp;
use autodie qw(open close);

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use MooseX::Aliases;
use Moose::Util qw(apply_all_roles);
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Empty );

use File::Spec;
use List::Util qw(min max);
use List::MoreUtils qw(any none uniq);
use Spreadsheet::WriteExcel;
use String::Random qw(random_string);

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

use vars qw($Fityk_exists);
$Fityk_exists       = eval "require fityk";

has '+plottable'      => (default => 1);
has '+data'	      => (isa => Empty.'|Demeter::Data|Demeter::XES');
has '+name'	      => (default => 'PeakFit' );
has 'screen'	      => (is => 'rw', isa => 'Bool',   default => 0);
has 'buffer'	      => (is => 'rw', isa => 'ArrayRef | ScalarRef');
has 'engine'	      => (is => 'rw', isa => 'Bool',   default => 1);

has 'xaxis'	      => (is => 'rw', isa => 'Str',    default => q{energy});
has 'yaxis'	      => (is => 'rw', isa => 'Str',    default => q{flat});
has 'sigma'	      => (is => 'rw', isa => 'Str',    default => q{});

has 'xmin'	      => (is => 'rw', isa => 'LaxNum', default => 0, alias => 'emin');
has 'xmax'	      => (is => 'rw', isa => 'LaxNum', default => 0, alias => 'emax');

has 'plot_components' => (is => 'rw', isa => 'Bool',   default => 0);
has 'plot_residual'   => (is => 'rw', isa => 'Bool',   default => 0);

has 'ninfo'	      => (is => 'rw', isa => 'LaxNum', default => 0);
has 'epsilon'	      => (is => 'rw', isa => 'LaxNum', default => 0);
has 'nparam'	      => (is => 'rw', isa => 'Int',    default => 0);
has 'ndata'	      => (is => 'rw', isa => 'Int',    default => 0);
has 'ntitles'	      => (is => 'rw', isa => 'Int',    default => 0);

has 'rfactor'	      => (is => 'rw', isa => 'LaxNum', default => 0);
has 'chisqr'	      => (is => 'rw', isa => 'LaxNum', default => 0);
has 'chinu'	      => (is => 'rw', isa => 'LaxNum', default => 0);

has 'lineshapes'   => (
		       traits    => ['Array'],
		       is        => 'rw',
		       isa       => 'ArrayRef[Demeter::PeakFit::LineShape]',
		       default   => sub { [] },
		       handles   => {
				     'push_lineshapes'    => 'push',
				     'pop_lineshapes'     => 'pop',
				     'shift_lineshapes'   => 'shift',
				     'unshift_lineshapes' => 'unshift',
				     'clear_lineshapes'   => 'clear',
				    },
		      );
has 'linegroups'   => (
		       traits    => ['Array'],
		       is        => 'rw',
		       isa       => 'ArrayRef[Str]',
		       default   => sub { [] },
		       handles   => {
				     'push_linegroups'    => 'push',
				     'pop_linegroups'     => 'pop',
				     'shift_linegroups'   => 'shift',
				     'unshift_linegroups' => 'unshift',
				     'clear_linegroups'   => 'clear',
				    },
		      );

has 'tempfiles' => (
		    traits    => ['Array'],
		    is        => 'rw',
		    isa       => 'ArrayRef[Str]',
		    default   => sub { [] },
		    handles   => {
				  'add_tempfile'  => 'push',
				  'remove_tempfile'   => 'pop',
				  'clear_tempfiles' => 'clear',
				 }
		   );


has 'doing_seq' => (is => 'rw', isa => 'Bool', default => 0);
has 'include_caller' => (is => 'rw', isa => 'Bool', default => 1);
has 'seq_count' => (is => 'rw', isa => 'Int',  default => 0);
has 'seq_results'=> (
		     traits    => ['Array'],
		     is        => 'rw',
		     isa       => 'ArrayRef',
		     default   => sub { [] },
		     handles   => {
				   'push_seq_results'    => 'push',
				   'pop_seq_results'     => 'pop',
				   'shift_seq_results'   => 'shift',
				   'unshift_seq_results' => 'unshift',
				   'clear_seq_results'   => 'clear',
				  },
		    );


enum 'PeakFitBackends' => ['ifeffit', 'larch', 'fityk'];
coerce 'PeakFitBackends',
  from 'Str',
  via { lc($_) };
has backend => (is => 'rw', isa => 'PeakFitBackends', coerce => 1, alias => 'md',
		trigger => sub{my ($self, $new) = @_;
			       if (($new eq 'fityk') and (not $Fityk_exists)) {
				 warn "The Fityk peak fitting backend is not available, falling back to Ifeffit.\n";
				 $new = 'ifeffit';
			       };
			       if ($new eq 'ifeffit') {
				 eval {apply_all_roles($self, 'Demeter::PeakFit::Ifeffit')};
				 #print $@;
				 $@ and die("PeakFit backend Demeter::PeakFit::Ifeffit could not be loaded");
				 $self->initialize;
			       } elsif ($new eq 'larch') {
				 eval {apply_all_roles($self, 'Demeter::PeakFit::Larch')};
				 #print $@;
				 $@ and die("PeakFit backend Demeter::PeakFit::Larch does not exist");
				 $self->initialize;
			       } elsif ($new eq 'fityk') {
				 eval {apply_all_roles($self, 'Demeter::PeakFit::Fityk')};
				 #print $@;
				 $@ and die("PeakFit backend Demeter::PeakFit::Fityk does not exist");
				 $self->initialize;
			       } else {
				 eval {apply_all_roles($self, 'Demeter::PeakFit'.$new)};
				 $@ and die("PeakFit backend Demeter::PeakFit::$new does not exist");
				 $self->initialize;
			       };
			     });

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_PeakFit($self);
  return $self;
};

override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  foreach my $att (qw{lineshapes}) {
    delete $all{$att};
  };
  return %all;
};

sub cleantemp {
  my ($self) = @_;
  foreach my $f (@{ $self->tempfiles }) {
    unlink $f;
  };
  $self -> clear_tempfiles;
  return $self;
};

sub add {
  my ($self, $function, @args) = @_;
  $function = $self->normalize_function($function);
  croak("$function is not a valid lineshape") if not $self->valid($function);

  my %args = @args;
  $args{a0}   ||= $args{height} || $args{yint}  || 0.3;
  $args{a1}   ||= $args{center} || $args{slope} || 0;
  $args{a2}   ||= $args{hwhm}   || $args{sigma} || $args{width} || $self->defwidth;
  $args{a3}   ||= $args{eta}    || 0;
  $args{a4}   ||= 0;
  $args{a5}   ||= 0;
  $args{a6}   ||= 0;
  $args{a7}   ||= 0;
  $args{a8}   ||= 0;
  $args{fix0} ||= $args{fixheight} || $args{fixyint}  || 0;
  $args{fix1} ||= $args{fixcenter} || $args{fixslope} || 0;
  $args{fix2} ||= $args{fixhwhm}   || $args{fixsigma} || $args{fixwidth} || 0;
  $args{fix3} ||= $args{fixeta}    || 0;
  $args{fix4} ||= 0;
  $args{fix5} ||= 0;
  $args{fix6} ||= 0;
  $args{fix7} ||= 0;
  $args{fix8} ||= 0;
  $args{name} ||= 'Lineshape';
  ## set defaults of things

  my $this = Demeter::PeakFit::LineShape->new(function=>$function,
					      a0 => $args{a0}, a1 => $args{a1},
					      a2 => $args{a2}, a3 => $args{a3},
					      a4 => $args{a4}, a5 => $args{a5},
					      a6 => $args{a6}, a7 => $args{a7},
					      fix0 => $args{fix0}, fix1 => $args{fix1},
					      fix2 => $args{fix2}, fix3 => $args{fix3},
					      fix4 => $args{fix4}, fix5 => $args{fix5},
					      fix6 => $args{fix6}, fix7 => $args{fix7},
					      name => $args{name},
					      parent => $self,
					     );

  my $start = 0;
  foreach my $in_model (@{$self->lineshapes}) {
    $start += $in_model->np;
    foreach my $n (0 .. $in_model->np-1) {
      my $att = "fix$n";
    };
  };
  $this->start($start);		# what is this?

  $self->push_lineshapes($this);
  return $this;
};

sub compute_ninfo {
  my ($self) = @_;
  my $ni = 0;
  ## for XANES divide the data range by the core-hole lifetime
  $ni =($self->xmax - $self->xmin) / Xray::Absorption->get_gamma($self->data->bkg_z, $self->data->fft_edge);
  $self->ninfo(sprintf("%.3f",$ni));
  return $ni;
};


sub fit {
  my ($self, $nofit) = @_;
  $nofit ||= 0;
  $self->start_spinner("Demeter is performing a peak fit")
    if (($self->mo->ui eq 'screen') and not $self->doing_seq and not $nofit);

  $self->data->_update('fft');
  ## this does the right stuff for XES/Data
  $self->compute_ninfo;# if not $self->ninfo;
  #my @save = $self->get(qw(xmin xmax));
  my ($emin, $emax) = $self->data->prep_peakfit($self->xmin, $self->xmax);
  $self->xmin($emin);
  $self->xmax($emax);

  $self->cleantemp;

  ## import data into Fityk
  #$FITYK->load_data(0, \@x, \@y, \@s, $self->name);
  if (@{$self->linegroups}) {    # clean up from previous fit
    $self->cleanup($self->linegroups);
    $self->clear_linegroups;
  };
  $self->prep_data;

  ## define each lineshape
  my @all = ();
  my $np = 0;
  foreach my $ls (@{$self->lineshapes}) {
    $ls->set(xmin=>$emin, xmax=>$emax);
    $self->define($ls);
    push @all, $self->sigil.$ls->group;
    foreach my $i (0 .. $ls->np-1) {
      my $att = "fix$i";
      ++$np if not $ls->$att;
    };
  };
  $self -> linegroups(\@all);
  $self -> nparam($np);

  $self->pf_dispose($self->fit_command($nofit));
  my @data_x = $self->fetch_data_x;
  my @model_y = $self->fetch_model_y(\@data_x);
  $self->place_array($self->group.".".$self->xaxis, \@data_x) if @data_x;
  $self->place_array($self->group.".".$self->yaxis, \@model_y);
  $self -> ndata($#model_y+1);
  $self -> resid;

  ## gather arrays for each lineshape
  foreach my $ls (@{$self->lineshapes}) {
    $self->put_arrays($ls, \@data_x);
  };
  $self->post_fit(\@all);

  $self->fetch_statistics;
  #$self -> xmin($save[0]);
  #$self -> xmax($save[1]);

  $self->stop_spinner
    if (($self->mo->ui eq 'screen') and not $self->doing_seq and not $nofit);
  return $self;
};


sub sequence {
  my ($self, @groups) = @_;
  my $first = $self->data;
  my @data = ($self->include_caller) ? uniq($first, @groups) : uniq(@groups);
  my $nfits = $#data+1;

  $self->doing_seq(1);
  $self->start_counter("Performing a sequence of Peak fits", $nfits) if ($self->mo->ui eq 'screen');
  my @results = ();
  my $count = 1;
  my @save = $self->get(qw(xmin xmax));

  foreach my $d (@data) {
    $self->seq_count($count);
    $self->count if ($self->mo->ui eq 'screen');
    $self->call_sentinal;
    $self->xmin($save[0]);
    $self->xmax($save[1]);
    $self->data($d);

    $self->fit;
    $self->plot if $self->co->default('peakfit', 'plot_during');

    my %fit = (
	       Rfactor => $self->rfactor,
	       Chinu   => $self->chinu,
	       Chisqr  => $self->chisqr,
	       Nparam  => $self->nparam,
	       Ninfo   => $self->ninfo,
	       Ndata   => $self->ndata,
	       Data    => $d->group,
	       Xmin    => $save[0],
	       Xmax    => $save[1],
	      );
    foreach my $ls (@{$self->lineshapes}) { # use of capitalized keys above avoid key collision
      $fit{$ls->group} = [$ls->get(qw(function name a0 e0 fix0 a1 e1 fix1 a2 e2 fix2 a3 e3 fix3))];
    };
    ##Demeter->Dump(\%fit);
    push @results, \%fit;
    ++$count;
  };


  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->data($first);
  my $which = "lcf_prep";
  $self->dispense("analysis", 'peak_prep');
  $self->set(doing_seq=>0, seq_results=>\@results);
  $self->restore($results[1]);
  ##Demeter->Dump($self->seq_results);
  $self->plot_fit if $self->co->default('lcf', 'plot_during');
  return $self;
};




sub restore {
  my ($self, $rhash) = @_;
  $self->rfactor($rhash->{Rfactor});
  $self->chinu($rhash->{Chinu});
  $self->chisqr($rhash->{Chisqr});
  $self->nparam($rhash->{Nparam});
  $self->ninfo($rhash->{Ninfo});
  $self->ndata($rhash->{Ndata});
  $self->xmin($rhash->{Xmin});
  $self->xmax($rhash->{Xmax});
  $self->data(Demeter->mo->fetch("Data", $rhash->{Data}));
  my @data_x = $self->fetch_data_x;
  foreach my $ls (@{$self->lineshapes}) { # use of capitalized keys above avoid key collision
    my $gp = $ls->group;
    #local $|=1;
    #Demeter->Dump($rhash->{$gp});
    $ls->a0  ($rhash->{$gp}->[2]);
    $ls->e0  ($rhash->{$gp}->[3]);
    $ls->fix0($rhash->{$gp}->[4]);
    $ls->a1  ($rhash->{$gp}->[5]);
    $ls->e1  ($rhash->{$gp}->[6]);
    $ls->fix1($rhash->{$gp}->[7]);
    $ls->a2  ($rhash->{$gp}->[8]);
    $ls->e2  ($rhash->{$gp}->[9]);
    $ls->fix2($rhash->{$gp}->[10]);
    $ls->a3  ($rhash->{$gp}->[11]);
    $ls->e3  ($rhash->{$gp}->[12]);
    $ls->fix3($rhash->{$gp}->[13]);
  };
  $self->fit(1);
};


sub report_excel {
  my ($self, $fname) = @_;
  my @stats  = qw(rfactor chinu chisqr ndata nparam ninfo);
  my @names  = map {$_->name} @{$self->lineshapes};

  my $workbook;
  {
    ## The evals in Spreadsheet::WriteExcel::Workbook::_get_checksum_method
    ## will set the eval error variable ($@) if any of Digest::XXX
    ## (XXX = MD4 | PERL::MD4 | MD5) are not installed on the machine.
    ## This is not a problem -- crypto is not needed in the exported
    ## Excel file.  However, setting $@ will post a warning given that
    ## $SIG{__DIE__} is defined to use Wx::Perl::Carp.  So I need to
    ## locally undefine $SIG{__DIE__} to avoid having a completely
    ## pointless error message posted to the screen when the S::WE
    ## object is instantiated
    local $SIG{__DIE__} = undef;
    $workbook = Spreadsheet::WriteExcel->new($fname);
  };
  my $worksheet = $workbook->add_worksheet();

  my $head = $workbook->add_format();
  $head -> set_bold;
  $head -> set_bg_color('grey');
  $head -> set_align('left');
  my $group = $workbook->add_format();
  $group -> set_bold;
  $group -> set_bg_color('grey');
  $group -> set_align('left');


  my $col = 0;
  $worksheet->write(1, $col++, 'Data', $head);
  foreach my $s (@stats) {
    $worksheet->write(1, $col++, $s, $head);
  };
  my $k = 0;
  foreach my $n (@{$self->lineshapes}) {
    $worksheet->write(1, $col,   'function', $head);
    $worksheet->write(1, $col+1, 'height',   $head);
    $worksheet->write(1, $col+2, 'error',    $head);
    $worksheet->write(1, $col+3, 'centroid', $head);
    $worksheet->write(1, $col+4, 'error',    $head);
    $worksheet->write(1, $col+5, 'width',    $head);
    $worksheet->write(1, $col+6, 'error',    $head);
    if ($n->nparams == 4) {
      $worksheet->merge_range(0,  $col, 0, $col+8, $n->name, $group);
      $worksheet->write(1, $col+7, 'gamma',    $head);
      $worksheet->write(1, $col+8, 'error',    $head);
      $col+=9;
    } else {
      $worksheet->merge_range(0,  $col, 0, $col+6, $n->name, $group);
      $col+=7;
    };
    ++$k;
  };

  my $row = 2;
  $col = 0;
  foreach my $res (@{$self->seq_results}) {
    $worksheet->write($row, $col++, $self->mo->fetch('Data', $res->{Data})->name);
    foreach my $s (@stats) {
      $worksheet->write($row, $col++, $res->{ucfirst($s)});
    };
    foreach my $n (@{$self->lineshapes}) {
      $worksheet->write($row, $col++, $res->{$n->group}->[0]);
      $worksheet->write($row, $col++, $res->{$n->group}->[2]);
      $worksheet->write($row, $col++, $res->{$n->group}->[3]);
      $worksheet->write($row, $col++, $res->{$n->group}->[5]);
      $worksheet->write($row, $col++, $res->{$n->group}->[6]);
      $worksheet->write($row, $col++, $res->{$n->group}->[8]);
      $worksheet->write($row, $col++, $res->{$n->group}->[9]);
      if ($n->nparams == 4) {
	$worksheet->write($row, $col++, $res->{$n->group}->[11]);
	$worksheet->write($row, $col++, $res->{$n->group}->[12]);
      };
    };
    ++$row;
    $col=0;
  };
  $workbook->close;
};



sub plot {
  my ($self) = @_;
  $self -> po -> set(e_norm   => 1,
		     e_markers=> 1,
		     e_bkg    => 0,
		     e_der    => 0,
		     e_sec    => 0,
		     emin     => $self->xmin - $self->data->bkg_e0 - 10,
		     emax     => $self->xmax - $self->data->bkg_e0 + 10,);


  $self->po->start_plot;
  $self->data->plot('E');
  $self->chart('plot', 'overpeak', {suffix=>'func', thiskey=>$self->name});
  $self->po->increment;
  if ($self->plot_residual) {
    ## prep the residual plot
    my $save = $self->yaxis;
    my $yoff = $self->data->y_offset;
    $self->yaxis('resid');
    $self->data->plotkey('residual');
    my @y = $self->data->get_array($save);
    $self->data->y_offset($self->data->y_offset - 0.1*max(@y));

    $self->chart('plot', 'overpeak', {suffix=>'resid', thiskey=>'residual'});

    ## restore values and increment the plot
    $self->yaxis($save);
    $self->data->plotkey(q{});
    $self->data->y_offset($yoff);
    $self->po->increment;
  };
  if ($self->plot_components) {
    foreach my $ls (@{$self->lineshapes}) {
      if (Demeter->mo->template_analysis eq 'larch') {
	$self->chart('plot', 'overpeak', {suffix=>$ls->group, thiskey=>$ls->name});
      } else {
	$ls->chart('plot', 'overpeak', {suffix=>'func', thiskey=>$ls->name});
      };
      $self->po->increment;
    };
  };
  return $self;
};


sub report {
  my ($self) = @_;
  my $string = $self->template("analysis", "peak_report");
  foreach my $ls (@{$self->lineshapes}) {
    $string .= $ls->report;
  };
  return $string;
};


sub clean {
  my ($self) = @_;
  # if (@{$self->linegroups}) {    # clean up from previous fit
  #   $self->cleanup($self->linegroups);
  #   $self->clear_linegroups;
  # };
  $self->cleanup($self->linegroups);
  foreach my $ls (@{$self->lineshapes}) {
    $ls->DEMOLISH;
  };
  $self->clear_lineshapes;
  $self->clear_linegroups;
  return $self;
};

sub save {
  my ($self, $filename) = @_;
  my $text = $self->template('analysis', 'peak_header');
  my @titles = split(/\n/, $text);
  $self->ntitles($#titles + 1);
  $text .= $self->template("analysis", "peak_save", {filename=>$filename});
  $self->dispose($text);
  return $self;
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::PeakFit - A peak fitting object for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

Here is a simple fit of three peak shapes to normalized XES data.

  #!/usr/bin/perl
  use Demeter qw(:ui=screen :plotwith=gnuplot);

  my $xes = Demeter::XES->new(file=>'../XES/7725.11',
                              energy => 2, emission => 3,
                              e1 => 7610, e2 => 7624, e3 => 7664, e4 => 7690,
                             );
  my $peak = Demeter::PeakFit->new(screen => 0, yaxis=> 'norm', name=>'fit');
  $peak -> data($xes);

  $peak -> add('gaussian',   center=>7649.5, name=>'peak 1');
  $peak -> add('gaussian',   center=>7647.7, name=>'peak 2');
  $peak -> add('lorentzian', center=>7636.8, name=>'peak 3');

  $peak -> fit;
  print $peak -> report;
  $_  -> plot('norm') foreach ($xes, $peak, @{$peak->lineshapes});
  $peak -> pause;

=head1 DESCRIPTION

This object is a sort of container for holding Data (either XANES data
in a normal Data object or XES data in an XES object) along with some
number of lineshapes.  It organizes the parameterization of the
lineshapes and shuffles all of this off to the fitting engine for
fitting, all wihtout having to master whatever quirky syntax it might
have.

=head1 FITTING ENGINES

This module provides an abstract framework for enabling peak fitting
in Demeter.  This abstraction allows (well ... in principle) the use
of various backends for performing the actual fit.  Currently the only
one available is Fityk (http://www.unipress.waw.pl/fityk/), which is
implemented as L<Demeter::PeakFit::Fityk>.

Any suggestions?

=head1 ATTRIBUTES

=over 4

=item C<screen> (boolean) [0]

This is a flag telling Demeter to echo instructions to the screen.

=item C<engine> (boolean) [1]

This is a flag telling Demeter to echo instructions to the fitting engine
process.

=item C<buffer>

Dispose commands to a string or array when given a reference to a
string or array.  This allows you to accumulate instructions in a
string or an array an save them for future use, e.g. writing a script
or displaying a text widget in a GUI.

=item C<xaxis> (string) [energy]

The string denoting the array containing the ordinate axis of the
data.  For most XANES and XES data, this is C<energy>.

=item C<yaxis> (string) [flat]

The string denoting the array containing the abscisa axis of the data.
For most XANES, this is typically either C<flat> or C<norm>.  For XES
data, this might be C<raw>, C<sub>, or C<norm>.  Note that the default
will trigger an error if you try to fit XES data without changing its
value appropriately.

=item C<sigma> (string) []

The string denoting the array containing the varience of the data.

=item C<xmin> (float)

The lower bound of the fit range.  For XANES data, this will be
interpreted relative to the edge, while for XES data it is
intepretated as an absolute energy.

=item C<xmax> (float)

The upper bound of the fit range.  For XANES data, this will be
interpreted relative to the edge, while for XES data it is
intepretated as an absolute energy.

=item C<lineshapes>

This contains a reference to the array of LineShape objects included
in the fit.  This array can be manipulated with the standard Moose-y
sort of automatically generated methods:

  push_lineshapes
  pop_lineshapes
  shift_lineshapes
  unshift_lineshapes
  clear_lineshapes

=back

=head1 METHODS

=over 4

=item C<add>

Use this to add new lineshapes to the fitting model.

  $ls = $peak -> add("Gaussian", center => 4967, name => "First peak")

This returns a F<Demeter::PeakFit::LineShape> object.  This is the
standard way of creating such an object as this properly associates
the LineShape object with the current peak fitting effort.  It should
never be necessary (or desirable) to create a LineShape by hand.

=item C<fit>

Perform the fit after adding one or more LineShapes.

  $peak -> fit;

After the fit finishes, the statistics of the fit will be accumulated
from the fitting engine and stored in this and all the LineShape
objects.

=item C<engine_object>

This returns the object for interacting with the fitting engine (if
there is one).  This is used extensively by
F<Demeter::PeakFit::LineShape>.

=item C<plot>

Use this to plot the result of the fit.  Note that this only plots the
full model and (optionally) the residual.  To plot the individual
function, use the C<plot> method of the the LineShape object.

This plots the data along with the fitting model and each function:

  $xanes_data -> po -> e_norm(1);
  $_ -> plot('E') foreach ($xanes_data, $peak, @{$peak->lineshapes});

Note that the C('E') argument and the setting of C<e_norm> are ignored
by the PeakFit and LineShape objects, but they are required to plot a
fit to XANES data as the fit is made to the normalized data.  In fact,
the fit is made to the flattened data if the Data's C<bkg_flatten>
attribute is true.

For a fit to raw XES data, you might make the plot like so:

  $_ -> plot('raw') foreach ($xanes_data, $peak, @{$peak->lineshapes});

Specifically, you want to plot the data in the manner indicated by the
C<yaxis> attribute of the PeakFit object, which indicates the form of
the data used in the fit.

When the PeakFit object is plotted, the residual from the fit will
also be plotted if the C<plot_res> attribute of the Plot object is
true.

=item C<pf_dispose>

This is the choke point for sending instructions to the fitting
engine, much like the normal C<dispose> method handles text intended
for Ifeffit or Gnuplot.  See the descriptions of the C<engine> and
C<screen> attributes.

=item C<report>

This returns a tring summarizing the results of a fit.

  print $peak->report;

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

How to capture errors without bailing?

=item *

more testing with xanes data

=item *

better interface for fixing parameters

=item *

need to test more functions

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
