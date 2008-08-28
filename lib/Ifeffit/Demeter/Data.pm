package Ifeffit::Demeter::Data;

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

use base qw(
	     Ifeffit::Demeter
	     Ifeffit::Demeter::Data::Mu
	     Ifeffit::Demeter::Data::E0
	     Ifeffit::Demeter::Data::Process
	     Ifeffit::Demeter::Data::Defaults
	     Ifeffit::Demeter::Data::Athena
	     Ifeffit::Demeter::Dispose
	     Ifeffit::Demeter::Project
	   );
use strict;
use warnings;
#use diagnostics;
use aliased 'Ifeffit::Demeter::Tools';
use Carp;
use Class::Std;
use Fatal qw(open close);
use Ifeffit;
use List::Util qw(min max);
use List::MoreUtils qw(pairwise);
use Regexp::Common;
use Regexp::List;
use Regexp::Optimizer;
use Readonly;
Readonly my $NUMBER   => $RE{num}{real};
Readonly my $PI       => 4*atan2(1,1);
Readonly my $NULLFILE => '@&^^null^&@';

{
  my $opt  = Regexp::List->new;
  ## set default data parameter values
  my $config = Ifeffit::Demeter->get_mode("params");
  my %data_defaults = (
		       group		  => q{my},
		       tag		  => q{my},
		       cv                 => 0,    # characteristic value
		       file		  => $NULLFILE,
		       from_athena        => 0,
		       label		  => q{},
		       fitsum		  => q{},  # fit/sum, indicated what was recently done
		       fitting		  => 0,	   # boolean
		       fit_data		  => 0,

		       columns            => q{},
		       energy             => q{},
		       numerator          => q{},
		       denominator        => q{},
		       ln                 => 0,
		       energy_string      => q{},
		       xmu_string         => q{},
		       i0_string          => q{},

		       is_col             => 0,
		       is_xmu		  => 0,	   # boolean
		       is_xmudat	  => 0,	   # boolean
		       is_chi		  => 0,	   # boolean
		       is_nor		  => 0,	   # boolean
		       is_xanes		  => 0,	   # boolean
		       generated          => 0,    # boolean
		       is_merge           => 0,    # boolean

		       update_data	  => 1,
		       update_columns	  => 1,
		       update_norm	  => 1,
		       update_bkg	  => 1,
		       update_fft	  => 1,
		       update_bft	  => 1,

		       ## processing level
		       bkg_e0		  => 0,	       # number
		       bkg_e0_fraction	  => $config->default("bkg", "e0_fraction") || 0.5,
		       bkg_eshift	  => 0,	       # number
		       bkg_kw		  => $config->default("bkg", "kw")   ||  2,
		       bkg_rbkg		  => $config->default("bkg", "rbkg") ||  1,
		       bkg_dk		  => $config->default("bkg", "dk")   ||  0,
		       bkg_pre1		  => $config->default("bkg", "pre1") || -150,
		       bkg_pre2		  => $config->default("bkg", "pre2") || -30,
		       bkg_nor1		  => $config->default("bkg", "nor1") ||  150,
		       bkg_nor2		  => $config->default("bkg", "nor2") ||  400,
		       bkg_spl1		  => $config->default("bkg", "spl1") ||  0,
		       bkg_spl2		  => $config->default("bkg", "spl2") ||  0,
		       bkg_spl1e	  => 0,	       # number
		       bkg_spl2e	  => 0,	       # number
		       bkg_kwindow	  => $config->default("bkg", "kwindow") || 'hanning',
		       bkg_slope	  => 0,		       # number
		       bkg_int		  => 0,		       # number
		       bkg_step		  => 0,		       # number
		       bkg_fitted_step	  => 0,		       # number
		       bkg_fixstep	  => 0,		       # boolean
		       bkg_nc0		  => 0,		       # number
		       bkg_nc1		  => 0,		       # number
		       bkg_nc2		  => 0,		       # number
		       bkg_flatten	  => $config->default("bkg", "flatten") || 1,
		       bkg_fnorm	  => $config->default("bkg", "fnorm")   || 0,
		       bkg_nnorm	  => $config->default("bkg", "nnorm")   || 3,
		       bkg_stan		  => 'None',
		       bkg_stan_lab	  => '0: None',
		       bkg_clamp1	  => $config->default("bkg", "clamp1")  || 0,
		       bkg_clamp2	  => $config->default("bkg", "clamp2")  || 24,
		       bkg_nclamp	  => $config->default("bkg", "nclamp")  || 5,
		       bkg_tie_e0	  => 0,		       # boolean
		       bkg_former_e0	  => 0,		       # number
		       bkg_cl		  => 0,		       # boolean
		       bkg_z		  => 'H',	       # element

		       fft_edge		  => 'K',	       # K L1 L2 L3
		       fft_kmin		  => $config->default("fft", "kmin")     ||  3,
		       fft_kmax		  => $config->default("fft", "kmax")     || -2,
		       fft_dk		  => $config->default("fft", "dk")       ||  2,
		       fft_kwindow	  => $config->default("fft", "kwindow")  || 'hanning',
		       fft_pc		  => $config->default("fft", "pc")       ||  0,
		       rmax_out		  => $config->default("fft", "rmax_out") ||  10,

		       bft_rwindow	  => $config->default("bft", "rwindow")  || 'hanning',
		       bft_rmin		  => $config->default("bft", "rmin")     ||  1,
		       bft_rmax		  => $config->default("bft", "rmax")     ||  3,
		       bft_dr		  => $config->default("bft", "dr")       ||  0.2,

		       ## fitting level
		       fit_k1		  => $config->default("fit", "k1")         ||  1,
		       fit_k2		  => $config->default("fit", "k2")         ||  0,
		       fit_k3		  => $config->default("fit", "k3")         ||  1,
		       fit_karb		  => $config->default("fit", "karb")       ||  0,
		       fit_karb_value	  => $config->default("fit", "karb_value") ||  0,
		       fit_space	  => $config->default("fit", "space")      || 'r',
		       fit_epsilon	  => 0,	   # float
		       fit_cormin	  => $config->default("fit", "cormin")     ||  0.4,
		       fit_pcpath	  => 'None',
		       fit_include	  => 1,	   # boolean
		       fit_plot_after_fit => 0,	   # boolean
		       fit_do_bkg	  => 0,	   # boolean
		       fit_titles	  => q{},  # multiline

		       ## plotting level
		       'y_offset'	  => 0,
		       plot_multiplier	  => 1,

		      );
  my $number_attr   = $opt->list2re(qw(fit_karb_value cv
                                       bkg_e0 bkg_eshift bkg_kw bkg_rbkg bkg_dk
                                       bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2
                                       bkg_spl1 bkg_spl2 bkg_spl1e bkg_spl2e
                                       bkg_slope bkg_int bkg_nc0 bkg_nc1 bkg_nc2
                                       bkg_step bkg_fitted_step bkg_former_e0
                                       fft_kmin fft_max fft_dk
                                       bft_rmin bft_rmax bft_dr
                                       fit_epsilon fit_cormin));
  ##
  my $boolean_attr  = $opt->list2re(qw(bkg_fixstep bkg_flatten bkg_fnorm
                                       bkg_tie_e0 bkg_cl fit_k1 fit_k2 fit_k3
                                       fit_karb fit_include fit_plot_after_fit
                                       fit_do_bkg is_xmu is_chi is_nor is_xmudat is_nor
				       fft_pc fitting is_merge generated is_col));
  my $posint_attr   = $opt->list2re(qw(bkg_clamp1 bkg_clamp2 bkg_nclamp));
  my $window_attr   = $opt->list2re(qw(bkg_kwindow fft_kwindow bft_rwindow));
  my $window_regexp = $opt->list2re(qw(kaiser-bessel hanning parzen welch sine gaussian));
  my $valid_group   = '\A[a-z][a-z0-9:_\?&]{0-63}\z';

  sub BUILD {
    my ($self, $ident, $arguments) = @_;
    $self -> set(\%data_defaults);
    $self -> set({bkg_spl1=>$data_defaults{bkg_spl1}, bkg_spl2=>$data_defaults{bkg_spl2}});
    $self->SUPER::set({is_xmu=>0, is_chi=>0});
    my $group = $arguments->{group} || Tools -> random_string(4);
    $self->set_group($group);

    ## data specific attributes
    $self -> set($arguments);
  };
#   sub DEMOLISH {
#     my ($self, $ident) = @_;
#     my $group = $self->get_group;
#     if ($group) {
#       my $string = Ifeffit::Demeter->template("process", "erase_group", {dead=>$group});
#       Ifeffit::Demeter->dispose($string);
#     };
#     return;
#   };

  sub data {
    my ($self) = @_;
    return $self;
  };
  sub plottable {
    my ($self) = @_;
    return 1;
  };

  sub cv {
    my ($self) = @_;
    return $self->get("cv");
  };

  sub standard {
    my ($self) = @_;
    Ifeffit::Demeter->set_mode({standard=>$self});
    return $self;
  };
  sub unset_standard {
    my ($self) = @_;
    Ifeffit::Demeter->set_mode({standard=>q{}});
    return $self;
  };

  ## return a list of valid data parameter names
  sub parameter_list {
    my ($self) = @_;
    return (sort keys %data_defaults);
  };
  my $parameter_regexp = $opt->list2re(keys %data_defaults);
  sub _regexp {
    my ($self) = @_;
    return $parameter_regexp;
  };

  sub set_group {
    my ($self, $group) = @_;
    $self->SUPER::set_group($group);
    $self->set({tag => $group}) if ((not $self->get("tag")) or ($self->get("tag") eq 'my'));
    return $self;
  };

  sub set {
    my ($self, $r_hash) = @_;
    my $re = $self->regexp;

    my %update_table = (data	=> {update_columns=>1, update_norm=>1, update_bkg=>1, update_fft=>1, update_bft=>1},
			columns	=> {update_norm=>1, update_bkg=>1, update_fft=>1, update_bft=>1},
			norm	=> {update_bkg=>1,  update_fft=>1, update_bft=>1},
			bkg	=> {update_fft=>1,  update_bft=>1},
			fft	=> {update_bft=>1},
			bft	=> {},
		       );
    my %range_check = (k=>0, r=>0);
    foreach my $key (keys %$r_hash) {
      my $k = lc $key;

      carp("\"$key\" is not a valid Ifeffit::Demeter::Data parameter"), next
	if ($k !~ /$re/);


      #if (($k =~ m{\Abkg_clamp[12]}) and ($r_hash->{$k} !~ m{\A\+?[0-9]+\z})) {
	#print ">>> $k  ", $r_hash->{$k}, "  ", $self->clamp($r_hash->{$k}), $/;
	#$self->SUPER::set({$k=>$self->clamp($r_hash->{$k})});
      #};

      ## basic sanity checking of parameter values
      if ($k =~ m{\A$number_attr\z}) { # numbers must be numbers
	croak("Ifeffit::Demeter::Data: $k must be a number ($r_hash->{$k})")
	  if ($r_hash->{$k} !~ m{\A$NUMBER\z});
	++$range_check{$1} if ($k =~ /\A(?:bft|fft|fit)_([kr])m(?:ax|in)\z/);
      };
      if ($k =~ m{\A$posint_attr\z}) { # pos integers must be pos integers
	croak("Ifeffit::Demeter::Data: $k must be a positive integer")
	  if ($r_hash->{$k} !~ m{\A\+?[0-9]+\z});
      };
      if ($k =~ m{\A$window_attr\z}) { # windows must be windows
	croak("Ifeffit::Demeter::Data: $k must be a window function")
	  if (lc($r_hash->{$k}) !~ m{\A$window_regexp\z});
      };

      ## specialized sanity checking and processing
    SET: {
	($k =~ /\Ais_(?:chi|xmu)\z/) and do { # is_chi and is_xmu are exclusive
	  my $other = ($k eq 'is_chi') ? 'is_xmu' : 'is_chi';
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  $self->SUPER::set({$other=>abs($r_hash->{$k}-1)});
	  last SET;
	};
	($k eq 'is_col') and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  if ($r_hash->{$k}) {
	    $self->SUPER::set({is_xmu=>1, is_chi=>0});
	  };
	  last SET;
	};
	($k eq 'generated') and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  $self->SUPER::set({file           => q{},
			     update_data    => 0,
			     update_columns => 0,
			     is_col         => 0,
			     columns        => q{},
			     energy         => q{},
			     numerator      => q{},
			     denominator    => q{},
			     ln             => 0,
			     energy_string  => q{},
			     xmu_string     => q{},});
	  last SET;
	};
	($k eq 'group') and do { # label defaults to group name unless otherwise specified
	  croak("Ifeffit::Demeter::Data: $r_hash->{$k} is not a valid group name")
	    if ($r_hash->{$k} !~ m{\A[a-z][a-z0-9:_\?&]{0,63}\z}io);
	  my $label = $self->get('label') || q{};
	  $self->SUPER::set({label=>$r_hash->{$k}}) if ($label =~ m{\A\s*\z});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k =~ m{(?:energy|denominator|ln|numerator)}) and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  if ($r_hash->{$k}) {
	    $self->set({update_columns=>1, is_col=>1});
	  };
	  last SET;
	};
	($k =~ m{\Afile\z}) and do {
	  croak("Ifeffit::Demeter::Data: $r_hash->{$k} is not a readable data file")
	    if (($r_hash->{$k} ne $NULLFILE) and (not -e $r_hash->{$k}));
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  my $label = $self->get('label') || q{};
	  $self->SUPER::set({label=>$r_hash->{$k}}) if ($label =~ m{\A\s*\z});
	  $self->set({update_data=>1});
	  $self->determine_data_type;
	  last SET;
	};
	($k =~ m{\Afit_space\z}) and do {
	  croak("Ifeffit::Demeter::Data: $k must be one of (k R q)")
	    if (lc($r_hash->{$k}) !~ m{\A[krq]\z}i);
	  $self->SUPER::set({$k=>lc($r_hash->{$k})});
	  last SET;
	};
	($k =~ m{\Afft_edge\z}) and do {
	  croak("Ifeffit::Demeter::Data: $k must be one of (K L1 L2 L3)")
	    if (lc($r_hash->{$k}) !~ /\A(?:k|l[123])\z/i);
	  $self->SUPER::set({$k=>lc($r_hash->{$k})});
	  last SET;
	};
	($k =~ m{\Afitsum\z}) and do {
	  croak("Ifeffit::Demeter::Data: $k must be one of (fit sum)")
	    if (lc($r_hash->{$k}) !~ m{\A(?:fit|sum|\s*)\z}i);
	  $self->SUPER::set({$k=>lc($r_hash->{$k})});
	  last SET;
	};

	($k =~ /\Abkg_spl[12]\z/) and do {
	  $self->SUPER::set({ $k=>$r_hash->{$k} });
	  my $evalue = $self->k2e($r_hash->{$k}, "relative");
	  my $key = $k . "e";
	  $self->SUPER::set({ $key=>$evalue, %{$update_table{norm}} });
	  last SET;
	};
	($k =~ /\Abkg_spl[12]e\z/) and do {
	  $self->SUPER::set({ $k=>$r_hash->{$k} });
	  my $kvalue = $self->e2k($r_hash->{$k}, "relative");
	  my $key = substr($k, 0, -1);
	  $self->SUPER::set({ $key=>$kvalue, %{$update_table{norm}} });
	  last SET;
	};
	($k =~ m{\Abkg_}) and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}, %{$update_table{norm}} });
	  last SET;
	};
	($k =~ m{\Afft_}) and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}, %{ $update_table{bkg}} });
	  last SET;
	};
	($k =~ m{\Abft_}) and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}, %{$update_table{fft}} });
	  last SET;
	};

	## handle update logic, if a step is flagged as needing update, all
	## later steps must also be flagged as needing update
	##      data -> normalization -> background -> fft -> bft
	($k =~ m{\Aupdate_(columns|data|norm|bkg|fft)}) and do {
	  $self->SUPER::set({ $key=>$r_hash->{$k} });
	  if ($r_hash->{$k}) {
	    $self->SUPER::set($update_table{$1});
	  };
	  if (($k eq "update_data") and $self->get("is_col")) {
	    $self->SUPER::set({update_columns=>1});
	  };
	  last SET;
	};

	do {			# no special handling required
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};
      };

    };

    ## make sure fft_kmin/fft_kmax and bft_rmin/bft_rmax are in the right order if any
    ## of them have been set in this call to this method
    if ($range_check{k}) {
      my ($min, $max)    = sort {$a <=> $b} ( $self->get(qw(fft_kmin fft_kmax)) );
      $self -> SUPER::set({fft_kmin=>$min, fft_kmax=>$max});
    };
    if ($range_check{r}) {
      my ($min, $max)    = sort {$a <=> $b} ( $self->get(qw(bft_rmin bft_rmax)) );
      $self -> SUPER::set({bft_rmin=>$min, bft_rmax=>$max});
    };

    return $self;
  };

  sub set_windows {
    my ($self, $window) = @_;
    $window = lc($window);
    carp("window type must be one of Kaiser-Bessel, Hanning, Parzen, Welch, Sine, or Gaussian"),
      return if ($window !~ m{\A$window_regexp\z});
    $self->set({
		bkg_kwindow => $window,
		fft_kwindow => $window,
		bft_rwindow => $window,
	       });
    return $self;
  };

  sub _update {
    my ($self, $which) = @_;
    $which = lc($which);
    ##print join("|",$self->get(qw(update_data update_columns update_norm update_bkg))), $/;
    my $is_xmu = $self->get("is_xmu");
  WHICH: {
      ($which eq 'normalize') and do {
	$self->read_data if ($self->get('update_data'));
	$self->put_data  if ($self->get('update_columns'));
	last WHICH;
      };
      ($which eq 'background') and do {
	$self->read_data if ($self->get('update_data'));
	$self->put_data  if ($self->get('update_columns'));
	$self->normalize if ($self->get('update_norm') and $is_xmu);
	last WHICH;
      };
      ($which eq 'fft') and do {
	$self->read_data if ($self->get('update_data'));
	$self->put_data  if ($self->get('update_columns'));
	$self->normalize if ($self->get('update_norm') and $is_xmu);
	$self->autobk    if ($self->get('update_bkg')  and $is_xmu);
	last WHICH;
      };
      ($which eq 'bft') and do {
	$self->read_data if ($self->get('update_data'));
	$self->put_data  if ($self->get('update_columns'));
	$self->normalize if ($self->get('update_norm') and $is_xmu);
	$self->autobk    if ($self->get('update_bkg')  and $is_xmu);
	$self->fft       if ($self->get('update_fft'));
	last WHICH;
      };
      ($which eq 'all') and do {
	$self->read_data if ($self->get('update_data'));
	$self->put_data  if ($self->get('update_columns'));
	$self->normalize if ($self->get('update_norm') and $is_xmu);
	$self->autobk    if ($self->get('update_bkg')  and $is_xmu);
	$self->fft       if ($self->get('update_fft'));
	$self->bft       if ($self->get('update_bft'));
	last WHICH;
      };

    };
    return $self;
  };


  ## this is a shortcut for doing FTs, plotting, and managing the plot object
  sub display {
    my ($self, $space) = @_;
    my $how = Ifeffit::Demeter->get_mode('process');
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    my $command = q{};
    my %parts = (data => $pf->get('plot_data'),
		 fit  => $pf->get('plot_fit'),
		 res  => $pf->get('plot_res'),
		 bkg  => $pf->get('plot_bkg'),
		 win  => $pf->get('plot_win'),
		);
    #foreach my $p (@$r_parts) {
    #  ++$parts{$p};
    #};
    foreach my $p (qw(data fit res bkg win)) {
      next if not $parts{$p};
      next if (($p eq 'bkg') and (not $self->get('fit_do_bkg')));
      if ($p eq 'data') {
	$command .= $self->_read_data_command;
	$command .= $self->_fft_command($how,$pf);
	$command .= $self->_bft_command($how,$pf);
	$command .= $self->_plot_command($space, $pf);
      } elsif ($p eq 'win') {
	$command .= $self->_plot_window_command($space, $pf);
      } elsif ($p =~ m{\A(?:bkg|fit|res|sum)\z}) {
	$command .= $self->_part_fft_command($p, $how, $pf);
	$command .= $self->_part_bft_command($p, $how);
	$command .= $self->_part_plot_command($p, $space, $pf);
      #} else {
      #	carp("Ifeffit::Demeter::Data: invalid data part $part (data fit bkg res win)");
      #	next;
      };
      $pf->increment; # increment the color for the next trace
    };
    $self->dispose($command);
    return $command;
  };

  sub determine_data_type {
    my ($self) = @_;
    my $file = $self->get("file");
    return 0 if ($file eq $NULLFILE);
    ## figure out how to interpret these data -- need some error checking
    $self->set({is_col=>1}) if ($self->get("numerator") or $self->get("numerator"));
    if ((not $self->get("is_col")) and (not $self->get("is_xmu")) and (not $self->get("is_chi")) ) {
      Ifeffit::ifeffit("read_data(file=\"$file\", group=b___lah)\n");
      my $f = (split(" ", Ifeffit::get_string('$column_label')))[0];
      my @x = Ifeffit::get_array("b___lah.$f");
      Ifeffit::ifeffit("erase \@group b___lah\n");
      if ($x[0] > 100) {	# seems to be energy data
	$self->set({is_xmu=>1});
      } elsif ($x[-1] > 35) {   # seems to be relative energy data
	$self->set({is_xmu=>1});
      } else {			# it's chi(k) data
	$self->set({is_chi=>1});
      };
    };
    return $self;
  };

  sub read_data {
    my ($self) = @_;
    my $type = ($self->get('is_col')) ? q{}
             : ($self->get('is_chi')) ? 'chi'
	     :                          'xmu';
    my $string = $self->SUPER::_read_data_command($type);
    $self->dispose($string);
    $self->set({update_data=>0});
    if ($self->get('is_col')) {
      $self->set({columns=>Ifeffit::get_string("column_label")});
    };
    $self->sort_data;
    return $self;
  };

  sub sort_data {
    my ($self) = @_;
    my @x = ();
    if ($self->get('is_col')) {

      ## This block is a complicated bit.  The idea is to store all
      ## the data in a list of lists.  In this way, I can sort all the
      ## data in one swoop by sorting off the energy part of the list
      ## of lists.  After sorting, I check the data for repeated
      ## points and remove them.  Finally, I reload the data into
      ## ifeffit and carry on like normal data

      ## This gets a list of column labels
      my @cols = split(" ", $self->get('columns'));
      my @lol;
      ## energy value is zeroth in each anon list
      unshift @cols, q{};
      my $ecol = $self->get("energy");
      $ecol =~ s{^\$}{};
      my @array = $self->get_array($cols[$ecol]);
      foreach (0 .. $#array) {push @{$lol[$_]}, $array[$_]};
      foreach my $c (@cols) {
	next unless $c;
	## load other cols (including energy col) into anon. lists
	my @this_array = $self->get_array($c);
	foreach (0 .. $#this_array) {push @{$lol[$_]}, $this_array[$_]};
      };
      ## sort the anon. lists by energy (i.e. zeroth element)
      @lol = sort {$a->[0] <=> $b->[0]} @lol;

      ## now fish thru lol looking for repeated energy points
      my $ii = 0;
      while ($ii < $#lol) {
	($lol[$ii+1]->[0] > $lol[$ii]->[0]) ? ++$ii : splice(@lol, $ii+1, 1);
      };

      ## now feed columns back to ifeffit
      foreach my $c (1 .. $#cols) {
	my @array;
	foreach (@lol) {push @array, $_->[$c]};
	$self->dispose("## replacing $self.$cols[$c] with sorted version");
	$self->dispose("erase $self.$cols[$c]");
	Ifeffit::put_array("$self.$cols[$c]", \@array);
      };
    };
    return $self;
  };

  sub save {
    my ($self, $what, $filename) = @_;
    croak("No filename specified for save") unless $filename;
    ($what = 'chi') if (lc($what) eq 'k');
    croak("Valid save types are: xmu norm chi r q fit bkgsub")
      if ($what !~ m{\A(?:xmu|norm|chi|r|q|fit|bkgsub)\z});
  WHAT: {
      (lc($what) eq 'fit') and do {
	$self->save_fit($filename);
	last WHAT;
      };
      (lc($what) eq 'xmu') and do {
	$self->_update("background");
	carp("cannot save mu(E) file from chi(k) data"), return if ($self->get("is_chi"));
	$self->save_xmu($filename);
	last WHAT;
      };
      (lc($what) eq 'norm') and do {
	$self->_update("background");
	carp("cannot save norm(E) file from chi(k) data"), return if ($self->get("is_chi"));
	$self->save_norm($filename);
	last WHAT;
      };
      (lc($what) eq 'chi') and do {
	$self->_update("fft");
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
      (lc($what) eq 'bkgsub') and do {
	$self->_update("all");
	$self->dispose($self->save_bkgsub($filename));
	last WHAT;
      };
    };
    return $self;
  };

  ## need to include the data's titles in write_data() command
  sub save_fit {
    my ($self, $filename) = @_;
    croak("No filename specified for save_fit") unless $filename;
    $self->title_glob("dem_data_", "f");
    my $command = $self-> template("fit", "save_fit", {filename => $filename,
						       titles   => "dem_data_*"});
    $self->dispose($command);
    return $self;
  };

  sub save_bkgsub {
    my ($self, $filename) = @_;
    croak("No filename specified for save_bkgsub") unless $filename;
    $self->title_glob("dem_data_", "f");
    my $command = $self-> template("fit", "save_bkgsub", {filename => $filename,
						          titles   => "dem_data_*"});
    $self->dispose($command);
    return $self;
  };

  sub read_fit {
    my ($self, $filename) = @_;
    croak("No filename specified for read_fit") unless $filename;
    my $command = $self-> template("fit", "read_fit", {filename => $filename,});
    $self->dispose($command);
    $self->set({update_fft=>1});
    return $self;
  };

  ## standard deviation array?
  sub serialize {
    my ($self, $filename) = @_;
    croak("No filename specified for serialize") unless $filename;
    open my $Y, ">".$filename;
    print $Y $self->SUPER::serialize;
    if ($self->get("is_xmu")) {
      my @array = $self->get_array("energy");
      print $Y YAML::Dump(\@array);
      @array = $self->get_array("xmu");
      print $Y YAML::Dump(\@array);
      if ($self->get("is_col")) {
	@array = $self->get_array("i0");
	print $Y YAML::Dump(\@array);
      }
    } elsif ($self->get("is_chi")) {
      my @array = $self->get_array("k");
      print $Y YAML::Dump(\@array);
      @array = $self->get_array("chi");
      print $Y YAML::Dump(\@array);
    };
    close $Y;
    return $self;
  };
  sub deserialize {
    my ($self, $filename_or_stream) = @_;
    croak("No filename or YAML stream specified for deserialize") unless $filename_or_stream;
    my $data = Ifeffit::Demeter::Data->new();
    my ($rhash, $ra1, $ra2, $ra3);
    if ($filename_or_stream =~ m{\n}) {
      ($rhash, $ra1, $ra2, $ra3) = YAML::Load($filename_or_stream);
    } else {
      ($rhash, $ra1, $ra2, $ra3) = YAML::LoadFile($filename_or_stream);
    };
    delete $$rhash{file};
    $data->set($rhash);
    if ($rhash->{is_xmu}) {
      Ifeffit::put_array("$data.energy", $ra1);
      Ifeffit::put_array("$data.xmu",    $ra2);
      Ifeffit::put_array("$data.i0",     $ra3) if (defined $ra3);
      $data->set({update_norm => 1});
    } elsif ($rhash->{is_chi}) {
      Ifeffit::put_array("$data.k",      $ra1);
      Ifeffit::put_array("$data.chi",    $ra2);
      $data->set({update_fft  => 1});
    };
    return $data;
  };
  {
    no warnings 'once';
    # alternate names
    *freeze = \ &serialize;
    *thaw   = \ &deserialize;
  }

  sub nidp {
    my ($self) = @_;
    my ($kmin, $kmax, $rmin, $rmax) = $self->get(qw(fft_kmin fft_kmax bft_rmin bft_rmax));
    return 2 * ($kmax-$kmin) * ($rmax-$rmin) / $PI;
  };

  sub chi_noise {
    my ($self) = @_;
    my $string = $self->template("process", "chi_noise");
    $self->dispose($string);
    return (Ifeffit::get_scalar("epsilon_k"),
	    Ifeffit::get_scalar("epsilon_r"),
	    Ifeffit::get_scalar("kmax_suggest"),
	   );
  };

  sub rfactor {
    my ($self) = @_;
    my (@x, @dr, @di, @fr, @fi, $xmin, $xmax);
    if (lc($self->get('fit_space')) eq 'k') {
      ($xmin,$xmax) = $self->get(qw(fft_kmin fft_kmax));
      @x  = $self -> get_array("k");
      @di = $self -> get_array("chi");
      @fr = $self -> get_array("chi", "fit");
    } elsif (lc($self->get('fit_space')) eq 'r') {
      ($xmin,$xmax) = $self->get(qw(bft_rmin bft_rmax));
      @x  = $self -> get_array("r");
      @dr = $self -> get_array("chir_re");
      @di = $self -> get_array("chir_im");
      @fr = $self -> get_array("chir_re", "fit");
      @fi = $self -> get_array("chir_im", "fit");
    } elsif (lc($self->get('fit_space')) eq 'q') {
      ($xmin,$xmax) = $self->get(qw(fft_kmin fft_kmax));
      @x  = $self -> get_array("q");
      @dr = $self -> get_array("chiq_re");
      @di = $self -> get_array("chiq_im");
      @fr = $self -> get_array("chiq_re", "fit");
      @fi = $self -> get_array("chiq_im", "fit");
    };
    my ($numerator, $denominator) = (0,0);
    foreach my $i (0 .. $#x) {
      next if ($x[$i] < $xmin);
      last if ($x[$i] > $xmax);
      $numerator   += ($dr[$i] - $fr[$i])**2;
      $denominator +=  $dr[$i]           **2;
      if (lc($self->get('fit_space')) ne 'k') {
	$numerator   += ($di[$i] - $fi[$i])**2;
	$denominator +=  $di[$i]           **2;
      };
    };
    return ($denominator) ? $numerator/$denominator : 0;
  };

  ## parts are plotted and Fourier transformed just like their
  ## respective data, these methods just rewrite the data plot()
  ## fftf() or fftr() command using the group name of the part
  sub part_fft {
    my ($self, $part) = @_;
    $self->dispose($self->_part_fft_command($part));
    return $self;
  };
  sub _part_fft_command {
    my ($self, $pt) = @_;
    my $part = ($pt eq 'sum') ? 'fit' : $pt; # sum is a synonym for fit
    croak('part_fft: valid parts are fit, res, and bkg') if ($part !~ /(?:bkg|fit|res)/);
    my $group = join("_", $self, $part);
    my $string = $self->_fft_command;
    $string =~ s{\b$self\b}{$group}g; # replace group names
    return $string;
  };
  sub part_bft {
    my ($self, $part) = @_;
    $self->dispose($self->_part_bft_command($part))
  };
  sub _part_bft_command {
    my ($self, $pt) = @_;
    my $part = ($pt eq 'sum') ? 'fit' : $pt; # sum is a synonym for fit
    croak('part_bft: valid parts are fit, res, and bkg') if ($part !~ /(?:bkg|fit|res)/);
    my $group = join("_", $self, $part);
    my $string = $self->_bft_command;
    $string =~ s{\b$self\b}{$group}g; # replace group names
    return $string;
  };
  sub part_plot {
    my ($self, $part, $space) = @_;
    $self->part_fft($part) if (lc($space) ne 'k');
    $self->part_bft($part) if (lc($space) eq 'q');
    my $command = $self->_part_plot_command($part, $space);
    $self->dispose($command, "plotting");
    return $self;
  };
  sub _part_plot_command {
    my ($self, $pt, $space) = @_;
    my $pf           = Ifeffit::Demeter->get_mode('plot');
    $pt            ||= q{};
    my $part         = ($pt eq 'sum') ? 'fit' : $pt; # sum is a synonym for fit
    #croak('part_plot: valid parts are fit, res, and bkg') if ($part !~ /(?:bkg|fit|res)/);
    my $group        = ($part =~ /(?:bkg|fit|res)/) ? join("_", $self, $part) : $self->label;
    my %labels       = (bkg=>'background', fit=>$self->get('fitsum'), res=>'residual');
    $labels{$part} ||= $part->label;
    my $datalabel    = $self->label;

    $self->new_params({plot_part => $part});
    my $string = $self->hashes;
    $string   .= ($part =~ /(?:bkg|fit|res)/) ? " plot $labels{$part} ___\n" : " plot path ___\n";
    $string   .= $self->_plot_command($space, $pf);

    #print $string  if ($part !~ /(?:bkg|fit|res)/);

    ## (?<+ ) is the positive zero-width look behind -- it only # }
    ## replaces the label when it follows q{key="}, i.e. it won't get
    ## confused by the same text in the title for a newplot
    if ($self->get_mode("pgplot")) {
      $string =~ s{(?<=key=")$datalabel}{$labels{$part}};
    } elsif ($self->get_mode("gnuplot")) {
      $string =~ s{(?<=title ")$datalabel}{$labels{$part}};
    };
    if (($self->get_mode("gnuplot")) and ($datalabel =~ m{\A\s*\z})) {
      $string =~ s{(?<=title ")$labels{$part}}{};
    };
    return $string if ($part !~ /(?:bkg|fit|res)/);

    ## (?! ) is the negative zero-width look ahead -- it does not
    ## replace the group name when it is followed by k, r, or q
    $string =~ s{\b$self(?!\.[krq]\b)}{$group}g;                # }
    return $string;
  };

  sub plot_window {
    my ($self, $space) = @_;
    $self->fft if (lc($space) eq 'k');
    $self->bft if (lc($space) eq 'r');
    $self->dispose($self->_prep_window_command($space));

    #if (Ifeffit::Demeter->get_mode('template_plot') eq 'gnuplot') {
    #  $self->get_mode('external_plot_object')->gnuplot_cmd($self->_plot_window_command($space));
    #  $self->get_mode('external_plot_object')->gnuplot_pause(-1);
    #} else {
    $self->dispose($self->_plot_window_command($space), "plotting");
    #};
    return $self;
  };
  sub _prep_window_command {
    my ($self, $sp) = @_;
    my $pf      = Ifeffit::Demeter->get_mode('plot');
    my $space   = lc($sp);
    my %dsuff   = (k=>'chik',            r=>'chir_mag', 'q'=>'chiq_mag');
    my $suffix  = ($space eq 'r') ? 'rwin' : 'win';
    my $string  = "\n" . $self->hashes . " plot window ___\n";
    if ($space eq 'r') {
      $string .= $self->template("process", "prep_rwindow");
    } else {
      $string .= $self->template("process", "prep_kwindow");
    };
    return $string;
  };

  sub _plot_window_command {
    my ($self, $sp) = @_;
    my $pf      = Ifeffit::Demeter->get_mode('plot');
    my $space   = lc($sp);
    $self -> new_params({window_space => $space,
			 window_size  => sprintf("%.5g", Ifeffit::get_scalar("win___dow")),
			});
    my $string = $self->template("plot", "window");
    ## reinitialize the local plot parameters
    $pf -> reinitialize(q{}, q{});
    return $string;
  };

  sub data_parameter_report {
    my ($self, $include_rfactor) = @_;
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    my $data = $self->data;
    my $string = $data->template("process", "data_report");
    $string =~ s/\+ \-/- /g;
    return $string;
  };
  sub fit_parameter_report {
    my ($self, $include_rfactor, $fit_performed) = @_;
    $include_rfactor ||= 0;
    $fit_performed   ||= 0;
    my $data = $self->data;
    my $string = $data->template("fit", "fit_report");
    if ($include_rfactor and $fit_performed) {	# only print this for a multiple data set fit
      $string .= sprintf("\nr-factor for this data set = %.7f\n", $self->rfactor);
    };
    return $string;
  };
  sub _kw_string {
    my ($self) = @_;
    my @list = ();
    push @list, "1" if $self->get("fit_k1");
    push @list, "2" if $self->get("fit_k2");
    push @list, "3" if $self->get("fit_k3");
    push @list, $self->get("fit_karb_value") if $self->get("fit_karb");
    return join(",", @list);
  };

  sub plot_marker {
    my ($self, $requested, $x) = @_;
    my $command = q{};
    my @list = (ref($x) eq 'ARRAY') ? @$x : ($x);
    foreach my $xx (@list) {
      my $y = $self->yofx($requested, "", $xx);
      $command .= $self->template("plot", "marker", { x => $xx, 'y'=> $y });
    };
    #if ($self->get_mode("template_plot") eq 'gnuplot') {
    #  $self->get_mode('external_plot_object')->gnuplot_cmd($command);
    #} else {
      $self -> dispose($command, "plotting");
    #};
    return $self;
  };

  sub points {
    my ($self, $args) = @_;
    $$args{space}     = lc($$args{space});
    $$args{shift}   ||= 0;
    $$args{scale}   ||= 1;
    $$args{yoffset} ||= 0;
    $$args{part}    ||= q{};

    my @x = ($$args{space} eq 'e') ? $self->get_array('energy')
          : ($$args{space} eq 'k') ? $self->get_array('k')
          : ($$args{space} eq 'r') ? $self->get_array('r')
          :                          $self->get_array('q');
    @x = map {$_ + $$args{shift}} @x;

    my @y = ();
    my $regexp = $self->regexp('data_parts');
    if ($$args{part} =~ m{$regexp}) {
      @y = $self->get_array($$args{suffix}, $$args{part});
    } elsif (ref($$args{part}) =~ m{Path}) {
      #print $$args{part}, "  ", ref($$args{part}), "  ", $$args{file}, $/;
      @y = $$args{part}->get_array($$args{suffix});
    } else {
      @y = $self->get_array($$args{suffix});
    };
    if (defined $$args{weight}) {
      @y = pairwise {$$args{scale}*$a**$$args{weight}*$b + $$args{yoffset}} @x, @y;
    } else {
      @y = map {$$args{scale}*$_ + $$args{yoffset}} @y;
    };

    my $message = q{};
    pairwise { $message .= join(" ", $a, $b, $/) } @x, @y;
    if ($$args{file}) {
      open my $T, '>'.$$args{file};
      print $T $message;
      close $T;
      return $$args{file};
    } else {
      return $message;
    };
  };

};
1;

=head1 NAME

Ifeffit::Demeter::Data - Process and analyze EXAFS data with Ifeffit


=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.


=head1 SYNOPSIS

  my $data = Ifeffit::Demeter::Data ->
       new({group => 'data0',});
  $data -> set({file      => "example/cu/cu10k.chi",
	        fft_kmax  => 3, # \ note that this gets
	        fft_kmin  => 14,# / fixed automagically
	        bft_rmax  => 4.3,
	        fit_k1    => 1,
	        fit_k3    => 1,
	        label     => 'My copper data',
	       });
  $data -> plot("r");

=head1 DESCRIPTION

This subclass of the L<Ifeffit::Demeter> class is inteded to hold
information pertaining to data for use in data processing and
analysis.

=head1 ATTRIBUTES

The following are the attributes of the Data object.  Attempting to
access an attribute not on this list will throw an exception.

The type of argument expected in given in parentheses. i.e. number,
integer, string, and so on.  The default value, if one exists, is
given in square brackets.  The label "{read-only}" means that you can
C<get> that attribute value, but C<set>ting it has no effect.

For a Data object to be included in a fit, it is necessary that it be
an attribute of a Fit object.  See L<Ifeffit::Demeter::Fit> for
details.

=head2 General Attributes

=over 4

=item C<group> (string) I<[random 4-letter string]>

This is the name associated with the data.  It's primary use is as the group
name for the arrays associated with the data in Ifeffit.  That is, its arrays
will be called I<group>.k, I<group>.chi, and so on.  It is best if this is a
reasonably short word and it B<must> follow the conventions of a valid group
name in Ifeffit.  The default group is a random four-letter string generated
automatically when the object is created.

=item C<tag> (string) I<[same random 4-letter string as group]>

Use to disambiguate guess parameter names when doing variable name
substitution for local parameters.

=item C<file> (filename)

This is the file containing the chi(k) associated with this data object.

=item C<label> (string)

This is a text string used to describe this object in a plot ot a user
interface.  Like the C<group> attribute, this should be short, but it
can be a bit more verbose.  It should be a single line, unlike the
C<title> attibute.

=item C<is_xmu> (boolean)

This is true if the file indicated by the C<file> attribute contains
mu(E) data.  See the description of the C<read_data> method for how
this gets set automatically and when you may need to set it by hand.

=item C<is_chi> (boolean)

This is true if the file indicated by the C<file> attribute contains
chi(k) data.  See the description of the C<read_data> method for how
this gets set automatically and when you may need to set it by hand.

=item C<is_col> (boolean)

This is true if the file indicated by the C<file> attribute contains
column data that needs to be converted into mu(E) data.  See the
description of the C<read_data> method for how this gets set
automatically and when you may need to set it by hand.

=item C<columns> (string)

This string contains Ifeffit's C<$column_label> string from importing
the data file.

=item C<energy> (string)

This string uses gnuplot-like notation to indicate which column in the
data file contains the energy axis.  As an example, if the first
column contains the energy, this string should be C<$1>.

=item C<numerator> (string)

This string uses gnuplot-like notation to indicate how to convert
columns from the data file into the numerator of the expression for
computing mu(E).  For example, if these are transmission data and I0
is in the 2nd column, this string should be C<$2>.

If these are fluorescence data measured with a multichannel analyzer
and the MCA channels are in columns 7 - 10, then this string would be
C<$7+$8+$9+$10>.

=item C<denominator> (string)

This string uses gnuplot-like notation to indicate how to convert
columns from the data file into the denominator of the expression for
computing mu(E).  For example, if these are transmission data and
transmission is in the 3nd column, this string should be C<$3>.

=item C<ln> (boolean)

This is true for transmission data, i.e. if cponversion from columns
to mu(E) requires that the natural log be taken.

=back

=head2 Background Removal Attributes

=over 4

=item C<bkg_e0> (number)

The E0 value of mu(E) data.  This is determined from the data when the
read_data method is called.

=item C<bkg_e0_fraction> (number) I<[0.5]>

This is a number between 0 and 1 used for the e0 algorithm which sets
e0 to a fraction of the edge step.  See L<Ifeffit::Demeter::Data>.

=item C<bkg_eshift> (number) I<[0]>

An energy shift to apply to the data before doing any further processing.

=item C<bkg_kw> (number) I<[1]>

The k-weight to use during the background removal using the Autobk algorithm.

=item C<bkg_rbkg> (number) I<[1]>

The Rbkg value in the Autobk algorithm.

=item C<bkg_dk> (number) I<[0]>

The dk value to be used in the Fourier transform as part of the Autobk
algorithm.

=item C<bkg_pre1> (number) I<[-150]>

The lower end of the range of the pre-edge regression, relative to E0.

=item C<bkg_pre2> (number) I<[-30]>

The upper end of the range of the pre-edge regression, relative to E0.

=item C<bkg_nor1> (number) I<[100]>

The lower end of the range of the post-edge regression, relative to E0.

=item C<bkg_nor2> (number) I<[600]>

The upper end of the range of the post-edge regression, relative to E0.

=item C<bkg_spl1> (number) I<[0]>

The lower end in k of the spline range in the Autobk algorithm.  The value of
bkg_spl1e is updated whenever this is updated.

=item C<bkg_spl2> (number) I<[15]>

The upper end in k of the spline range in the Autobk algorithm.  The value of
bkg_spl2e is updated whenever this is updated.

=item C<bkg_spl1e> (number) I<[0]>

The lower end in energy of the spline range in the Autobk algorithm,
relative to E0.  The value of bkg_spl1 is updated whenever this is
updated.

=item C<bkg_spl2e> (number) I<[857]>

The upper end in energy of the spline range in the Autobk algorithm,
relative to E0.  The value of bkg_spl2 is updated whenever this is
updated.

=item C<bkg_kwindow> (list) I<[Hanning]>

This is the functional form of the Fourier transform window used in
the Autobk algorithm.  It is one of

   Kaiser-Bessel Hanning Welch Parzen Sine Gaussian

=item C<bkg_slope> (number) {read-only}

The slope of the pre-edge line.  This is set as part of the
C<normalize> method.

=item C<bkg_int> (number) {read-only}

The intercept of the pre-edge line.  This is set as part of the
C<normalize> method.

=item C<bkg_step> (number)

The edge step found by the C<normalize> method.  This attribute will
be overwritten the next time the C<normalize> method is called unless
the C<bkg_fixstep> atribute is set true.

=item C<bkg_fitted_step> (number) {read-only}

The value of edge step found by the C<normalize> method, regardless of
the setting of C<bkg_fixstep>.  This is needed to correctly flatten
data.

=item C<bkg_fixstep> (boolean) I<[0]>

When true, the value of the c<bkg>_step will not be overwritten by the
c<normalize> method.

=item C<bkg_nc0> (number) {read-only}

The constant parameter in the post-edge regression.  This is set as part of
the c<normalize> method.

=item C<bkg_nc1> (number) {read-only}

The linear parameter in the post-edge regression.  This is set as part of
the C<normalize> method.

=item C<bkg_nc2> (number) {read-only}

The cubic parameter in the post-edge regression.  This is set as part of
the C<normalize> method.

=item C<bkg_flatten> (boolean) I<[1]>

When true, a plot of normalized mu(E) data will be flattened.

=item C<bkg_fnorm> (boolean) I<[0]>

When true, a functional normalization is performed.  I<not yet implemented>

=item C<bkg_nnorm> (integer) I<[3]>

This can be either 2 or 3 and specifies the order of the post-edge regression.
When this is 2, C<bkg_nc2> will be forced to 0 in the regression.  I<not yet
implemented>

=item C<bkg_stan> (Data or Path object)

The background removal standard.  This can be either a Data object or a Path
object.  I<not yet implemented>

=item C<bkg_clamp1> (integer) I<[0]>

The value of the low-end spline clamp.

=item C<bkg_clamp2> (integer) I<[24]>

The value of the high-end spline clamp.

=item C<bkg_nclamp> (integer) I<[5]>

The number of data points to use in evaluating the clamp.

=item C<bkg_cl> (boolean) I<[0]>

When true, use Cromer-Liberman normalization rather than the Autobk algorithm.
I<not yet implemented>

=item C<bkg_z> (number)

The Z number of the absorber for these data.  This is determined as part of
the normalize method but can also be set by hand.  To deal with edge energy
confusions, certain K and L3 edges are prefered over nearby L2 and L3 edges
when this attribute is set automatically.

       prefer     over
      ----------------
       Fe K       Nd L1
       Mn K       Ce L1
       Bi K       Ir L1
       Se K       Tl L2
       Pt L3      W  L2
       Se K       Pb L2
       Np L3      At L1
       Cr K       Ba L1

=back

=head2 Forward Transform Attributes

Note that there is not an C<fft_kw> attribute.  For all plotting and
data processing purposes, the Plot object's C<kweight> attribute is
used, while in fits the Fit object's k-weighting attributes are used.

=over 4

=item C<fft_edge> (edge symbol) I<[K]>

The absorption edge measured by the input data.  This is used doing a
central-atom-only phase correction to the Fourier transform.

=item C<fft_kmin> (number) I<[2]>

The lower end of the k-range for the forward transform.  C<fft_kmin> and
C<fft_kmax> will be sorted by Demeter.

=item C<fft_kmax> (number) I<[12]>

The upper end of the k-range for the forward transform.  C<fft_kmin> and
C<fft_kmax> will be sorted by Demeter.

=item C<fft_dk> (number) I<[2]>

The width of the window sill used for the forward transform.  The meaning of
this parameter depends on the functional form of the window.  See the Ifeffit
document for a full discussion of the functional forms.

=item C<fft_kwindow> (list) I<[Hanning]>

This is the functional form of the Fourier transform window used in
the forward transform.  It is one of

   Kaiser-Bessel Hanning Welch Parzen Sine Gaussian

=item C<fft_pc> (Path object) I<[0]>

This is set to the Path object to be used for a full phase correction to the
Fourier transform.

=item C<rmax_out> (number) I<[10]>

This tells Ifeffit how to size output arrays after doing a Fourier transform.

=back

=head2 Back Transform Attributes

=over 4

=item C<bft_rwindow> (number) I<[Hanning]>

This is the functional form of the Fourier transform window used in
the backward transform.  It is one of

   Kaiser-Bessel Hanning Welch Parzen Sine Gaussian

=item C<bft_rmin> (number) I<[1]>

The lower end of the R-range for the backward transform or the fitting range.
C<bft_rmin> and C<bft_rmax> will be sorted by Demeter.

=item C<bft_rmax> (number) I<[3]>

The upper end of the R-range for the backward transform or the fitting range.
C<bft_rmin> and C<bft_rmax> will be sorted by Demeter.

=item C<bft_dr> (number) I<[0.2]>

The width of the window sill used for the backward transform.  The meaning of
this parameter depends on the functional form of the window.  See the Ifeffit
document for a full discussion of the functional forms.

=back

=head2 Fitting Attributes

Note that parameters with C<fft_> and C<bft_> analogs such as
C<fft_kmin> have been deprecated along with the C<process> mode.

=over 4

=item C<fitting> (boolean) I<[0]>

This is set to true when a Data object is used in a fit.  It is used by
plotting methods to determine whether data parts (fit, background, residual)
should be considered for plotting.

=item C<fit_k1> (boolean) I<[1]>

If true, then k-weight of 1 will be used in the fit.  Setting more
than one k-weighting parameter to true will result in a multiple
k-weight fit.

=item C<fit_k2> (boolean) I<[0]>

If true, then k-weight of 2 will be used in the fit.  Setting more
than one k-weighting parameter to true will result in a multiple
k-weight fit.

=item C<fit_k3> (boolean) I<[0]>

If true, then k-weight of 3 will be used in the fit.  Setting more
than one k-weighting parameter to true will result in a multiple
k-weight fit.

=item C<fit_karb> (boolean) I<[0]>

If true, then the user-supplied, arbitrary k-weight will be used in
the fit.  Setting more than one k-weighting parameter to true will
result in a multiple k-weight fit.

=item C<fit_karb_value> (number) I<[0]>

This is the value of the arbitrary k-weight which will be used in the
fit is C<fit_karb> is true.

=item C<fit_space> (list) I<[R]>

This is the space in which the fit will be evaluated.  It is one of
C<k>, C<r>, or C<q>.

=item C<fit_epsilon> (number) I<[0]>

If this number is non-zero, it will be used as the measurement
uncertainty in k-space when the fit is evaluated.  If it is zero, then
Ifeffit's default will be used.

=item C<fit_cormin> (number) I<[0.4]>

This is the minimum value of correlation to be reported in the log
file after a fit.

=item C<fit_pcpath> (Path object)

This is the Path object to use for phase correction when these data
and it paths are plotted.  It takes the reference to the Path object
as its value.

=item C<fit_include> (boolean) I<[1]>

When this is true, the data will be included in the next fit.

=item C<fit_plot_after_fit> (boolean) I<[0]>

This is a flag for use by a user interface to indicate that after a
fit is finished, this data set should be plotted.

=item C<fit_do_bkg> (boolean) I<[0]>

When true, the background function will be corefined for this data set
and the "bkg" part of the data will be created.

=item C<fit_titles> (multiline string)

These are title lines associated with this Data object.  These lines
will be written to log files, output data files, etc.

=item C<fitsum> (list) {read-only}

This attribute indicates whether the Fit objects C<fit> or C<ff2chi>
mehthod was most recently called.  It is one of C<fit> or C<sum>.
It's purpose is to allow the fit part of the data object to be labeled
correctly in a plot.

=back

=head2 Plotting Attributes

Most aspects of how plots are made are handled by the attributes of
the Plot object.  These Data attributes are specific to a particular
Data object and influence how that object is plotted.

=over 4

=item C<y_offset> (number) I<[0]>

The vertical displacement given to this data when plotted.  This is
useful for making stacked plots.

=item C<plot_multiplier> (number) I<[1]>

An over-all scaling factor for this data when plotted.  It is probably
a bad idea for this to be 0.

=back

=head1 METHODS

This subclass inherits from Ifeffit::Demeter, so all of the methods of
the parent class are available.

See L<Ifeffit::Demeter/Object_handling_methods> for a discussion of
accessor methods.

=head2 I/O methods

These methods handle the details of file I/O.  See also the C<save>
method of the parent class.

=over 4

=item C<save>

This method returns the Ifeffit commands necessary to write column data files
based on the data object.  This method takes two arguments, the output
filename and the type of the output file.  The types are:

=over 4

=item xmu

This is a 7 column file: energy, mu(E), bkg(E), pre(E), post(E), derivative of
mu(E), and second derivative of mu(E).

=item norm

This is a 7 column file: energy, normalized mu(E), normalized bkg(E),
flattened mu(E), flattened bkg(E), derivative of norm(E), and second
derivative of norm(E).

=item chi

This is a 6 or 7 column file: k, chi(k), window, k*chi(k), k^2*chi(k), and
k^3*chi(k).  If the fft_karb attribute is true, then seventh column containg
the fft_karb_value-weighted chi(k) will be included.

=item r

This is a 6 column file: R, real part, imaginary part, magnitude, phase,
and window.

=item q

This is a 7 column file: back transform k, real part, imaginary part,
magnitude, phase, and window in k. The last column is the original chi(k)
weighted by the k-weight used in the Fourier transform.

=item fit

This is a 5 or 6 column file: k, chi(k), fit(k), residual(k), and k-window.
If the C<fit_do_bkg> attribute is true, then the background in k will be the
column between the residual and the window.

=back

   $command = $dobject->save("cufit.fit", "fit");

This method will automatically generate useful headers for the output
data file.  These headers will include the title lines associated with
the data in Ifeffit and the text of the C<fit_parameter_report> method.

=item C<data_parameter_report>

This method returns a simple, textual summary of the attributes of the data
object related to background removal and data processing.  It is used in log
files, output data files, and elsewhere.  It may also be useful as a way of
interactively describing the data.

=item C<fit_parameter_report>

This method returns a simple, textual summary of the attributes of the
data object related to the fit.  It is used in log files, output data
files, and elsewhere.  It may also be useful as a way of interactively
describing the data.  The two optional arguments control whether the
r-factor is computed as part of the report.

=item C<r_factor>

This returns an evaluation of the R-factor from a fit for a single
data set.  This is different from the R-factor for a multiple data set
fit as reported by Ifeffit in that this number includes only the
misfit of the single data set.

  $r = $data_object -> r_factor;

=item C<nidp>

This returns the number of independent points associated with this
data set, as determined from the values of the k- and R-range
parameters.

   $n = $data_object->nidp;

The Athena-like fft and bft ranges are used if the processing mode is
set to "fft".  The Artemis-like fit ranges are used if the processing
mode is set to "fit".

=item C<plot>

Use this method to make plots of data.  Demeter keeps track of changes
to parameters and which data processing steps need to be taken in
order to correctly make the plot.  Consequently, it should never be
necessary to import data or perform a Fourier tansform by hand.  The
practice with Demeter is to create a Data group, set some of its
attributes, and then make a plot.

  $data_object -> plot($space)

The argument is one of C<E>, C<k>, C<R>, C<q>, or C<kq>.

=back

=head2 Convenience methods

=over 4

=item C<set_windows>

This is a shortcut to setting the functional form of all Fourier
transform windows used by the Data object.  In one swoop, this method
sets C<bkg_kwindow>, C<fit_kwindow>, C<fit_rwindow>, C<fft_kwindow>,
and C<bft_rwindow> to the specified window type.

  $data_object -> set_windows("Hanning");

The window type must be one of C<Kaiser-Bessel>, C<Hanning>,
C<Parzen>, C<Welch>, C<Sine>, or C<Gaussian>.

=item C<data>

This method returns the reference to the data object itself.  This is
less silly than it seems.  Having a C<data> method defined for both
Data and Path objects allows a loop over both kinds of objects and
provides a simple way to identify the correct Data object.

  foreach my $obj (@data_objects, @paths_objects) {
     my $d = $obj->data;
     ## do something with $d
  };

=item C<plot_marker>

Mark an arbitrary point in the data.

  $data -> plot_marker($part, $x);

or

  $data -> plot_marker($part, \@x);

The C<$part> is the suffix of the array to be marked, for example
"xmu", "der", or "chi".  The second argument can be a point to mark or
a reference to a list of points.

=back


=head1 DATA FILES AND DATA PARTS


When data are imported, Demeter tries to figure out whether the data
are raw data, mu(E) or chi(k) data, if that has not been specified.
The heuristics are as follows:

=over 4

=item *

If the C<numerator> or C<denominator> attributes are set, this is data
is assumed to be column data that will be interpreted as raw data and
converted in mu(E) data.

=item *

The data will be read by Ifeffit.  If the first data point is greater
than 100, it will be assumed that these data are mu(E) and that the
energy axis is absolute energy.

=item *

If the last data point is greater than 35, it will be assumed that
these data are mu(E) and that the energy axis si relative energy.

=item *

If none of the above are true, then the data must be chi(k) data.

=back

If your data will be misintepreted by these heuristics, then you
B<must> set the C<is_xmu> of C<is_chi> attributes by hand.


The Data object has several parts associated with it.  Before a fit
(or ff2chi) is done, there are two parts: the data itself and the
window.  After the fit, there is a residual, a fit, and (if the
C<fit_do_bkg> attribute is true) a background.  Attributes of the
L<Ifeffit::Demeter::Plot> object are used to specify which Data parts
are shown in a plot.

=head1 COERCIONS

When the reference to the Data object is used in string context, it
returns the group name.  So

  my $data = Ifeffit::Demeter::Data ->
       new({group => 'data0',
	    file  => "example/cu/cu10k.chi",
	    label => 'My copper data',
	   });
  print "This is $data.\n";

will print

  This is data0.

=head1 DIAGNOSTICS

These messages are classified as follows (listed in increasing order
of desperation):

    (W) A warning (optional).
    (F) A fatal error (trappable).

=over 4

=item C<"$key" is not a valid Ifeffit::Demeter::Data parameter>

(W) You have attempted to access an attribute that does not exist.  Check
the spelling of the attribute at the point where you called the accessor.

=item C<Ifeffit::Demeter::Data: "group" is not a valid group name>

(F) You have used a group name that does not follow Ifeffit's rules for group
names.  The group name must start with a letter.  After that only letters,
numbers, &, ?, _, and : are acceptable characters.  The group name must be no
longer than 64 characters.

=item C<Ifeffit::Demeter::Data: "$key" takes a number as an argument>

(F) You have attempted to set a numerical attribute with something
that cannot be interpretted as a number.


=item C<Ifeffit::Demeter::Data: $k must be a number>

(F) You have attempted to set an attribute that requires a numerical
value to something that cannot be interpreted as a number.

=item C<Ifeffit::Demeter::Data: $k must be a positive integer>

(F) You have attempted to set an attribute that requires a positive
integer value to something that cannot be interpreted as such.

=item C<Ifeffit::Demeter::Data: $k must be a window function>

(F) You have set a Fourier transform window attribute to something not
recognized as a window function.

=item C<Ifeffit::Demeter::Data: $r_hash->{$k} is not a readable data file>

(F) You have set the C<file> attribute to something that cannot be
found on disk.

=item C<Ifeffit::Demeter::Data: $k must be one of (k R q)>

(F) You have set a fitting space that is not one C<k>, C<R>, or C<q>.

=item C<Ifeffit::Demeter::Data: $k must be one of (K L1 L2 L3)>

(F) You have attempted to set the C<fft_edge> attribute to something
that is not recognized as an edge symbol.

=item C<No filename specified for save>

(F) You have called the save method without supplying a filename
for the output file.

=item C<Valid save types are: xmu norm chi r q fit bkgsub>

(F) You have called the save method with an unknown output file type.

=item C<cannot save mu(E) file from chi(k) data>

=item C<cannot save norm(E) file from chi(k) data>

(F) You have attempted to write out data in energy for data that were
imported as chi(k).

=item C<No filename specified for serialize>

(F) You have not supplied a filename for your data serialization.

=item C<No filename or YAML stream specified for deserialize>

(F) You have not supplied a filename from which to deserialization
data.

=back


=head1 SERIALIZATION AND DESERIALIZATION

The serialization format of a data object is as a YAML file.  The YAML
serialization begins with a mapping of the Data object attributes.  This is
followed by sequences representing the data.  For mu(E) data, the sequences
are energy and xmu.  If the data was column data, the xmu sequence is followed
by a sequence representing the i0 array.  For chi(k) data, the mapping is
followed by sequences representing k and chi(k).

To serialize a Data object to a file:

  $data -> serialize($filename);

To import the serialized data and create a Data object to hold it:

  $data -> deserialize($filename);

As a convenience C<freeze> is a synonym for C<serialize> and C<thaw>
is a synonym for C<deserialize>.

Among the many attractive features of YAML as a serialization format is that
YAML is supported by lots of programming languages.  So Demeter serialization
can be imported easily into other analysis software.

=head1 CONFIGURATION

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.  Many attributes of a Data object can be configured via the
configuration system.  See, among others, the C<bkg>, C<fft>, C<bft>,
and C<fit> configuration groups.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Several features have not yet been implemented.

=over 4

=item *

Not all of the Athena-like data process methods (alignment, merging, and
so on) have been implemented yet.

=item *

Various background and normalization options: functional
normalization, normalization order, background removal standard,
Cromer-Liberman

=item *

Tied reference channel

=item *

Standard deviation for merged data not written to serialization.

=back

Please report problems to Bruce Ravel (bravel AT anl DOT gov)

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
