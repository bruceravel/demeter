package Demeter::Path;

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

use autodie qw(open close);

use Moose;
use MooseX::Aliases;
extends 'Demeter';
use Demeter::StrTypes qw( Empty PathParam FileName );
use Demeter::NumTypes qw( Natural PosInt NonNeg );

with 'Demeter::Data::Arrays';
with 'Demeter::Data::IO';
with 'Demeter::Path::Process';
with 'Demeter::Path::Sanity';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

use Carp;
use File::Copy;
use File::Spec;
use List::Util qw(max);
use Regexp::Assemble;
use Scalar::Util qw(looks_like_number);

has '+plottable'      => (default => 1);
has '+pathtype'       => (default => 1);
has '+data'           => (isa => Empty.'|Demeter::Data');
has 'label'	      => (is=>'rw', isa=>'Str', default => q{});

has 'n'		      => (is=>'rw', isa=>'Num', default =>  0);

has 's02'	      => (is=>'rw', isa=>'Str', default => '1'); # trigger value into _stored
has 's02_stored'      => (is=>'rw', isa=>'Str', default => '1');
has 's02_value'	      => (is=>'rw', isa=>'Num', default =>  1);

has 'e0'	      => (is=>'rw', isa=>'Str', default => '0');
has 'e0_stored'	      => (is=>'rw', isa=>'Str', default => '0');
has 'e0_value'	      => (is=>'rw', isa=>'Num', default =>  0);

has 'delr'	      => (is=>'rw', isa=>'Str', default => '0');
has 'delr_stored'     => (is=>'rw', isa=>'Str', default => '0');
has 'delr_value'      => (is=>'rw', isa=>'Num', default =>  0);

has 'sigma2'	      => (is=>'rw', isa=>'Str', default => '0');
has 'sigma2_stored'   => (is=>'rw', isa=>'Str', default => '0');
has 'sigma2_value'    => (is=>'rw', isa=>'Num', default =>  0);

has 'ei'	      => (is=>'rw', isa=>'Str', default => '0');
has 'ei_stored'	      => (is=>'rw', isa=>'Str', default => '0');
has 'ei_value'	      => (is=>'rw', isa=>'Num', default =>  0);

has 'third'	      => (is=>'rw', isa=>'Str', default => '0');
has 'third_stored'    => (is=>'rw', isa=>'Str', default => '0');
has 'third_value'     => (is=>'rw', isa=>'Num', default =>  0);

has 'fourth'	      => (is=>'rw', isa=>'Str', default => '0');
has 'fourth_stored'   => (is=>'rw', isa=>'Str', default => '0');
has 'fourth_value'    => (is=>'rw', isa=>'Num', default =>  0);

has 'dphase'	      => (is=>'rw', isa=>'Str', default => '0');
has 'dphase_stored'   => (is=>'rw', isa=>'Str', default => '0');
has 'dphase_value'    => (is=>'rw', isa=>'Num', default =>  0);

has 'id'	      => (is=>'rw', isa=>'Str', default => q{});
has 'k_array'	      => (is=>'rw', isa=>'Str', default => q{});
has 'amp_array'	      => (is=>'rw', isa=>'Str', default => q{});
has 'phase_array'     => (is=>'rw', isa=>'Str', default => q{});

## these four provide a generic way of storing cumulant information
## about a Path or Path-like object.  this is used, for instance, in
## Demeter::Feff::Distributions to store the cumulants computed from
## the SS distribution in an FPath object created from a histogram
has 'c1'              => (is=>'rw', isa=>'Num', default =>  0, documentation => "the computed first cumulant");
has 'c2'              => (is=>'rw', isa=>'Num', default =>  0, documentation => "the computed second cumulant");
has 'c3'              => (is=>'rw', isa=>'Num', default =>  0, documentation => "the computed third cumulant");
has 'c4'              => (is=>'rw', isa=>'Num', default =>  0, documentation => "the computed fourth cumulant");


## object relationships
has 'parentgroup'     => (is=>'rw', isa => 'Str', default => q{});
has 'parent'          => (is=>'rw', isa => 'Any', default => q{},  # Empty.'|Demeter::Feff'
			  trigger => \&set_parent,
			  alias   => 'feff');
