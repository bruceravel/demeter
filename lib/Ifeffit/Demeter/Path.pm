package Ifeffit::Demeter::Path;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;
use Class::Std;
use Carp;
use Fatal qw(open close);
use File::Copy;
use File::Spec;
use Regexp::List;
use Regexp::Optimizer;
use Ifeffit;
use Ifeffit::Demeter::Data;
use aliased 'Ifeffit::Demeter::Tools';

{
  use base qw( Ifeffit::Demeter
               Ifeffit::Demeter::Path::Sanity
               Ifeffit::Demeter::Dispose
               Ifeffit::Demeter::Project
             );
  my %pp_trans = ('3rd'=>"third", '4th'=>"fourth", dphase=>"dphase",
		  dr=>"delr", e0=>"e0", ei=>"ei", s02=>"s02", ss2=>"sigma2");
  ## set default data parameter values
  my %path_defaults = (
		       group          => q{},
		       ## path parameters, s02 thru dphase take an anon array of [mathexp, value]
		       n	      => 0,	    # float
		       s02	      => "1",       # mathexp, float
		       s02_stored     => "1",
		       s02_value      => 1,
		       e0	      => q{},       # mathexp, float
		       e0_stored      => 0,
		       e0_value       => 0,
		       delr	      => q{},       # mathexp, float
		       delr_stored    => 0,
		       delr_value     => 0,
		       sigma2	      => q{},       # mathexp, float
		       sigma2_stored  => 0,
		       sigma2_value   => 0,
		       ei	      => q{},       # mathexp, float
		       ei_stored      => 0,
		       ei_value       => 0,
		       third	      => q{},       # mathexp, float
		       third_stored   => 0,
		       third_value    => 0,
		       fourth	      => q{},       # mathexp, float
		       fourth_stored  => 0,
		       fourth_value   => 0,
		       dphase	      => q{},       # mathexp, float
		       dphase_stored  => 0,
		       dphase_value   => 0,
		       label	      => q{},
		       id	      => q{},
		       k_array	      => q{},	    # mathexp
		       amp_array      => q{},	    # mathexp
		       phase_array    => q{},	    # mathexp
		       ## general parameters
		       data	      => q{},	    # Data object
		       parent	      => q{},	    # Feff object
		       sp             => q{},       # ScatteringPath object
		       sp_was         => q{},       # SP group name from a project
		       folder         => q{},
		       file	      => q{},
		       index          => 0,	    # integer   pseudo-Read Only
		       include	      => 1,	    # boolean
		       is_col	      => 0,	    # boolean   Read Only
		       is_ss	      => 1,	    # boolean   Read Only
		       plot_after_fit => 0,	    # boolean
		       ## feff interpretation parameters
		       degen	      => 0,	    # integer   Read Only
		       nleg	      => 2,	    # integer   Read Only
		       reff	      => 0,	    # float     Read Only
		       zcwif	      => 0,	    # float     Read Only
		       intrpline      => q{},       #           Read Only
		       geometry	      => q{},	    # multiline Read Only

		       ## data processing flags
		       update_path    => 1,
		       update_fft     => 1,
		       update_bft     => 1,
		      );
  my $opt  = Regexp::List->new;
  my $parameter_regexp = $opt->list2re(keys %path_defaults);
  my $pp_regex = $opt->list2re(qw(s02 e0 delr e0 sigma2 ei third fourth dphase));

  sub BUILD {
    my ($self, $ident, $arguments) = @_;
    $self -> SUPER::set(\%path_defaults);
    my $group = Tools -> random_string(4);
    $self -> set_group($group);

    ## path specific attributes
    $self -> set($arguments);

    my $val = $self->get_mode("datadefault");
    if ($val =~ m{\A\s*\z}) {
      $self->set_mode({datadefault=>Ifeffit::Demeter::Data->new({group=>'default___',
								 label=>'D_E_F_A_U_L_T',
								 fft_kmin=>3, fft_kmax=>15,
								 bft_rmin=>1, bft_rmax=>6,
								})
		      });
    };

    return;
  };

#  sub DEMOLISH {
#    my ($self) = @_;
#    return;
#  };


  ## return a list of valid path parameter names
  sub parameter_list {
    my ($self) = @_;
    return (sort keys %path_defaults);
  };
  sub _regexp {
    my ($self) = @_;
    return $parameter_regexp;
  };

  ## path specific methods
  sub set {
    my ($self, $r_hash) = @_;
    my $re = $self->regexp;

    foreach my $key (keys %$r_hash) {
      my $k = lc $key;
      carp("\"$key\" is not a valid Ifeffit::Demeter::Path parameter"), next
	if ($k !~ /$re/);

      ## special handling of some parameters
    SET: {
	#($k =~ /\b(?:data|feff)\b/) and do {	# set *_group when data|feff is set
	#  croak("The argument of \"$key\" must be a valid Ifeffit::Demeter object")
	#    if ($r_hash->{$k} and ref($r_hash->{$k}) !~ /Ifeffit/);
	#  $self->SUPER::set({$k=>$r_hash->{$k}});
	#  if ($r_hash->{$k}) {
	#    my $g = $r_hash->{$k} -> get_group;
	#    $self->SUPER::set({$k."_group"=>$g});
	#  };
	#  last SET;
	#};
	($k eq 'group') and do { # label defaults to group name unless otherwise specified
	  croak("Ifeffit::Demeter::Path: $r_hash->{$k} is not a valid group name")
	    if ($r_hash->{$k} !~ m{\A[a-z][a-z0-9:_\?&]{0,63}\z}io);
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};
	#($k =~ m{\b$pp_regex\b}) and do {
	#  $self->SUPER::set({$k=>[$r_hash->{$k}, 0]});
	#  last SET;
	#};
	($k =~ m{\A(?:f(?:ile|older))\z}) and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  $self->parse_nnnn;
	  last SET;
	};
	($k =~ m{\Asp\z}) and do {
	  croak("Ifeffit::Demeter::Path: the sp attribute must be ScatteringPath object")
	    if ($r_hash->{$k} and (ref($r_hash->{$k}) !~ m{ScatteringPath}));
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k =~ m{$re}) and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}}, "${k}_stored"=>$r_hash->{$k});
	};
	## handle update logic, if a step is flagged as needing update, all
	## later steps must also be flagged as needing update
	##      feffNNNN import -> fft -> bft
	($k =~ m{\Aupdate_(path|fft|bft)}) and do {
	  #$self->SUPER::set({ $key=>1 });  #### kludge alert!!
	  $self->SUPER::set({ $key=>$r_hash->{$k} });
	  last SET if ($1 eq 'bft');
	  my %table = (path=>{update_fft=>1, update_bft=>1},
	  	       fft =>{update_bft=>1},
	  	      );
	  if ($r_hash->{$k}) {
	    $self->SUPER::set($table{$1})
	  };
	  last SET;
	};
	do {
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	}
      };

    };
    return $self;
  };

  ### ---- this will be different working from a ScatteringPath object
  ###      snarfing from the object will have to be part of an update
  sub _update {
    my ($self, $which) = @_;
    $which = lc($which);
  WHICH: {
      ($which eq 'path') and do {
	$self->path(1) if $self->get('update_path');
	last WHICH;
      };
      ($which eq 'fft') and do {
	$self->path(1) if ($self->get('update_path'));
	last WHICH;
      };
      ($which eq 'bft') and do {
	$self->path(1) if ($self->get('update_path'));
	$self->fft;  # if ($self->get('update_fft'));  <--- kweight may have changed, just redo this
	last WHICH;
      };
      ($which eq 'all') and do {
	$self->path(1) if ($self->get('update_path'));
	$self->fft;  # if ($self->get('update_fft'));
	$self->bft;  # if ($self->get('update_bft'));
	last WHICH;
      };

    };
    return $self;
  };

  sub Index : NUMERIFY {
    my ($self) = @_;
    return $self->get('index');
  };
  sub data {
    my ($self) = @_;
    return $self->get('data') || $self->get_mode('datadefault') || q{};
  };
  sub plottable {
    my ($self) = @_;
    return 1;
  };

  sub rm {
    my ($self) = @_;
    unlink File::Spec->catfile($self->get(qw(folder file)));
    return $self;
  };

  sub display {
    my ($self, $space) = @_;
    my $pf = $self->get_mode("plot");
    my $command = q{};
    $command .= $self->_path_command(1);
    $command .= $self->_fft_command;
    $command .= $self->_bft_command;
    $command .= $self->_plot_command($space);
    $pf->increment; # increment the color for the next trace
    return $command;
  };

  sub read_data {
    my ($self) = @_;
    my $string = $self->SUPER::read_data('feff.dat');
    return $string;
  };


  ## how to handle extended path parameters?
  ## $index, $folder, $stash_dir all need to be known to the object
  sub path {
    my ($self, $do_ff2chi) = @_;
    $self->_update_from_ScatteringPath if $self->get("sp");
    $self->dispose($self->_path_command($do_ff2chi));
    $self->set({update_path=>0});
    return $self;
  };
  sub _update_from_ScatteringPath {
    my ($self) = @_;
    ## generate from a ScatteringPath object
    my $sp     = $self->get("sp");
    my $feff   = $sp  ->get("feff");
    my ($workspace, $fname) = ($feff->get("workspace"), $sp->get("random_string"));
#    if ($fname and (-e File::Spec->catfile($workspace, $fname))) { # feffNNNN.dat is already there
#      $self->set({folder => $workspace,
#		  file   => $fname});
#      return $self;
#    };

    $feff -> make_one_path($sp)
      -> make_feffinp("genfmt")
	-> run_feff;

    my $tempfile = "feff" . $feff->config->default('pathfinder', 'one_off_index') . ".dat";
    $fname ||= $sp->get("random_string");
    move(File::Spec->catfile($workspace, $tempfile),
	 File::Spec->catfile($workspace, $fname));
    $self->set({folder => $workspace,
		file   => $fname});
    my $label = $self -> get("label") || $sp->intrplist;
    $self->set({label=>$label});

    unlink File::Spec->catfile($feff->get("workspace"), "paths.dat");
    unlink File::Spec->catfile($feff->get("workspace"), "feff.run");
    unlink File::Spec->catfile($feff->get("workspace"), "nstar.dat");
    if (not $feff->get('save')) {
      unlink File::Spec->catfile($feff->get("workspace"), "feff.inp");
      unlink File::Spec->catfile($feff->get("workspace"), "files.dat");
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
      my $me = $self->get($pp);
      $me =~ s{\[?cv\]?}{$cv}g;
      $self->SUPER::set({$pp=>$me});
    };
  };



  ## paths are Fourier transformed just like their respective data,
  ## these methods just rewrite the data fftf() and fftr() command
  ## using the group name of the path
  sub fft {
    my ($self) = @_;
    $self->_update("fft");
    $self->dispose($self->_fft_command);
    $self->set({update_fft=>0});
  };
  sub _fft_command{
    my ($self) = @_;
    my $group = $self->get_group;
    my $dobject = $self->data;
    my $string = $dobject->_fft_command;
    $string =~ s{\b$dobject\b}{$group}g; # replace group names
    return $string;
  };

  sub bft {
    my ($self) = @_;
    $self->_update("bft");
    $self->dispose($self->_bft_command);
    $self->set({update_bft=>0});
  };
  sub _bft_command{
    my ($self) = @_;
    my $group = $self->get_group;
    my $dobject = $self->data;
    my $string = $dobject->_bft_command;
    $string =~ s{\b$dobject\b}{$group}g; # replace group names
    return $string;
  };

  sub plot {
    my ($self, $space) = @_;
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    my $which = q{};
    if (lc($space) eq 'k') {
      $self -> _update("fft");
      $which = "update_path";
    } elsif (lc($space) eq 'r') {
      $self -> _update("bft");
      $which = "update_fft";
    } elsif (lc($space) eq 'q') {
      $self -> _update("all");
      $which = "update_bft";
    };
    $self->dispose($self->_plot_command($space), "plotting");
    $pf->increment;
    $self->set({$which=>0});
  };
  sub _plot_command{
    my ($self, $space) = @_;
    my $group     = $self->get_group;
    my $label     = $self->label || $self->get("id");
    my $dobject   = $self->data;
    my $datalabel = $dobject->label;
    #my $string    = $dobject->_plot_command($space);
    my $string    = $dobject->_part_plot_command($self, $space);
    $string =~ s{\b$dobject\b}{$group}g; # replace group names
    ## (?<= ) is the positive zero-width look behind -- it only replaces
    ## the label when it follows q{key="}, that way it won't get confused by
    ## the same text in the title for a newplot
    $string =~ s{(?<=key=")$datalabel}{$label};         # ") silly emacs!
    return $string;
  };

  sub save {
    my ($self, $what, $filename) = @_;
    croak("No filename specified for save") unless $filename;
    ($what = 'chi') if (lc($what) eq 'k');
    croak("Valid save types are: chi r q") if ($what !~ m{\A(?:chi|r|q)\z});
  WHAT: {
      (lc($what) eq 'chi') and do {
	$self->_update("path");
	$self->dispose($self->_save_chi('k', $filename));
	last WHAT;
      };
      (lc($what) eq 'r') and do {
	$self->_update("bft");
	$self->dispose($self->_save_chi('r', $filename));
	last WHAT;
      };
      (lc($what) eq 'q') and do {
	$self->_update("all");
	$self->dispose($self->_save_chi('q', $filename));
	last WHAT;
      };
    };
  };


  sub parse_nnnn {
    my ($self) = @_;
    my $oneoff = "feff" . $self->config->default('pathfinder', 'one_off_index');
    my ($folder, $file) = $self->get(qw(folder file));
    my $fname = File::Spec -> catfile($folder, $file);

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
    $self->set({geometry=>$geometry});

    $fname = File::Spec -> catfile($folder, 'files.dat');
    open (my $FILESDAT, $fname);
    while (<$FILESDAT>) {
      next if ($_ !~ /(?:$file|$oneoff)/); # $oneoff is matched when working from a ScatteringPath object
      my @list = split(" ", $_);
      my $n_set = $self->get("n");
      $self->SUPER::set({zcwif =>     $list[2],
			 degen => int($list[3]),
			 n     => $n_set || int($list[3]),
			 nleg  =>     $list[4],
			 reff  =>     $list[5]
			});
    };
    close $FILESDAT;

    return 0;
  };


  sub fetch {
    my ($self) = @_;

    my $save = Ifeffit::get_scalar("\&screen_echo");
    ifeffit("\&screen_echo = 0\n");

    ifeffit(sprintf("show \@path %d\n", $self));

    my $lines = Ifeffit::get_scalar('&echo_lines');
    ifeffit("\&screen_echo = $save\n"), return if not $lines;
    my $found = 0;
    foreach my $l (1 .. $lines) {
      my $response = Ifeffit::get_echo()."\n";
      ($found = 1), next if ($response =~ m{\A PATH}x);
      next if not $found;
      chomp $response;
      my @line = split(/\s+=\s*/, $response);
    SWITCH: {

	($line[0] eq 'id') and do {
	  $self -> set({id=>$line[1]});
	  last SWITCH;
	};

	($line[0] =~ m{(?:3rd|4th|d(?:phase|r)|e[0i]|s[0s]2)}) and do {
	  $self -> evaluate($pp_trans{$line[0]}, $line[1]);
	  last SWITCH;
	}

      };
    };

    ifeffit("\&screen_echo = $save\n");
    return 0;
  };

  ## path parameter tools
  sub evaluate {
    my ($self, $key, $value) = @_;
    my $array_ref = $self->get($key);
    $self->SUPER::set({$key."_value"=>$value});
    return 0;
  };
  sub value {
    my ($self, $pathparam) = @_;
    my $re = $self->regexp('pathparams');
    return 0 if ($pathparam !~ m{$re});
    return $self->get($pathparam."_value");
  };

  sub parent {
    my ($self) = @_;
    return $self->get("parent");
  };
  sub identity {
    my ($self) = @_;
    return sprintf("%s", $self->label);
    ##return sprintf("%s : %s", $self->parent->label, $self->label);
  };


  ## log file tools

  sub R {
    my ($self) = @_;
    my ($reff, $delr) = ($self->get('reff'), $self->value('delr'));
    return $reff + $delr;
  };
  sub paragraph {
    my ($self) = @_;
    my $string = sprintf("    feff   = %s\n",     File::Spec->catfile($self->get(qw(folder file))));
    $string   .= sprintf("    id     = %s\n",     $self->get(qw(id)));
    $string   .= sprintf("    label  = %s\n",     $self->get(qw(label)));
    $string   .= sprintf("    r      = %12.6f\n", $self->R);
    $string   .= sprintf("    degen  = %12.6f\n", $self->get('n'));
    foreach my $pp (qw(s02 e0 delr sigma2 third fourth ei)) {
      $string .= sprintf("    %-6s = %12.6f\n",   $pp, $self->value($pp));
    };
    return $string;
  };
  sub row_main_label {
    my ($self, $width) = @_;
    $width ||= 15;
    my $pattern = '  %-' . $width . join(" ", qw(s %8s %7s %9s %7s %7s %8s %8s)) . "\n";
    my $string = sprintf($pattern, qw(label N S02 sigma^2 e0 delr Reff R));
    $string .= "=" x (length($string)+2) . "\n";
  };
  sub row_main {
    my ($self, $width) = @_;
    $width ||= 15;
    my $pattern = '  %-' . $width . join(" ", qw(s %8.3f %7.3f %9.5f %7.3f %8.5f %8.5f %8.5f)) . "\n";
    my $string = sprintf($pattern,
			 $self->get(qw(label n)),
			 (map {$self->value($_)} (qw(s02 sigma2 e0 delr))),
			 $self->get('reff'),
			 $self->R,
			);
    return $string;
  }

  sub row_second_label {
    my ($self, $width) = @_;
    $width ||= 15;
    my $pattern = '  %-' . $width . join(" ", qw(s %9s %9s %9s %9s)) . "\n";
    my $string = sprintf($pattern, qw(label ei third fourth dphase));
    $string .= "=" x (length($string)+1) . "\n";
  };
  sub row_second {
    my ($self, $width) = @_;
    $width ||= 15;
    my $pattern = '  %-' . $width . join(" ", qw(s %9.5f %9.5f %9.5f %9.5f)) . "\n";
    my $string = sprintf($pattern,
			 $self->get('label'),
			 (map {$self->value($_)} (qw(ei third fourth dphase))),
			);
    return $string;
  };

};
1;