has 'spgroup'         => (is=>'rw', isa => 'Str', default => q{});
has 'sp'              => (is=>'rw', isa => 'Any',                  # Empty.'|Demeter::ScatteringPath|Demeter::SSPath'
			  trigger => sub{ my($self, $new) = @_; 
					  if ($new) {
					    $self->zcwif($new->zcwif);
					    $self->spgroup($new->group);
					    $self->parent($new->feff) if not $self->parent;
					    $self->make_name if not $self->name;
					  };
					});
has 'datagroup'       => (is=>'rw', isa => 'Str', default => q{});



has 'folder'          => (is=>'rw', isa=> 'Str',    default => q{},
			  trigger => sub{ shift->parse_nnnn });
has 'file'            => (is=>'rw', isa=> 'Str',    default => q{},
			  trigger => sub{ shift->parse_nnnn });
has 'Index'           => (is=>'rw', isa=>  Natural, default => 0);
has 'include'         => (is=>'rw', isa=>  'Bool',  default => 1);

has 'is_col'          => (is=>'rw', isa=>  'Bool',  default => 0);
has 'is_ss'           => (is=>'rw', isa=>  'Bool',  default => 1);
has 'plot_after_fit'  => (is=>'rw', isa=>  'Bool',  default => 0);
has 'default_path'    => (is=>'rw', isa=>  'Bool',  default => 0);
has 'pc'              => (is=>'rw', isa=>  'Bool',  default => 0);

## feff interpretation parameters
has 'degen'           => (is=>'rw', isa=>  NonNeg,  default => 0);
has 'nleg'            => (is=>'rw', isa=>  PosInt,  default => 2);
has 'reff'            => (is=>'rw', isa=> 'Num',    default => 0);
has 'zcwif'           => (is=>'rw', isa=> 'Num',    default => 0, alias => 'population');
has 'intrpline'       => (is=>'rw', isa=> 'Str',    default => q{});
has 'geometry'        => (is=>'rw', isa=> 'Str',    default => q{});

## data processing flags
has 'update_path'     => (is=>'rw', isa=>  'Bool',  default => 1,
			  trigger => sub{ my($self, $new) = @_; $self->update_fft(1) if $new});
has 'update_fft'      => (is=>'rw', isa=>  'Bool',  default => 1,
			  trigger => sub{ my($self, $new) = @_; $self->update_bft(1) if $new});
has 'update_bft'      => (is=>'rw', isa=>  'Bool',  default => 1);

my $pp_regex = Regexp::Assemble->new()->add(qw(s02 e0 delr e0 sigma2 ei third fourth dphase))->re;

sub BUILD {
  my ($self, @arguments) = @_;
  my $val = $self->get_mode("datadefault");
  if ((ref($self->data) !~ m{Data}) and (ref($val) !~ m{Data})) {
    $self->mo->datadefault(Demeter::Data->new(group=>'default___',
					      name=>'default___',
					      fft_kmin=>3, fft_kmax=>15,
					      bft_rmin=>1, bft_rmax=>6,
					     ));
  };
  $self->data($self->mo->datadefault) if (ref($self->data) !~ m{Data});
  $self->mo->push_Path($self) if (ref($self) eq "Demeter::Path"); # don't do this for SSPath objects
  my $i = $self->mo->pathindex;
  $self->Index($i);
  $self->mo->pathindex(++$i);
};
#sub DEMOLISH {
#  my ($self) = @_;
#  $self->alldone;
#};

override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  delete $all{$_} foreach (qw(Index sp parent sentinal));
  return %all;
};

override clone => sub {
  my ($self, @arguments) = @_;
  my $new = $self->SUPER::clone();
  $new->parent($self->parent);
  $new->data($self->data);
  $new->sp($self->sp);

  $new->set(@arguments);
  return $new;
};

sub set_parent {
  my ($self, $feff) = @_;
  $self->set_parent_method($feff);
};
sub set_parent_method {
  my ($self, $feff) = @_;
  $self->parentgroup($feff->group) if $feff;
};

### ---- this will be different working from a ScatteringPath object
###      snarfing from the object will have to be part of an update
sub _update {
  my ($self, $which) = @_;
  $which = lc($which);
 WHICH: {
    ($which eq 'path') and do {
      $self->path(1) if $self->update_path;
      last WHICH;
    };
    ($which eq 'fft') and do {
      $self->path(1) if ($self->update_path);
      last WHICH;
    };
    ($which eq 'bft') and do {
      $self->path(1) if ($self->update_path);
      $self->fft     if ($self->update_fft);  #<--- kweight may have changed, just redo this
      last WHICH;
    };
    ($which eq 'all') and do {
      $self->path(1) if ($self->update_path);
      $self->fft     if ($self->update_fft);
      $self->bft     if ($self->update_bft);
      last WHICH;
    };
  };
  $self->ifeffit_heap;
  return $self;
};

sub rm {
  my ($self) = @_;
  unlink File::Spec->catfile($self->get(qw(folder file)));
  return $self;
};

#sub read_data {
#  my ($self) = @_;
#  my $string = $self->read_data('feff.dat');
#  return $string;
#};


## need a make_name for a path that does not come from ScatteringPath
sub make_name {
  my ($self) = @_;
  my $sp = $self->sp;
  my $pattern = $self->co->default("pathfinder", "label");
  my $token = $self->co->default("pathfinder", "token");
  my $noends = $sp->intrplist;
  my $re = qr(\Q$token\E);	# \Q...\E quotes the metacharacters, see perlre
  $noends =~ s{\A$re}{};
  $noends =~ s{$re\z}{};
  my %table = (i   => $self->Index,
	       I   => sprintf("%4.4d", $self->Index),
	       p   => $sp->intrplist,
	       P   => $noends,
	       r   => sprintf("%.3f", $sp->fuzzy),
	       n   => $sp->nleg,
	       d   => $sp->n,
	       t   => $sp->Type,
	       m   => $sp->weight,
	       g   => $sp->group,
	       f   => $sp->feff->name,
	       '%' => '%',
	      );
  my $regex = '[' . join('', keys(%table)) . ']';

  $pattern =~ s{\%($regex)}{$table{$1}}g;
  $pattern =~ s{\s+}{ }g;
  $pattern =~ s{\A\s+}{ }g;
  $pattern =~ s{\s+\z}{ }g;
  $self->label($pattern);

  $pattern = $self->co->default("pathfinder", "name");
  $pattern =~ s{\%($regex)}{$table{$1}}g;
  $pattern =~ s{\s+}{ }g;
  $self->name($pattern);
  return $self;
};



## how to handle extended path parameters?
## $index, $folder, $stash_dir all need to be known to the object
sub path {
  my ($self, $do_ff2chi) = @_;
  $self->_update_from_ScatteringPath if $self->sp;
  $self->dispose($self->_path_command($do_ff2chi));
  $self->update_path(0);
  return $self;
};
sub _update_from_ScatteringPath {
  my ($self) = @_;
  #print $/, join("|", ">>>>", $self->data->name, $self->reff, $self->sp->fuzzy), $/;
  ## generate from a ScatteringPath object
  my $sp     = $self->sp;
  my $feff   = $self->parent;
  my ($workspace, $fname) = ($feff->workspace, $sp->randstring);

  ## this feffNNNN.dat has already been generated
  if ($fname and (-e File::Spec->catfile($workspace, $fname))) {
    #print File::Spec->catfile($workspace, $fname), $/;
    #print join("|", "||||", $self->data->name, $self->reff, $self->sp->fuzzy), $/, $/;
    $self->set(folder => $workspace,
	       file   => $fname);
    return $self;
  };

  $feff -> make_one_path($sp)
    -> make_feffinp("genfmt")
      -> run_feff;
  $self -> make_name if not $self->name;

  my $tempfile = "feff" . $self->co->default('pathfinder', 'one_off_index') . ".dat";
  $fname ||= $sp->random_string;
  move(File::Spec->catfile($workspace, $tempfile),
       File::Spec->catfile($workspace, $fname));
  $self->set(folder => $workspace,
	     file   => $fname);
  $self->sp->set(folder => $workspace,
		 file   => $fname);
  ##print "++", File::Spec->catfile($workspace, $fname), $/;
  my $label = $self -> name || $sp->intrplist;
  $self->set(name=>$label);
  #print join("|", "<<<<", $self->data->name, $self->reff, $self->sp->fuzzy), $/, $/;

  unlink File::Spec->catfile($feff->workspace, "paths.dat");
  unlink File::Spec->catfile($feff->workspace, "feff.run");
  unlink File::Spec->catfile($feff->workspace, "nstar.dat");
  if (not $feff->save) {
    unlink File::Spec->catfile($feff->workspace, "feff.inp");
    unlink File::Spec->catfile($feff->workspace, "files.dat");
  };
  return $self;
};
sub _path_command {
  my ($self, $do_ff2chi) = @_;
  ## fret about long file names
  my $string = $self->template("fit", "path");
  $string   .= $self->template("fit", "ff2chi") if $do_ff2chi;
  return $string;
};
sub rewrite_cv {
  my ($self) = @_;
  my $data   = $self->data;
  my $cv     = $data->cv;
  #$cv       =~ s{\.}{_}g;
  foreach my $pp (qw(e0 ei sigma2 s02 delr third fourth dphase)) {
    my $me = $self->$pp;
    $me =~ s{\[?cv\]?}{$cv}g;
    $self->$pp($me);
  };
  foreach my $pp (qw(name label)) {
    my $this = $self->$pp;
    $this =~ s{\[cv\]}{$cv}g;
    $self->$pp($this);
  };
};