=head1 NAME

Ifeffit::Demeter - Single and multiple scattering paths for EXAFS fitting


=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.


=head1 SYNOPSIS

  $path_object -> new();
  $path_object -> set({data     => $dobject,
		       folder   => 'example/cu/',
		       file     => "feff0001.dat",
		       label    => "path 1",
		       s02      => 'amp',
		       e0       => 'enot',
		       delr     => 'alpha*reff',
		       sigma2   => 'debye(temp, theta) + sigmm',
		      });

or

  $path_object -> new();
  $path_object -> set({data     => $dobject,
                       sp       => $scattering_path_object
		       label    => "path 1",
		       s02      => 'amp',
		       e0       => 'enot',
		       delr     => 'alpha*reff',
		       sigma2   => 'debye(temp, theta) + sigmm',
		      });

=head1 DESCRIPTION

This subclass of the Ifeffit::Demeter class is for holding information
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

The attributes marked "I<{read-only}>" are typically not set
interactively.  Instead, they will be set as a side effect of other
method calls.  For example, the nleg attribute will the set after the
C<file> attribute is set.  C<nleg> is a piece of information that is
determined from the C<`feffNNNN.dat'> file.  They are not strictly
read-only.  You can set them if you want, but no care is taken to
preserve your modification from subsequent method calls.

For this Path object to be included in a fit, it is necessary that it
be an attribute of a Fit object.  See L<Ifeffit::Demeter::Fit> for
details.

=head2 General attributes

=over 4

=item C<group> (string)

This is the Ifeffit group name used for this path.  That is, its
arrays will be called I<group>.k, I<group>.chi, and so on.  It is best
if this is a reasonably short word and it B<must> follow the
conventions of a valid group name in Ifeffit.  By default, this is a
random, four-letter string.

=item C<label> (string)

This is a text string used to describe this object in a user
interface.  While the C<group> attribute should be short, this can be
more verbose.  But it should be a single line, unlike the C<title>
attibute.

=item C<parent> (Feff object)

This is the reference to the Feff object that this Path is a part of.

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

=item C<index> (integer) I<{read-only}>

This is the path index as required in the definition of an Ifeffit
Path.  It is rarely necessary to set this by hand.  Indexing is
typically handled by Demeter.

=item C<include> (boolean)

When this is true, this Path will be included in the next fit.

=item C<plot>_after_fit (boolean)

This is a flag for use by a user interface to indicate that after a
fit is finished, this Path should be plotted.

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

=item C<s02_value> (number) I<{read-only}>

This is the amplitude term for the path.

=item C<e0> (string)

=item C<e0_value> (number) I<{read-only}>

This is the energy shift term for the path.

=item C<delr> (string)

=item C<delr_value> (number) I<{read-only}>

This is the path length correction term for the path.

=item C<sigma2> (string)

=item C<sigma2_value> (number) I<{read-only}>

This is the mean square displacement shift term for the path.

=item C<ei> (string)

=item C<ei_value> (number) I<{read-only}>

This is the imaginary energy correction term for the path.

=item C<third> (string)

=item C<third_value> (number) I<{read-only}>

This is the third cumulant term for the path.

=item C<fourth> (string)

=item C<fourth_value> (number) I<{read-only}>

This is the fourth cumulant term for the path.

=item C<dphase> (string)

=item C<dphase_value> (number) I<{read-only}>

This is the constant phase shift term for the path.

=item C<id> (string) I<{read-only}>

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

=item C<degen> (number) I<{read-only}>

This is the degeneracy in the F<feffNNNN.dat> file associated with
this Path object.

=item C<nleg> (integer) I<{read-only}>

This is the number of legs in the F<feffNNNN.dat> file associated
with this Path object.

=item C<reff> (number) I<{read-only}>

This is the effective path length in the F<feffNNNN.dat> file
associated with this Path object.

=item C<zcwif> (number) I<{read-only}>

This is the amplitude (i.e. "Zabinsky curved wave importance factor")
for the F<feffNNNN.dat> file associated with this Path object.

Note that this is always 0 for paths that come from ScatteringPath
objects, since the ScatteringPath objct does not, at this time, have a
way of computing the ZCWIF.

=item C<intrpline> (string) I<{read-only}>

This is a line of text relating to this path from the interpretation
the Feff calculation.

=item C<geometry> (multiline string) I<{read-only}>

This is a textual description of the scattering geometry associated
with this path.

=item C<is_col> (boolean) I<{read-only}>

This is true when the path associated with this object is a colinear
or nearly colinear multiple scattering path.

=item C<is_ss> (boolean) I<{read-only}>

This is true when the path associated with this object is a single
scattering path.

=back

=head1 METHODS

The Path object inherits creation (C<new> and C<clone>) and accessor
methods (C<set>, C<get>) from the parent class described in the
L<Ifeffit::Demeter> documentation.

Additionally the Path object provides these methods:

=head2 Convenience methods

=over 4

=item C<Index>

This method returns the Ifeffit path index for this object.  It is
capitalized to avoid confusion with the built-in index function.

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

=back

=head1 COERCIONS

When the reference to the Path object is used in string context, it
returns the group name.  So

  $path_object -> set({group    => 'path1',
                       data     => $data_object,
		       folder   => 'example/cu/',
		       file     => "feff0001.dat",
		       label    => "path 1",
		       index    => 1,
		      });
  print "This is $path_object.\n";

will print

  This is path1.

Rather than

  This is Ifeffit::Demeter::Path.

When the reference to the Path object is used in numerical context, it
returns the path index.  So

  sprint("This is path number %d.\n", $path_object);

will print

  This is path number 1.

=head1 DIAGNOSTICS

=over 4

=item C<Ifeffit::Demeter::Path: "group" is not a valid group name>

(F) You have used a group name that does not follow Ifeffit's rules for group
names.  The group name must start with a letter.  After that only letters,
numbers, &, ?, _, and : are acceptable characters.  The group name must be no
longer than 64 characters.

=item C<Ifeffit::Demeter::Path: the sp attribute must be ScatteringPath object>

(F) You have set the C<sp> attribute to something other than a
ScatteringPath object.

=back

=head1 SERIALIZATION AND DESERIALIZATION

See the discussion of serialization and deserialization in
C<Ifeffit::Demeter::Fit>.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Automated indexing currently only works when doing a fit.  If you want
to plot paths before doing a fit, you will need to assign indeces by
hand.

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