sub plot {
  my ($self, $space) = @_;
  $space ||= $self->po->space;
  my $which = q{update_path};
  if (lc($space) =~ m{\Ak}) {
    $self -> _update("fft");
    $which = "update_path";
  } elsif (lc($space) =~ m{\Ar}) {
    $self -> _update("bft");
    $which = "update_fft";
  } elsif (lc($space) eq 'q') {
    $self -> _update("all");
    $which = "update_bft";
  };
  $self->mo->path($self);
  $self->dispose($self->_plot_command($space), "plotting");
  $self->po->after_plot_hook($self);
  $self->mo->path(q{});
  $self->po->increment;
  $self->$which(0);
};

sub save {
  my ($self, $what, $filename) = @_;
  croak("No filename specified for save") unless $filename;
  ($what = 'chi') if (lc($what) eq 'k');
  croak("Valid save types are: chi r q") if ($what !~ m{\A(?:chi|r|q)\z});
 WHAT: {
    (lc($what) eq 'chi') and do {
      $self->_update("path");
      $self->data->_update('bft'); # need window from data object
      $self->dispose($self->_save_chi_command('k', $filename));
      last WHAT;
    };
    (lc($what) eq 'r') and do {
      $self->_update("bft");
      $self->data->_update('all');
      $self->dispose($self->_save_chi_command('r', $filename));
      last WHAT;
    };
    (lc($what) eq 'q') and do {
      $self->_update("all");
      $self->data->_update('bft');
      $self->dispose($self->_save_chi_command('q', $filename));
      last WHAT;
    };
  };
};


sub parse_nnnn {
  my ($self) = @_;
  my $oneoff = "feff" . $self->co->default('pathfinder', 'one_off_index');
  my ($folder, $file) = $self->get(qw(folder file));
  my $fname = $self->follow_link(File::Spec -> catfile($folder, $file));
  return if not -f $fname;

  open (my $NNNN, $fname);
  my ($header, $geometry) = (0, q{});
  while (<$NNNN>) {
    if (m{\A\s*-------}) {
      $header = 1;
      next;
    };
    next if not $header;
    last if m{\A\s+k\s+real};
    $geometry .= $_;
  };
  close $NNNN;
  $self->set(geometry=>$geometry);

  my @list = split(" ", $geometry);
  my $n_set = $self->n;
  $self->set(degen => int($list[1]),
	     n     => $n_set || $list[1],
	     nleg  => $list[0],
	     reff  => $list[2]
	    );
  return 0 if $self->sp;

  $fname = File::Spec -> catfile($folder, 'files.dat');
  if (-e $fname) {
    open (my $FILESDAT, $fname);
    while (<$FILESDAT>) {
      next if ($_ !~ /(?:$file|$oneoff)/); # $oneoff is matched when working from a ScatteringPath object
      @list = split(" ", $_);
      $n_set = $self->n;
      $self->zcwif($list[2]) if (not $self->sp);   # zcwif is imported from the feffNNNN.dat only when
      $self->set(degen => int($list[3]),	   # the sp attribute is not set, otherwise zcwif is inherited
		 n     => $n_set || int($list[3]), # from the ScatteringPath object
		 nleg  => $list[4],
		 reff  => $list[5]
		);
    };
    close $FILESDAT;
  };
  return 0;
};


my %_pp_trans = ('3rd'=>"third", '4th'=>"fourth", dphase=>"dphase",
		 dr=>"delr", e0=>"e0", ei=>"ei", s02=>"s02", ss2=>"sigma2");
sub fetch {
  my ($self) = @_;

  my $save = Ifeffit::get_scalar("\&screen_echo");

  ## not using dispose so that the get_echo lines gets captured here
  ## rather than in the dispose method
  Ifeffit::ifeffit("\&screen_echo = 0\n");
  Ifeffit::ifeffit(sprintf("show \@path %d\n", $self->Index));

  my $lines = Ifeffit::get_scalar('&echo_lines');
  if (not $lines) {
    $self->dispose("\&screen_echo = $save\n") if $save;
    #return;
  };
  my $found = 0;
  foreach my $l (1 .. $lines) {
    my $response = Ifeffit::get_echo()."\n";
    ($found = 1), next if ($response =~ m{\A\s*PATH}x);
    next if not $found;
    chomp $response;
    my @line = split(/\s+=\s*/, $response);
  SWITCH: {

      ($line[0] eq 'id') and do {
	$self -> set(id=>$line[1]);
	last SWITCH;
      };

      ($line[0] =~ m{(?:3rd|4th|d(?:phase|r)|e[0i]|s[0s]2)}) and do {
	$self -> evaluate($_pp_trans{$line[0]}, $line[1]);
	last SWITCH;
      }

    };
  };

  $self->dispose("\&screen_echo = $save\n") if $save;
  return 0;
};

## path parameter tools
sub evaluate {
  my ($self, $key, $value) = @_;
  my $param = $key."_value";
  if (not looks_like_number($value)) {
    $value = ($key eq 's02') ? 1 : 0;
  };
  $self->$param($value);
  return 0;
};
sub value {
  my ($self, $pathparam) = @_;
  return 0 if (not is_PathParam($pathparam));
  my $key = $pathparam."_value";
  return $self->$key
};

sub identity {
  my ($self) = @_;
  return sprintf("%s", $self->name);
  ##return sprintf("%s : %s", $self->parent->name, $self->name);
};


## log file tools

sub R {
  my ($self) = @_;
  return $self->reff + $self->delr_value;
};
sub longest_leg {
  my ($self) = @_;
  return max(@{ $self -> sp -> rleg });
};
sub paragraph {
  my ($self) = @_;
  my $string = sprintf("    feff   = %s\n",     File::Spec->catfile($self->get(qw(folder file))));
  $string   .= sprintf("    id     = %s\n",     $self->id);
  $string   .= sprintf("    name   = %s\n",     $self->name);
  $string   .= sprintf("    r      = %12.6f\n", $self->R);
  $string   .= sprintf("    degen  = %12.6f\n", $self->n);
  foreach my $pp (qw(s02 e0 delr sigma2 third fourth ei)) {
    $string .= sprintf("    %-6s = %12.6f\n",   $pp, $self->value($pp)||0);
  };
  return $string;
};
sub row_main_label {
  my ($self, $width) = @_;
  $width ||= 15;
  return $self->template("report", "log_firstrow_label",  {width=>$width});
};
sub row_main {
  my ($self, $width) = @_;
  $width ||= 15;
  return $self->template("report", "log_firstrow",        {width=>$width});
}

sub row_second_label {
  my ($self, $width) = @_;
  $width ||= 15;
  return $self->template("report", "log_secondrow_label", {width=>$width});
};
sub row_second {
  my ($self, $width) = @_;
  $width ||= 15;
  return $self->template("report", "log_secondrow",        {width=>$width});
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter - Single and multiple scattering paths for EXAFS fitting


=head1 VERSION

This documentation refers to Demeter version 0.9.


=head1 SYNOPSIS

  $path_object -> new();
  $path_object -> set(data     => $dobject,
		      folder   => 'example/cu/',
		      file     => "feff0001.dat",
		      name     => "path 1",
		      s02      => 'amp',
		      e0       => 'enot',
		      delr     => 'alpha*reff',
		      sigma2   => 'debye(temp, theta) + sigmm',
		     );

or

  $path_object -> new();
  $path_object -> set(data     => $dobject,
                      sp       => $scattering_path_object
		      name     => "path 1",
		      s02      => 'amp',
		      e0       => 'enot',
		      delr     => 'alpha*reff',
		      sigma2   => 'debye(temp, theta) + sigmm',
		     );

=head1 DESCRIPTION

This subclass of the Demeter class is for holding information
pertaining to theoretical paths from Feff for use in a fit.

=head1 ATTRIBUTES

The following are the attributes of the Path object.  Attempting to
access an attribute not on this list will throw and exception.

The type of argument expected in given in parentheses.  Several of the
attributes take an anonymous array as the value.  In each case, the
zeroth element of the annonymous array is the math expressionfor the
path and the first element is its evaluation.  See the discussion
below in L</METHODS> for a description of how these attributes
interacts with the accessor methods.  See also the description of the
C<evaluate> method for how the second element of the anonymous array
gets set.

The defaults for all path parameter math expressions is 0 except for
C<s02>, which is 1.  The C<*_value> path parameter attributes contain
the evaluation of the path parameter after the fit is made or the path
is otherwise evaluated.

For this Path object to be included in a fit, it is necessary that it
be gathered into a Fit object.  See L<Demeter::Fit> for
details.

=head2 General attributes

=over 4

=item C<group> (string)

This is the Ifeffit group name used for this path.  That is, its
arrays will be called I<group>.k, I<group>.chi, and so on.  It is best
if this is a reasonably short word and it B<must> follow the
conventions of a valid group name in Ifeffit.  By default, this is a
random, four-letter string.

=item C<name> (string)

This is a text string used to describe this object in a user
interface.  While the C<group> attribute should be short, this can be
more verbose.  But it should be a single line, unlike the C<title>
attibute.

=item C<parent> (Feff object)

This is the reference to the Feff object that this Path is a part of.
C<feff> is an alias for C<parent>.

=item C<data> (Data object)

This is the reference to the Data object that this path is associated
with.  There exists a default Data object so that you can successfully
Fourier transform and plot Path objects which are not associated with
a Data object, as might be the case for a sum of paths.

=item C<sp> (ScatteringPath object)

This is the reference to the ScatteringPath object that is used to
generate the F<feffNNNN.dat> file.  Once the sp attribute is set,
the file and folder attributes will be overwritten based on the
settings and actions of the Feff and ScatteringPath objects.  To set a
specific F<feffNNNN.dat> file, you must also set the sp attribute to
an empty string.

=item C<folder> (string)

This is a string that takes the fully qualified path (in the file
system sense, not the Ifeffit sense) to the C<`feffNNNN.dat'> file
associated with this Path object.

If the C<SP> attribute is set, then this attribute will be set
automatically and changing it via the Path object's C<set> method will
be forbidden.

=item C<file> (filename)

This is the name of the F<feffNNNN.dat> file associated with this
Path object.

If the C<sp> attribute is set, then this attribute will be set
automatically.

=item C<Index> (integer)

This is the path index as required in the definition of an Ifeffit
Path.  It is rarely necessary to set this by hand.  Indexing is
typically handled by Demeter.  Demeter organization of the fit makes
use of lists of Path objects, so you are encouraged to think that way
rather than to fret about the path indeces.

=item C<include> (boolean)

When this is true, this Path will be included in the next fit.

=item C<plot_after_fit> (boolean)

This is a flag for use by a user interface to indicate that after a
fit is finished, this Path should be plotted.

=item C<default_path> (boolean)

This path will be set to the default path after the fit for the
purpose of evaluating C<def>, C<after>, and other parameters.  This is
only relevant if any C<def>, C<after> or other parameters depend
explicitly on path-specific quantites such as C<reff> or the
evaluation of the Debye or Eins functions.

=item C<pc> (boolean)

This is a flag indicating that the phase of this path should be used
to perform phase corrected plots.

=back

=head2 Path parameters

For each of these (except C<n> and C<id> which do not take math
expressions and the array path parameters which do not evaluate to
scalars), the first item listed is the attribute which takes the math
expression.  The second item listed is the evaluation of the math
expression after the fit is prefromed.  The evaluation cannot be set
by hand.  Instead you must change the values of GDS objects and
re-evaluate the fit using either of the C<fit> or C<sum> methods.

=over 4

=item C<n> (number)

This is the path degeneracy in the definition of an Ifeffit path.
This is a number, not a math expression.  Use the C<s02> attribute to
parameterize the amplitude of the path.

=item C<s02> (string)

=item C<s02_value> (number)

This is the amplitude term for the path.

=item C<e0> (string)

=item C<e0_value> (number)

This is the energy shift term for the path.

=item C<delr> (string)

=item C<delr_value> (number)

This is the path length correction term for the path.

=item C<sigma2> (string)

=item C<sigma2_value> (number)

This is the mean square displacement shift term for the path.

=item C<ei> (string)

=item C<ei_value> (number)

This is the imaginary energy correction term for the path.

=item C<third> (string)

=item C<third_value> (number)

This is the third cumulant term for the path.

=item C<fourth> (string)

=item C<fourth_value> (number)

This is the fourth cumulant term for the path.

=item C<dphase> (string)

=item C<dphase_value> (number)

This is the constant phase shift term for the path.

=item C<id> (string)

This is Ifeffit's identification string for the path.

=item C<k_array> (string)

This takes the math expression for the infrequently used C<k_array>
path parameter.  You really need to know what you are doing to use the
array valued path parameters!

=item C<amp_array> (string)

This takes the math expression for the infrequently used C<amp_array>
path parameter.  You really need to know what you are doing to use the
array valued path parameters!

=item C<phase_array> (string)

This takes the math expression for the infrequently used
C<phase_array> path parameter.  You really need to know what you are
doing to use the array valued path parameters!

=back

=head2 Feff interpretation attributes

Where possible, these attributes will be taken from the ScatteringPath
object associated with the Path.

=over 4

=item C<degen> (number)

This is the degeneracy in the F<feffNNNN.dat> file associated with
this Path object.

=item C<nleg> (integer)

This is the number of legs in the F<feffNNNN.dat> file associated
with this Path object.

=item C<reff> (number)

This is the effective path length in the F<feffNNNN.dat> file
associated with this Path object.

=item C<zcwif> (number)

This is the amplitude (i.e. "Zabinsky curved wave importance factor")
for the F<feffNNNN.dat> file associated with this Path object.

Note that this is always 0 for paths that come from ScatteringPath
objects, since the ScatteringPath objct does not, at this time, have a
way of computing the ZCWIF.

=item C<intrpline> (string)

This is a line of text relating to this path from the interpretation
the Feff calculation.

=item C<geometry> (multiline string)

This is a textual description of the scattering geometry associated
with this path.

=item C<is_col> (boolean)

This is true when the path associated with this object is a colinear
or nearly colinear multiple scattering path.

=item C<is_ss> (boolean)

This is true when the path associated with this object is a single
scattering path.

=back

=head1 METHODS

The Path object inherits creation (C<new> and C<clone>) and accessor
methods (C<set>, C<get>) from the parent class described in the
L<Demeter> documentation.

Additionally the Path object provides these methods:

=head2 I/O methods

=over 4

=item C<save>

This method returns the Ifeffit commands necessary to write column
data files based on the Path object.  See C<Demeter::Data::IO> for
details.  Only the C<chi>, C<r>, and C<q> options are available for
writing Path column data files.

=back

=head2 Convenience methods

=over 4

=item C<data>

This method returns the reference to the Data object that this Path is
associated with.  This method is meant to be used with the Data
object's C<data> method.  Path and Data objects can be put into a loop
and the correct Data object can be identified for each kind of object.

  foreach my $obj (@data_objects, @paths_objects) {
     my $d = $obj->data;
     ## do something with $d
  };

Note that this works because Data objects have a C<data> method which
self-identifies.

=item C<value>

This method returns the evaluated value of a path parameter after a
fit is made or a path is otherwise evaluated.

   my $val = $path_object->value("sigma2");

=item C<rm>

Delete the F<feffNNNN.dat> file associated with this Path.

  $path -> rm;

=back

=head2 Ifeffit interaction methods

=over 4

=item C<read_data>

This is completely different from the C<read_data> method called on a
Data object.  Or, it's exactly the same, depending on your
perspective.  It is not normally necessary to call read_data on a
F<feffNNNN.dat> file in the course of data analysis.  That file is
imported into Ifeffit as a part of the C<write_path> method.

When C<read_data> is called on a Path object, the Ifeffit command for
reading the F<feffNNNN.dat> file as a column data file is returned.
This is useful if you ever need to examine the raw columns of the
F<feffNNNN.dat> file.

  $command = $path_object -> read_data;

=item C<write_path>

This method returns the Ifeffit commands to import and define a Feff
path.  It takes a boolean argument which tells the method whether to
also generate the Ifeffit command for converting the defined path into
Ifeffit arrays for plotting or other manipulations.  That argument is
set true as part of the C<display> method, but false when the fit is
defined.

  $command = $path_object -> write_path($do_ff2chi);

=back

=head2 Information reporting methods

These methods are useful for generating log files and other reports.

=over 4

=item C<paragraph>

This method returns a multiline text string reporting on the
evaluation of the Path's math expressions.  This text looks very much
like the text that Ifeffit returns when you use Ifeffit's C<show
@group> command.

  print $path_object -> paragraph;

=item C<row_main>

This method returns a newline-terminated line of text containing the
values of several path parameters in a format suitable for making a
table of fitting results.  The path parameters included in this line
are C<n>, C<s02>, C<e0>, C<sigma2>, C<delr>, C<reff>, and the sum of
C<delr> and C<reff>.

The optional argument specifies the width of the first column, which
contains the path labels.

  print $path[0] -> row_main($width);

With this optional argument, you can scan the path labels before
creating the table and pre-size the first column, leading to a much
more attractive table.  The default width is 10 characters.  The
C<row_main_label>, C<row_second>, and C<row_second_label> methods also
take this same optional argument.

=item C<row_main_label>

This method returns a newline-terminated line of text suitable for the
header of the table made by repeated calls to the C<row_main> method.
Something like this will make a nice table

   print $path[0] -> row_main_label;
   print $path[0] -> row_main;
   print $path[1] -> row_main;
   print $path[2] -> row_main;

=item C<row_second>

This method returns a newline-terminated line of text containing the
values of several path parameters in a format suitable for making a
table of fitting results.  The path parameters included in this line
are C<ei>, C<dphase>, C<third>, C<fourth>.

=item C<row_second_label>

This method returns a newline-terminated line of text suitable for the
header of the table made by repeated calls to the C<row_second>
method.  Something like this will make a nice table

   print $path[0] -> row_second_label;
   print $path[0] -> row_second;
   print $path[1] -> row_second;
   print $path[2] -> row_second;

=item C<R>

This method returns the sum of the C<reff> attribute and the
evaluation of the C<delr> path parameter.  This:

  print $path_object -> R, $/;

is equivalent to (and fewer keystrokes than):

  ($reff, $delr) = $path_object->get(qw(reff delr_value));
  $R = $reff + $delr;
  print $R, $/;

=item C<longest_leg>

This returns the length in Angstroms of the longest leg of a path.

  print $path_object -> longest_leg, $/;

This is determined by searching the C<rleg> attribute of the
associated ScatteringPath object and returning the longest value.

=back

=head1 DIAGNOSTICS

=over 4

=item C<Demeter::Path: "group" is not a valid group name>

(F) You have used a group name that does not follow Ifeffit's rules for group
names.  The group name must start with a letter.  After that only letters,
numbers, &, ?, _, and : are acceptable characters.  The group name must be no
longer than 64 characters.

=item C<Demeter::Path: the sp attribute must be ScatteringPath object>

(F) You have set the C<sp> attribute to something other than a
ScatteringPath object.

=back

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

Automated indexing currently only works when doing a fit.  If you want
to plot paths before doing a fit, you will need to assign indeces by
hand.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
