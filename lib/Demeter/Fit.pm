package Demeter::Fit;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

#use diagnostics;
use autodie qw( open close );
use File::Copy;
use File::Spec;

use Moose;
extends 'Demeter';
use MooseX::AttributeHelpers;
use MooseX::Aliases;
#use MooseX::StrictConstructor;

with 'Demeter::Fit::Happiness';
with 'Demeter::Fit::Sanity';

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Interview';
  with 'Demeter::UI::Screen::Progress';
};


use Demeter::NumTypes qw( NonNeg Natural NaturalC );

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Carp;
use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::Util qw(max);
use List::MoreUtils qw(any none zip uniq);
use Regexp::Assemble;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER    => $RE{num}{real};
Readonly my $STAT_TEXT => "n_idp n_varys chi_square chi_reduced r_factor epsilon_k epsilon_r data_total";
Readonly my $NULLFILE  => '@&^^null^^&@';
use Text::Wrap;
use YAML::Tiny;

use Text::Wrap;
$Text::Wrap::columns = 65;

## -------- properties
has 'description'    => (is => 'rw', isa => 'Str',    default => q{});
has 'fom'            => (is => 'rw', isa => 'Num',    default => 0);
has 'fitenvironment' => (is => 'rw', isa => 'Str',    default => sub{ shift->environment });
has 'interface'      => (is => 'rw', isa => 'Str',    default => 'Demeter-based perl script'); # should be sensitive to :ui "pragma"
has 'started'        => (is => 'rw', isa => 'Str',    default => q{});  # should be a Date/Time object
has 'time_of_fit'    => (is => 'rw', isa => 'Str',    default => q{});  # should be a Date/Time object
has 'prepared_by'    => (is => 'rw', isa => 'Str',    default => sub{ shift->who });
has 'contact'        => (is => 'rw', isa => 'Str',    default => q{});
has 'fitted'         => (is => 'rw', isa => 'Bool',   default => 0);
has 'number'         => (is => 'rw', isa => 'Num',    default => 0);

## -------- serialization/deserialization
has 'project'        => (is => 'rw', isa => 'Str',    default => q{},
			 trigger => sub{my ($self, $new) = @_; $self->deserialize(file=>$new) if $new} );
has 'folder'         => (is => 'rw', isa => 'Str',    default => q{});

## -------- mechanics of the fit
has 'cormin'         => (is => 'rw', isa =>  NonNeg,  default => sub{ shift->co->default("fit", "cormin")  || 0.4});
has 'header'         => (is => 'rw', isa => 'Str',    default => q{});
has 'footer'         => (is => 'rw', isa => 'Str',    default => q{});
has 'restraints'     => (is => 'rw', isa => 'Str',    default => q{});
has 'ndata'          => (is => 'rw', isa =>  Natural, default => 0);
has 'indeces'        => (is => 'rw', isa => 'Str',    default => q{});
has 'location'       => (is => 'rw', isa => 'Str',    default => q{});
has 'fit_performed'  => (is => 'rw', isa => 'Bool',   default => 0);
has 'ignore_errors'  => (is => 'rw', isa => 'Bool',   default => 0);
has 'stop'           => (is => 'rw', isa => 'Bool',   default => 0);
has 'troubletext'    => (is => 'rw', isa => 'Str',    default => q{});

## -------- array attributes
has 'gds' => (
	      metaclass => 'Collection::Array',
	      is        => 'rw',
	      isa       => 'ArrayRef',
	      default   => sub { [] },
	      provides  => {
			    'push'    => 'push_gds',
			    'pop'     => 'pop_gds',
			    'shift'   => 'shift_gds',
			    'unshift' => 'unshift_gds',
			    'clear'   => 'clear_gds',
			   }
	     );

has 'data' => (
	       metaclass => 'Collection::Array',
	       is        => 'rw',
	       isa       => 'ArrayRef',
	       default   => sub { [] },
	       provides  => {
			     'push'    => 'push_data',
			     'pop'     => 'pop_data',
			     'shift'   => 'shift_data',
			     'unshift' => 'unshift_data',
			     'clear'   => 'clear_data',
			    }
	      );

has 'paths' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_paths',
			      'pop'     => 'pop_paths',
			      'shift'   => 'shift_paths',
			      'unshift' => 'unshift_paths',
			      'clear'   => 'clear_paths',
			     }
	       );

has 'vpaths' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_vpaths',
			      'pop'     => 'pop_vpaths',
			      'shift'   => 'shift_vpaths',
			      'unshift' => 'unshift_vpaths',
			      'clear'   => 'clear_vpaths',
			     }
	       );

## -------- statistics
has 'happiness'         => (is => 'rw', isa =>  NonNeg,   default => 0);
has 'happiness_summary' => (is => 'rw', isa => 'Str',     default => q{});
has 'n_idp'             => (is => 'rw', isa =>  NonNeg,   default => 0);
has 'n_varys'           => (is => 'rw', isa =>  NaturalC, default => 0, coerce => 1);
has 'data_total'        => (is => 'rw', isa =>  NaturalC, default => 0, coerce => 1);
has 'epsilon_k'         => (is => 'rw', isa =>  NonNeg,   default => 0);
has 'epsilon_r'         => (is => 'rw', isa =>  NonNeg,   default => 0);
has 'r_factor'          => (is => 'rw', isa =>  NonNeg,   default => 0);
has 'chi_square'        => (is => 'rw', isa =>  NonNeg,   default => 0);
has 'chi_reduced'       => (is => 'rw', isa =>  NonNeg,   default => 0);

## deprecated and unused...
has 'fancyline'         => (is => 'rw', isa => 'Str',     default => q{});

has 'correlations' => (
		       metaclass => 'Collection::Hash',
		       is        => 'rw',
		       isa       => 'HashRef[HashRef]',
		       default   => sub { {} },
		       provides  => {
				     exists    => 'exists_in_correlations',
				     keys      => 'keys_in_correlations',
				     get       => 'get_correlations',
				     set       => 'set_correlations',
				    }
		      );

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Fit($self);
  $self->number($self->mo->currentfit);
};

#   sub set_all {
#     my ($self, $which, $rhash)  = @_;
#     return 0 if ($which !~ m{\A(?:data|gds|paths)\z}i);
#     return 0 if (ref($rhash) ne 'HASH');
#     my @list = @{ $component_of{ident $self}{$which} };
#     foreach my $obj (@list) {
#       $obj -> set($rhash);
#     };
#     return $self;
#   };

sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

override 'alldone' => sub {
  my ($self) = @_;
  $self->remove;
  rmtree $self->folder if (-d $self->folder);
};

override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  delete $all{gds};
  delete $all{data};
  delete $all{paths};
  delete $all{vpaths};
  return %all;
};


sub rm {
  my ($self) = @_;
  #print "removing ", $self->location, $/;
  rmtree($self->location);
};


## ------------------------------------------------------------
## sanity checks     see Demeter::Fit::Sanity
sub _verify_fit {
  my ($self) = @_;
  my $trouble_found = 0;
  my @gds   = @{ $self->gds };
  $self->add_trouble("gds"),   ++$trouble_found if ($#gds   == -1);
  my @data  = @{ $self->data };
  $self->add_trouble("data"),  ++$trouble_found if ($#data  == -1);
  my @paths = @{ $self->paths };
  $self->add_trouble("paths"), ++$trouble_found if ($#paths == -1);

  ## all these tests live in Demeter::Fit::Sanity, which is
  ## part of the base of this module

  ## 1. check that all data and feffNNNN.dat files exist
  $trouble_found += $self->S_data_files_exist;
  $trouble_found += $self->S_feff_files_exist;

  ## 2. check that all guesses are used in defs and pathparams
  $trouble_found += $self->S_defined_not_used;

  ## 3. check that defs and path paramers do not use undefined GDS parameters
  $trouble_found += $self->S_used_not_defined;

  ## 4. check that ++ -- // *** do not appear in math expression
  $trouble_found += $self->S_binary_ops;

  ## 5. check that all function() names are valid in math expressions
  $trouble_found += $self->S_function_names;

  ## 6. check that all data have unique group names and tags
  ## 7. check that all paths have unique group names
  $trouble_found += $self->S_unique_group_names;

  ## 8. check that all GDS have unique names
  $trouble_found += $self->S_gds_unique_names;

  ## 9. check that parens match
  $trouble_found += $self->S_parens_not_match;

  ## 10. check that data parameters are sensible
  $trouble_found += $self->S_data_parameters;

  ## 11. check number of guesses against Nidp
  $trouble_found += $self->S_nidp;

  ## 12. verify that Rmin is >= Rbkg for data imported as mu(E)
  $trouble_found += $self->S_rmin_rbkg;

  ## 13. verify that Reffs of all paths are within some margin of rmax
  $trouble_found += $self->S_reff_rmax;

  ## 14. check that Ifeffit's hard wired limits are not exceeded
  $trouble_found += $self->S_exceed_ifeffit_limits;

  ## 15. check that parameters do not have program variable names
  $trouble_found += $self->S_program_var_names;

  ## 16. check that all Path objects have either a ScatteringPath or a folder/file defined
  $trouble_found += $self->S_path_calculation_exists;

  ## 17. check that there are no unresolved merge parameetrs
  $trouble_found += $self->S_notice_merge;

  ## 18. check that no more than one path is flagged as the default path
  $trouble_found += $self->S_default_path;

  ## 18. check that GDS math expressions do not have loops or cycles
  $trouble_found += $self->S_cycle_loop;

  return $trouble_found;
};


## ------------------------------------------------------------
## fit and ff2chi

sub pre_fit {
  my ($self) = @_;
  ## reset use attribute (in case this fit involved local parameters)
  ## and clear all trouble attributes
  foreach my $gds (@{ $self->gds }) {
    $gds -> Use(1);
    $gds -> trouble(q{});
  };
  foreach my $d (@{ $self->data }) {
    $d -> fitting(0);
    $d -> trouble(q{});
  };
  foreach my $p (@{ $self->paths }) {
    $p -> _update('path') if (ref($p) =~ m{FSPath});
    $p -> trouble(q{});
    #print $/;
    #print $p->s02, $/;
    #print $p->e0, $/;
    #print $p->delr, $/;
    #print $p->sigma2, $/;
  };
  $self -> trouble(q{});
  $self -> troubletext(q{});
  return $self->template("fit", "prep_fit");
};

sub fit {
  my ($self) = @_;
  $self->stop(0);

  $self->start_spinner("Demeter is performing a fit") if ($self->mo->ui eq 'screen');
  my $prefit = $self->pre_fit;
  $self->number($self->mo->currentfit);

  my $trouble_found = $self->_verify_fit;
  if ($trouble_found) {
    $self->stop(1);
    my $text = $self->trouble_report;
    carp($text);
    $self->troubletext($text);
    if (not $self->ignore_errors) {
      if ($self->mo->ui eq 'Wx') {
	return "This fit has unrecoverable errors";
      } else {
	croak("This fit has unrecoverable errors");
      };
    };
  };
  return "Tilt!" if $self->stop;
  $self->dispose($prefit);

  $self->mo->fit($self);
  $self->mo->pathindex(1);
  foreach my $p (@{ $self->paths }) {
    $self->dispose("set path_index = " . $p->Index) if ($p->default_path);
  };
  my $command = q{};

  foreach my $type (qw(guess lguess set def restrain)) {
    $command .= $self->_gds_commands($type);
  };

  ## get a list of all data sets included in the fit
  my @datasets = @{ $self->data };
  my $ndata = $#datasets + 1;
  my $ipath = 0;
  my $count = 0;
  my $str = q{};
  $self->name("fit to " . join(", ", map {$_->name} @datasets)) if not $self->name;
  $self->description("fit to " . join(", ", map {$_->name} @datasets)) if not $self->description;

  ## munge parameters and path parameters to deal with lguess
  $command .= $self->_local_parameters;

  my $restraints_string = q{};
  foreach my $gds (@{ $self->gds }) {
    if (($gds->gds eq 'restrain') and ($gds->Use)) {
      #$restraints_string .= "restraint=%s, ", $gds->name;
      my $this = $gds->template("fit", "restraint");
      chomp($this);
      $restraints_string .= $this;
    };
  };
  if ($restraints_string) {
    $restraints_string = substr($restraints_string, 0, -2);
    $restraints_string = wrap("", "       ", $restraints_string);
  };
  $self -> restraints($restraints_string);
  $self -> ndata($ndata);

  foreach my $data (@datasets) {
    next if not $data->fit_include;
    ++$count;
    $data -> set(fitting=>1, fit_data=>$count);

    ## read the data
    $data -> _update('fft');
    $command .= "\n";

    ## define all the paths for this data set
    my $group = $data->group;
    my @indexstring = ();
    my $iii=1;
    foreach my $p (@{ $self->paths }) {
      next if not defined($p);
      next if ($p->data ne $data);
      next if not $p->include;
      $p->_update_from_ScatteringPath if $p->sp;
      ++$ipath;

      my $i = $p->mo->pathindex;
      $p->Index($i);
      $p->mo->pathindex(++$i);

      my $lab = $p->name;
      ($lab = "path $ipath") if ($lab =~ m{\A(?:\s*|path\s+\d+)\z});
      $p->set(name=>$lab);
      $p->rewrite_cv;
      $command .= $p->_path_command(0);
      push @indexstring, $p->Index;
    };
    $command .= "\n";

    $command .= $data->template("fit", "next") if ($count > 1);
    $self -> indeces(_normalize_paths(\@indexstring));
    if ($data->fit_data lt $self->ndata) {
      $command .= $data->template("fit", "fit");
    } else {
      $command .= $data->template("fit", "endfit");
    };

    $self -> restraints(q{}) if ($count == 1);
    $data -> fitsum('fit');
  };

  ## write out afters
  $command .= $self->_gds_commands('after');

  ## make residual and background arrays
  foreach my $data (@datasets) {
    $command .= $data->template("fit", "residual");
    if ($data->fit_do_bkg) {
      $command .= $data->template("fit", "background");
    };
  };
  $self->dispose($command);
  $self->evaluate;

  ## set happiness statistics
  my @joy = $self->get_happiness;
  $self->happiness( $joy[0] || 0 );
  $self->happiness_summary( $joy[1] || q{} );

  foreach my $g (@ {$self->gds}) {
    $g->autoannotate;
  };

  $self->fitted(1);
  $self->mo->fit(q{});
  $self->mo->increment_fit;

  ## prep data for plotting
  foreach my $data (@datasets) {
    $data->update_fft(1);
  };

  $self->stop_spinner if ($self->mo->ui eq 'screen');

  return $self;
};
alias feffit => 'fit';

sub ff2chi {
  my ($self, $data) = @_;
  $self->start_spinner("Demeter is doing a summation of paths") if ($self->mo->ui eq 'screen');
  my $prefit = $self->pre_fit;

  my @alldata = @{ $self->data };
  $data ||= $alldata[0];

  $data -> fitting(1);

  my $trouble_found = $self->_verify_fit;
  if ($trouble_found) {
    $self->stop(1);
    my $text = $self->trouble_report;
    carp($text);
    $self->troubletext($text);
    if (not $self->ignore_errors) {
      if ($self->mo->ui eq 'Wx') {
	return "This summation has unrecoverable errors";
      } else {
	croak("This summation has unrecoverable errors");
      };
    };
  };
  return "Tilt!" if $self->stop;
  $self->dispose($prefit);


  $self->mo->fit($self);
  my $command = q{};
  foreach my $type (qw(guess set def restrain)) {
    $command .= $self->_gds_commands($type);
  };
  ## munge parameters and path parameters to deal with lguess
  $command .= $self->_local_parameters;

  ## read the data
  $command .= $data -> _read_data_command("chi");
  $command .= "\n";

  my $ipath = 0;
  my $count = 0;
  my @indexstring = ();
  foreach my $p (@{ $self->paths }) {
    next if not defined($p);
    next if ($p->data ne $data);
    next if not $p->include;
    $p->_update_from_ScatteringPath if $p->get("sp");
    ++$ipath;
    my $lab = $p->name;
    ($lab = "path $ipath") if ($lab =~ m{\A(?:\s*|path\s+\d+)\z});
    $p->set(name=>$lab);
    $p->rewrite_cv;
    $command .= $p->_path_command(0);
    push @indexstring, $p->Index;
  };

  $command .= "\n";
  $command .= $data->hashes . " make sum of paths for data \"$data\"\n";
  $self -> indeces(_normalize_paths(\@indexstring));
  $command .= $data->template("fit", "sum");

  $command .= $data->hashes . " make residual array\n";
  $command .= $data->template("fit", "residual");

  $data->fitsum('sum');
  $self->dispose($command);
  $self->evaluate;
  $self->happiness(0);
  $self->happiness_summary(q{});

  $self->mo->fit(q{});

  $self->stop_spinner if ($self->mo->ui eq 'screen');

  return $self;
};
alias sum => 'ff2chi';


sub trouble_report {
  my ($fit) = @_;
  my $text = q{};
  $Text::Wrap::columns = 60;
  foreach my $obj ($fit, @{ $fit->data }, @{ $fit->gds }, @{ $fit->paths }) {
    next if not $obj->trouble;
    my $which = ref($obj);
    $which =~ s{Demeter::}{};
    foreach my $t (split(/\|/, $obj->trouble)) {
      my $pathfile = q{};
      if ($which =~ m{Path}) {
	$pathfile = ($obj->sp) ? $obj->sp->intrpline : File::Spec->catfile($obj->folder, $obj->file);
	$pathfile = '(' . $pathfile . ')';
      };
      $text .= sprintf("%s: %s %s\n%s\n\n", uc($which), $obj->name, $pathfile, wrap("     ", "     ", $obj->translate_trouble($t)));
      ##$text .= sprintf("%s: %s\t(%s)\n%s\n\n", $which, $obj->name, $t, wrap("     ", "     ", $obj->translate_trouble($t)));
    };
  };
  return $text;
};

sub _gds_commands {
  my ($self, $type) = @_;
  my $string = q{};

  foreach my $gds (@{ $self->gds }) {
    next unless ($gds->gds eq lc($type));
    next if (not $gds->Use);
    $string .= $gds -> write_gds;
  };
  $string = "\n" . $self->hashes . " $type parameters:\n" . $string if $string;

  return $string;
};

sub _local_parameters {
  my ($self) = @_;
  my $string = q{};
  my %created = ();

  ## list of lguesses
  my @local_list = grep {$_->gds eq 'lguess'} (@{ $self->gds });

  ## regex that matches all the lguesses
  my $local_regex = join("|", map {$_->name} @local_list);
  return q{} if (not $local_regex);

  ## need to fetch a complete list of lguess and the def, after,
  ## restrain that depend upon lguess by digging into the math
  ## expression dependencies
  my $continue = 1;
  while ($continue) {
    my $count = 0;
    my @llist = ();
    foreach my $gds (@{ $self->gds }) {
      next if ($gds->name =~ m{\b($local_regex)\b}i);
      next if ($gds->gds =~ m{(?:skip|merge)});
      if (($gds->mathexp =~ m{\b($local_regex)\b}i) and
	  (none {$gds->name eq $_->name} @local_list)) {
	push @llist, $gds;
	++$count;
      };
    };
    push @local_list, @llist;
    $local_regex = join("|", map {$_->name} @local_list);
    $continue = $count;
  };

  ## need to unguess any locally dependent guesses
  my $setguess_header_written = 0;
  foreach my $p (@local_list) {
    next if ($p->gds ne 'guess');
    if (not $setguess_header_written) {
      $string .= "\n" . $self->hashes . " unguessing locally dependent guess parameters:\n";
      $setguess_header_written = 1;
    };
    $p->Use(0); # so it doesn't get reported in the log file
    my $this = $p->name;
    $string .= "set $this = $this\n";
  };

  ## need to make a mapping of param names back to their objects
  my @keys = map {$_->name} @local_list;
  my %type = zip(@keys, @local_list);

  ## loop through all the data to find and rewrite math expressions
  ## that depend on lguesses
  foreach my $data (@{$self->data}) {
    my $tag = $data->cv || $data->tag;
    $tag   =~ s{\.}{_}g;
    $string .= "\n" . $self->hashes . " local guess and def parameters for " . $data->name . ":\n";

    foreach my $p (@{ $self->paths }) {
      next if not defined($p);
      next if ($p->data->group ne $data->group);
      next if not $p->include;
      foreach my $pp (qw(e0 ei sigma2 s02 delr third fourth dphase)) {
	my $me = $p->$pp;
	if ($me =~ m{\b($local_regex)\b}i) {
	  my $global = $1;
	  my $local = join("_", $global, $tag);

	  ## correct this path parameter's math expression
	  $me =~ s/\b$global\b/$local/g;
	  $p->$pp($me);

	  ## define a local guess and rewrite local guesses if not
	  ## already defined
	  if (not $created{$local}) {
	    my ($this_me, $this_type) = ($global, 'guess');
	    if ($type{$global}->gds eq 'def') {
	      $this_type = "def";
	      ($this_me = $type{$global}->mathexp) =~ s{\b($local_regex)\b}{$1_$tag}g;
	    };
	    my $new_gds = Demeter::GDS->new(gds     => $this_type,
					    name    => $local,
					    mathexp => $this_me);
	    $self->push_gds($new_gds);
	    $string .= $new_gds -> write_gds;
	    ++$created{$local};
	  };
	};
      };
    };

    ## rewrite remaining defs and all afters
    foreach my $ldef (@local_list) {
      next if ($ldef->gds !~ m{(?:after|def)});
      my $global = $ldef->name;
      my $local = join("_", $global, $tag);
      my $me = $ldef->mathexp;
      $me =~ s{\b($local_regex)\b}{$1_$tag}g;
      next if ($created{$local});
      my $new_gds = Demeter::GDS->new(gds     => $ldef->gds,
				      name    => $local,
				      mathexp => $me);
      $self->push_gds($new_gds);
      $string .= $new_gds -> write_gds  if ($ldef->gds eq 'def');
      $ldef->Use(0) if ($ldef->gds eq 'after');
      ++$created{$local};
    };

    ## next rewrite restraints
    my $restraint_header_written = 0;
    foreach my $lres (@local_list) {
      next if ($lres->gds ne 'restrain');
      if (not $restraint_header_written) {
	$string .= "\n" . $self->hashes . " local restraints " . $data->name . ":\n";
	$restraint_header_written = 1;
      };
      my $global = $lres->name;
      my $local = join("_", $global, $tag);
      my $me = $lres->mathexp;
      $me =~ s{\b($local_regex)\b}{$1_$tag}g;
      next if ($created{$local});
      my $new_gds = Demeter::GDS->new(gds     => 'restrain',
				      name    => $local,
				      mathexp => $me);
      $self->push_gds($new_gds);
      $lres -> Use(0);
      $string .= $new_gds -> write_gds;
      ++$created{$local};
    };
  };

  ## finally set expandsto attribute of each lguess
  foreach my $l (@local_list) {
    my $this = $l->name;
    my @these = ();
    foreach my $c (sort keys %created) {
      push(@these, $c) if ($c =~ m{\A$this});
    };
    $l -> expandsto(join(", ", @these));
  };
  return $string;
};


# swiped from the old Ifeffit::IO:
#   change (3,1,14,5,15,2,13,7,8,6,12) to "1-3,5-8,12-15"
sub _normalize_paths {
  my @tmplist;                  # expand 'X-Y'
  map { push @tmplist, ($_ =~ /(\d+)-(\d+)/) ? $1 .. $2 : $_ } @{$_[0]};
  my @list   = grep /\d+/, @tmplist; # weed out non-integers
  @list      = sort {$a<=>$b} @list; # sort 'em
  my $this   = shift(@list);
  my $string = $this;
  my ($prev, $concat) = ('', '');
  while (@list) {
    $prev   = $this;
    $this      = shift(@list);
    if ($this == $prev+1) {
      $concat  = "-";
    } else {
      $concat  = ",";
      $string .= join("", "-", $prev, $concat, $this);
    };
    $prev = $this;
  };
  ($concat eq "-") and $string .= $concat . $this;
  $string =~ s{(\d+)-(\1)\b}{$1}g;
  return $string || q{};
};


sub evaluate {
  my ($self) = @_;

  ## retrieve bestfit and errors for gds params, handle annotation
  foreach my $gds (@{ $self->gds }) {
    $gds->evaluate;
  };

  ## evaluate all path parameter math expressions
  foreach my $path (@{ $self->paths }) {
    next if not defined($path);
    $path->fetch;
    $path->update_path(1);
  };

  ## get fit and data set statistics (store in fit and data objects respectively)
  $self->fetch_statistics;

  ## get correlations (store in fit object?)
  $self->fetch_correlations;

  ## set properties
  $self->set(time_of_fit=>$self->now, fit_performed=>1);
  return $self;
};

my @keys = qw(name description fom time_of_fit fitenvironment interface prepared_by contact);
my @vals = ('Name', 'Description', 'Figure of merit', 'Time of fit', 'Environment', 'Interface', 'Prepared by', 'Contact');
my %properties = zip(@keys, @vals);

sub properties_header {
  my ($self, $is_summary) = @_;
  my $string = "\n";
  foreach my $k (@keys) {
    next if ($is_summary and ($k !~ m{name|description|fom}));
    if ($k eq 'description') {
      my @lines = ($self->$k) ? split($/, $self->$k) : (q{});
      $string .= sprintf " %-15s : %s\n", $properties{$k}, shift @lines;
      $string .= (sprintf " %-15s   %s\n", '        ...', $_) foreach @lines;
    } else {
      $string .= sprintf " %-15s : %s\n", $properties{$k}, $self->$k;
    };
  };
  return $string;
};

sub summary {
  my ($self) = @_;
  my $text = q{};
  $text .= $self->template("report", "properties_summary");
  $text .= $self->template("report", "statistics"); #statistics_report;
  $text .= $self->gds_report;
  $text .= $self->template("report", "fancyline");
  return $text;
};

sub logfile {
  my ($self, $fname, $header, $footer) = @_;
  $header ||= $self->get('header') || q{};
  $footer ||= $self->get('footer') || q{};
  open my $LOG, ">$fname";
  print $LOG $self->logtext($header, $footer);
  close $LOG;
  return $self;
};
sub logtext {
  my ($self, $header, $footer) = @_;
  $header ||= q{};
  $footer ||= q{};
  $self -> set(header=>$header, footer=>$footer);
  ($header .= "\n") if ($header !~ m{\n\z});
  my $text = q{};

  $text .= $header;
  $text .= $self->template("report", "properties"); #properties_header;
  $text .= $self->template("report", "fancyline");

  $text .= $self->template("report", "statistics"); #statistics_report;
  $text .= $self->template("report", "happiness");  #happiness_report;
  $text .= $self->gds_report;
  $text .= $self->correl_report(); # arg is cormin

  foreach my $data (@{ $self->data }) {
    next if (not $data->fitting);
    if (lc($data->fit_space) eq "r") {
      $data->_update("bft");
      $data->part_fft("fit") if (lc($data->fitsum) eq 'sum');
    };
    if (lc($data->fit_space) eq "q") {
      $data->_update("bft");
      $data->part_fft("fit") if (lc($data->fitsum) eq 'sum');
      $data->part_bft("fit") if (lc($data->fitsum) eq 'sum');
    };
    $text .= $data->fit_parameter_report($#{ $self->data }, $self->fit_performed);
    my @all_paths = @{ $self->paths };
    if (@all_paths) {
      ## figure out how wide the column of path labels should be
      my $length = max( map { length($_->name) if ($_->data eq $data) } @all_paths ) + 1;
      $text .= $all_paths[0]->row_main_label($length);
      foreach my $path (@all_paths) {
	next if not defined($path);
	next if ($path->data ne $data);
	next if not $path->include;
	$text .= $path->row_main($length);
      };
      $text .= $/;
      $text .= $all_paths[0]->row_second_label($length);
      foreach my $path (@all_paths) {
	next if not defined($path);
	next if ($path->data ne $data);
	next if not $path->include;
	$text .= $path->row_second($length);
      };
    };
  };

  $text .= $self->template("report", "fancyline");
  ($footer .= "\n") if ($footer !~ m{\n\z});
  $text .= $footer;

  return $text;
};


sub gds_report {
  my ($self) = @_;
  my $text = q{};
  foreach my $type (qw(guess lguess set def restrain after)) {
    my $tt = $type;
    my $head = "$type parameters:\n";
    my $string = q{};
    foreach my $gds (@{ $self->gds} ) {
## 	## need to not lose guesses that get flagged as local by
## 	## virtue of a math expression dependence
## 	if ( ($type eq 'lguess') and ($gds->type) and (not $gds->Use) ) {
## 	  $string .= "  " . $gds->report(0);
## 	  next;
## 	};
      next if ($gds->gds ne $type);
      next if (not $gds->Use);
      $string .= "  " . $gds->report(0);
    };
    if ($string) {
      $text.= $head . $string . "\n";
    };
  };
  return $text;
};



sub fetch_statistics {
  my ($self) = @_;

  my $save = Ifeffit::get_scalar("\&screen_echo");
  ## not using dispose so that the get_echo lines gets captured here
  ## rather than in the dispose method
  Ifeffit::ifeffit("\&screen_echo = 0\n");
  Ifeffit::ifeffit("show $STAT_TEXT\n");

  my $lines = Ifeffit::get_scalar('&echo_lines');
  if (not $lines) {
    $self->dispose("\&screen_echo = $save\n") if $save;
  };

  my $fit_stats_regexp = Regexp::Assemble->new()->add(@Demeter::StrTypes::stat_list)->re;
  foreach (1 .. $lines) {
    my $response = Ifeffit::get_echo()."\n";
    if ($response =~ m{($fit_stats_regexp)
		       \s*=\s*
		       ($NUMBER)
		    }x) {
      $self->$1($2);
    };
  };

  ## in the case of a sum, the stats cannot be obtained via get_echo
  if ($self->n_idp == 0) {
    my $nidp = 0;
    foreach my $d (@ {$self->data} ) {
      $nidp += $d->nidp;
    };
    $self->n_idp(sprintf("%.3f", $nidp));
  };
  if ($self->n_varys == 0) {
    my $nv = 0;
    foreach my $g (@ {$self->gds} ) {
      ++$nv if ($g->gds eq 'guess');
    };
    $self->n_varys($nv);
  };
  if ($self->data_total == 0) {
    $self->data_total($#{ $self->data } + 1);
  };
  if ($self->epsilon_k == 0) {
    my $which = q{};
    foreach my $d (@ {$self->data} ) {
      ($which = $d) if ($d->fitting);
    };
    $self->epsilon_k($which->epsk);
    $self->epsilon_r($which->epsr);
  };

  $self->dispose("\&screen_echo = $save\n") if $save;
  return 0;
};


# sub statistics_report {
#   my ($self) = @_;
#   my %things = ("n_idp"       => "Independent points          ",
# 		"n_varys"     => "Number of variables         ",
# 		"chi_square"  => "Chi-square                  ",
# 		"chi_reduced" => "Reduced chi-square          ",
# 		"r_factor"    => "R-factor                    ",
# 		"epsilon_k"   => "Measurement uncertainty (k) ",
# 		"epsilon_r"   => "Measurement uncertainty (R) ",
# 		"data_total"  => "Number of data sets         ",
# 	       );
#   my $string = q{};
#   foreach my $stat (split(" ", $STAT_TEXT)) {
#     $string .= $self->template("report", "statistics", {name=>$things{$stat}, stat=>$stat});
#     ##$string .= sprintf("%s : %s\n", $things{$stat}, $self->$stat||0);
#   };
#   return $string;
# };

sub happiness_report {
  my ($self) = @_;
  my $string = sprintf("Happiness = %.5f / 100\t\tcolor = %s\n", $self->happiness, $self->color);
  foreach my $line (split "\n", $self->happiness_summary) {
    $string .= "   $line\n";
  };
  $string .= "***** Note: happiness is a semantic parameter and should *****\n";
  $string .= "*****    NEVER be reported in a publication -- NEVER!    *****\n";
  return $string;
};


## handle correlations: store every correlation as attributes of the
## object.  provide a variety of convenience functions for accessing
## this information as relatively flat data

######## FIX ME!!! ####################################################################
## ack!! the echo_lines are not available if something else captures Ifeffit's feedback
## this happens if set_mode(screen=>1) is turned on or in Artemis's buffer
######## FIX ME!!! ####################################################################

sub fetch_correlations {
  my ($self) = @_;

  my @save = (Ifeffit::get_scalar("\&screen_echo"),
	      $self->get_mode("screen"),
	      $self->get_mode("plotscreen"),
	      $self->get_mode("feedback"));
  Ifeffit::ifeffit("\&screen_echo = 0\n");
  $self->set_mode(screen=>0, plotscreen=>0, feedback=>q{});
  my %correlations_of;
  my $d = $self -> data -> [0];
  my $correl_lines;
  $self->set_mode(buffer=>\$correl_lines);
  $self->dispose($d->template("fit", "correl"));
  #my $correl_text = Demeter->get_mode("echo");
  my $lines = Ifeffit::get_scalar('&echo_lines');
  my @correl_text = ();
  foreach my $l (1 .. $lines) {
    my $response = Ifeffit::get_echo();
    if ($response =~ m{\A\s*correl}) {
      push @correl_text, $response;
    };
  };
  Ifeffit::ifeffit("\&screen_echo = $save[0]\n");
  $self->set_mode(screen=>$save[1], plotscreen=>$save[2], feedback=>$save[3]);

  my @gds = map {lc($_->name)} @{ $self->gds };
  my $regex = Regexp::Assemble->new()->add(@gds)->re;

  foreach my $line (@correl_text) {
    if ($line =~ m{correl_
		   ($regex)_   # first variable name followed by underscore
		   ($regex)    # second variable name
		   \s+=\s+     # space equals space
		   ($NUMBER)   # a number
		}xi) {
      my ($x, $y, $correl) = ($1, $2, $3);
      #print join(" ", $x, $y, $correl), $/;
      $correlations_of{$x}{$y} = $correl;
    };
    if ($line =~ m{correl_
		   (bkg\d\d_\d\d)_   # bkg parameter followed by an underscore
		   ($regex)	       # variable name
		   \s+=\s+	       # space equals space
		   ($NUMBER)	       # a number
		}xi) {
      my ($x, $y, $correl) = ($1, $2, $3);
      #print join(" ", $x, $y, $correl), $/;
      $correlations_of{$x}{$y} = $correl;
    };
    if ($self->co->default("fit", "bkg_corr")) {
      if ($line =~ m{correl_
		     (bkg\d\d_\d\d)_ # bkg parameter followed by an underscore
		     (bkg\d\d_\d\d)  # another bkg parameter
		     \s+=\s+	       # space equals space
		     ($NUMBER)       # a number
		  }xi) {
	my ($x, $y, $correl) = ($1, $2, $3);
	#print join(" ", $x, $y, $correl), $/;
	$correlations_of{$x}{$y} = $correl;
      };
    };
  };

#  use Data::Dumper;
#  print Data::Dumper->Dump([\%correlations_of]);

  foreach my $k (keys %correlations_of) {
    $self->set_correlations($k, $correlations_of{$k});
  };
  return 0;
};

sub correl {
  my ($self, $x, $y) = @_;
  my $value = ($self->exists_in_correlations($x)) ? $self->get_correlations($x)->{$y}
            : ($self->exists_in_correlations($y)) ? $self->get_correlations($y)->{$x}
	    : 0;
  return $value;
};
sub all_correl {
  my ($self) = @_;
  my %all = ();
  foreach my $x ($self->keys_in_correlations) {
    foreach my $y (keys %{ $self->get_correlations($x) } ) {
      my $key = join("|", $x, $y);
      $all{$key} = $self->get_correlations($x)->{$y};
    };
  };
  return %all;
};
sub correl_report {
  my ($self, $cormin) = @_;
  my $string = "Correlations between variables:\n";
  $cormin ||= $self->cormin;
  my %all = $self->all_correl;
  my @order = sort {abs($all{$b}) <=> abs($all{$a})} (keys %all);
  foreach my $k (@order) {
    last if (abs($all{$k}) < $cormin);
    my ($x, $y) = split(/\|/, $k);
    $string .= $self->template("report", "correl", {p1=>$x, p2=>$y, correl=>$all{$k}});
  };
  $string .= "All other correlations below $cormin\n" if $cormin;
  return $string;
};

sub fetch_gds {
  my ($self, $which) = @_;
  $which = lc($which);
  foreach my $g (@{$self->gds}) {
    return $g if ($which eq lc($g->name));
  };
  return 0;
};

sub has_data {
  my ($self, $which) = @_;
  foreach my $g (@{$self->data}) {
    return 1 if ($which->group eq $g->group);
  };
  return 0;
};


## ------------------------------------------------------------
## Serialization and deserialization of the Fit object

override 'serialization' => sub {
  my ($self) = @_;
  my @gds    = @{ $self->gds   };
  my @data   = @{ $self->data  };
  my @paths  = @{ $self->paths };
  my @vpaths = @{ $self->vpaths };

  my @gdsgroups    = map { $_->group } @gds;
  my @datagroups   = map { $_->group } @data;
  my @pathsgroups  = map { $_->group } grep {defined $_} @paths;
  my @feffgroups   = map { $_ ?  $_->group : q{} } map {$_ -> parent} grep {defined $_} @paths;
  my @vpathsgroups = map { $_->group } grep {defined $_} @vpaths;
  @feffgroups = uniq @feffgroups;

  my $text = "# gdsgroups, datagroups, pathsgroups, feffgroups, vpathsgroups\n";
  $text .= YAML::Tiny::Dump(\@gdsgroups, \@datagroups, \@pathsgroups, \@feffgroups, \@vpathsgroups);
  $text .= "\n";
  my %hash = $self->all;
  $text .= YAML::Tiny::Dump(\%hash);
  return $text;
};

override 'serialize' => sub {
  my ($self, @args) = @_;
  my %args = @args;		# coerce args into a hash
  $args{tree}   ||= File::Spec->catfile($self->project_folder("raw_demeter"), 'fit');
  $args{folder} ||= $self->group;
  $args{file}   ||= $args{project};
  ($args{nozip} = 1) if not $args{file};
  $args{copyfeff} ||= 1;

  my @gds    = @{ $self->gds   };
  my @data   = @{ $self->data  };
  my @paths  = @{ $self->paths };
  my @vpaths = @{ $self->vpaths };

  my @gdsgroups    = map { $_->group } @gds;
  my @datagroups   = map { $_->group } @data;
  my @pathsgroups  = map { $_->group } grep {defined $_} @paths;
  my @feffgroups   = map { $_ ?  $_->group : q{} } map {$_ -> parent} grep {defined $_} @paths;
  my @vpathsgroups = map { $_->group } grep {defined $_} @vpaths;
  @feffgroups = uniq @feffgroups;

  unlink ($args{file}) if ($args{file} and (-e $args{file}));

  $self->folder(File::Spec->catfile($args{tree}, $args{folder}));
  mkpath($self->folder);

  ## -------- save a yaml containing the structure of the fit
  my $structure = File::Spec->catfile($self->folder, "structure.yaml");
  open my $STRUCTURE, ">$structure";
  print $STRUCTURE YAML::Tiny::Dump(\@gdsgroups, \@datagroups, \@pathsgroups, \@feffgroups, \@vpathsgroups);
  close $STRUCTURE;

  ## -------- save a yaml containing all GDS parameters
  my $gdsfile =  File::Spec->catfile($self->folder, "gds.yaml");
  open my $gfile, ">$gdsfile";
  foreach my $p (@gds) {
    print $gfile $p->serialization;
  };
  close $gfile;

  ## -------- save a yaml for each data file
  foreach my $d (@data) {
    my $dd = $d->group;
    $d -> file($NULLFILE) if $d->prjrecord;
    my $datafile =  File::Spec->catfile($self->folder, "$dd.yaml");
    $d -> serialization($datafile);
    $d -> serialize($datafile);
  };

  ## -------- save a yaml containing the paths
  my $pathsfile =  File::Spec->catfile($self->folder, "paths.yaml");
  my %feffs = ();
  open my $PATHS, ">$pathsfile";
  foreach my $p (@paths) {
    next if not defined($p);
    print $PATHS $p->serialization;
    if ($p->sp) {	# this path used a ScatteringPath object
      my $this = sprintf("%s", $p->parent);
      $feffs{$this} = $p->get("parent");
    } else {			# this path imported a feffNNNN.dat file
      1;
    };
  };
  close $PATHS;

  ## -------- save a yaml containing the vpaths
  my $vpathsfile =  File::Spec->catfile($self->folder, "vpaths.yaml");
  open my $VPATHS, ">$vpathsfile";
  foreach my $vp (@vpaths) {
    next if not defined($vp);
    print $VPATHS $vp->serialization;
  };
  close $VPATHS;

  ## -------- save yamls and phase.bin for the feff calculations (turn
  ##          this off in Artemis, where interaction with feff files
  ##          is handled somewhat differently)
  if ($args{copyfeff}) {
    foreach my $f (values %feffs) {
      my $ff = $f->group;
      my $feffyaml = File::Spec->catfile($self->folder, $ff.".yaml");
      $f->serialize($feffyaml, 1);
      my $feff_from  = File::Spec->catfile($f->get("workspace"), "original_feff.inp");
      my $feff_to    = File::Spec->catfile($self->folder, $ff.".inp");
      copy($feff_from,  $feff_to);
      my $phase_from = File::Spec->catfile($f->get("workspace"), "phase.bin");
      my $phase_to   = File::Spec->catfile($self->folder, $ff.".bin");
      copy($phase_from, $phase_to);
    };
  };

  ## -------- save a yaml containing the fit properties
  my @properties = grep {$_ !~ m{\A(?:gds|data|paths|vpaths|project|folder|rate|thingy|progress)\z}} $self->meta->get_attribute_list;
  push @properties, 'name';
  my @vals = $self->get(@properties);
  my %props = zip(@properties, @vals);
  my $propsfile =  File::Spec->catfile($self->folder, "fit.yaml");
  open my $PROPS, ">$propsfile";
  print $PROPS YAML::Tiny::Dump(\%props);
  close $PROPS;

  ## -------- write fit and log files to the folder
  foreach my $d (@data) {
    my $dd = $d->group;
    $d -> _update("bft");
    $d -> save("fit", File::Spec->catfile($self->folder, $dd.".fit"));
  };
  $self -> logfile(File::Spec->catfile($self->folder, "log"), $self->header, $self->footer);

  ## -------- finally save a yaml containing the Plot object
  my $plotfile =  File::Spec->catfile($self->folder, "plot.yaml");
  open my $PLOT, ">$plotfile";
  print $PLOT $self->po->serialization;
  close $PLOT;


  if ($args{file}) {
    my $readme = File::Spec->catfile($self->share_folder, "Readme.fit_serialization");
    my $target = File::Spec->catfile($self->folder, "Readme");
    copy($readme, $target);
    open(my $touch, '>', File::Spec->catfile($self->folder, "FIT.SERIALIZATION"));
    close $touch;
    if (not $args{nozip}) {
      $self->zip_project($self->folder, $args{file});
      rmtree($self->folder);
    };
  };

  return $self;
};

override 'deserialize' => sub {
  my ($self, @args) = @_;
  my %args = @args;
  $args{plot}       ||= 0;
  $args{file}       ||= 0;
  $args{folder}     ||= 0;
  $args{regenerate} ||= 0;

  my (%datae, %sps,  %parents, $dpj, $zip, $project_folder);

  if ($args{file}) {
    $dpj = File::Spec->rel2abs($args{file});
    $self->start_spinner("Demeter is unpacking \"$args{file}\"") if ($self->mo->ui eq 'screen');
    my $folder = $self->project_folder("raw_demeter");

    $zip = Archive::Zip->new();
    carp("Error reading project file ".$args{file}."\n\n"), return 1 unless ($zip->read($dpj) == AZ_OK);
  };

  my $structure = ($args{file}) ? $zip->contents('structure.yaml')
    : $self->slurp(File::Spec->catfile($args{folder}, 'structure.yaml'));
  my ($r_gdsnames, $r_data, $r_paths, $r_feff) = YAML::Tiny::Load($structure);

  ## -------- import the data
  my @data = ();
  foreach my $d (@$r_data) {
    my $yaml = ($args{file}) ? $zip->contents("$d.yaml")
      : $self->slurp(File::Spec->catfile($args{folder}, "$d.yaml"));
    my ($r_attributes, $r_x, $r_y) = YAML::Tiny::Load($yaml);
    delete $r_attributes->{fit_pcpath};	   # correct an early
    delete $r_attributes->{fit_do_pcpath}; # design mistake...
    my @array = %$r_attributes;
    my $savecv = $self->mo->datacount;
    my $this = Demeter::Data -> new(@array);
    $this->cv($r_attributes->{cv}||0);
    $self->mo->datacount($savecv);
    $datae{$this->group} = $this;
    if ($this->datatype eq 'xmu') {
      Ifeffit::put_array($this->group.".energy", $r_x);
      Ifeffit::put_array($this->group.".xmu",    $r_y);
    } elsif  ($this->datatype eq 'chi') {
      Ifeffit::put_array($this->group.".k",      $r_x);
      Ifeffit::put_array($this->group.".chi",    $r_y);
    };
    $this -> set(update_data=>0, update_columns=>0);
    push @data, $this;
  };

  ## -------- import the gds
  my @gds = ();
  my $yaml = ($args{file}) ? $zip->contents("gds.yaml")
    : $self->slurp(File::Spec->catfile($args{folder}, "gds.yaml"));
  my @list = YAML::Tiny::Load($yaml);
  foreach (@list) {
    my @array = %{ $_ };
    my $this = Demeter::GDS->new(@array);
    push @gds, $this;
    my $command;
    if ($this->gds eq 'guess') {
      $command = sprintf "guess %s = %f\n", $this->name, $this->bestfit;
    } elsif ($this->gds =~ m{\A(?:def|after)}) {
      $command = sprintf "def %s = %s\n", $this->name, $this->mathexp;
    } elsif ($this->gds eq 'set') {
      $command = sprintf "set %s = %s\n", $this->name, $this->mathexp;
    };
    ## restrain, skip, after, (merge, penalty) should not be disposed at this time
    if ($this->gds =~ m{(?:guess|def|set)}) {
      $this->dispose($command);
    };
  };

  ## -------- import the feff calculations
  my @feff = ();
  if ($args{file}) {
    foreach my $f (@$r_feff) {
      my $this = Demeter::Feff->new(group=>$f);
      $parents{$this->group} = $this;
      my $yaml = ($args{file}) ? $zip->contents("$f.yaml")
	: $self->slurp(File::Spec->catfile($args{folder}, "$f.yaml"));
      if (defined $yaml) {
	my @refs = YAML::Tiny::Load($yaml);
	$this->read_yaml(\@refs);
	foreach my $s (@{ $this->pathlist }) {
	  $sps{$s->group} = $s
	};
	push @feff, $this;
      };
    };
  };

  ## -------- import the paths
  my @paths = ();
  $yaml = ($args{file}) ? $zip->contents("paths.yaml")
    : $self->slurp(File::Spec->catfile($args{folder}, "paths.yaml"));
  @list = YAML::Tiny::Load($yaml);
  foreach my $plotlike (@list) {
    my $dg = $plotlike->{datagroup};
    $plotlike->{data} = $datae{$dg};
    if (exists $plotlike->{absorber}) {  # this is an FSPath
      delete $plotlike->{$_} foreach qw(workspace Type weight string pathtype plottable);
    } elsif (exists $plotlike->{ipot}) { # this is an SSPath
      delete $plotlike->{$_} foreach qw(Type weight string pathtype plottable);
    } elsif (exists $plotlike->{nnnntext}) { # this is an FPath
      1;
    };
    my @array = %{ $plotlike };
    my $this;
    if (exists $plotlike->{ipot}) {          # this is an SSPath
      my $feff = $parents{$plotlike->{parentgroup}} || $data[0] -> mo -> fetch('Feff', $plotlike->{parentgroup});
      $this = Demeter::SSPath->new(parent=>$feff);
      $this -> set(@array);
      $this -> sp($this);
      #print $this, "  ", $this->sp, $/;
    } elsif (exists $plotlike->{nnnntext}) { # this is an FPath
      $this = Demeter::FPath->new();
      $this -> set(@array);
      $this -> sp($this);
      $this -> parentgroup($this->group);
      $this -> parent($this);
      $this -> workspace($this->stash_folder);
    } elsif (exists $plotlike->{absorber}) { # this is an FSPath
      my $feff = $parents{$plotlike->{parentgroup}} || $data[0] -> mo -> fetch('Feff', $plotlike->{parentgroup});
      $this = Demeter::FSPath->new();
      $this -> set(@array);
      my $where = Cwd::realpath(File::Spec->catfile($args{folder}, '..', '..', 'feff', basename($feff->workspace)));
      $this -> set(workspace=>$where, folder=>$where, parent=>$data[0] -> mo -> fetch('Feff', $plotlike->{parentgroup}));
      my $sp = $sps{$this->spgroup} || $data[0] -> mo -> fetch('ScatteringPath', $this->spgroup);
      $this -> sp($sp);
    } else {
      $this = Demeter::Path->new(@array);
      my $sp = $sps{$this->spgroup} || $data[0] -> mo -> fetch('ScatteringPath', $this->spgroup);
      $this -> sp($sp);
      #print $this, "  ", $this->sp, $/;
    };
    $this -> datagroup($dg);
    ## reconnect object relationships
    $this -> parent($parents{$this->parentgroup}) if (ref($this) !~ m{FPath});
    $this -> data($datae{$this->datagroup});
    push @paths, $this;
  };

  ## -------- import the vpaths
  my @vpaths = ();
  $yaml = ($args{file}) ? $zip->contents("vpaths.yaml")
    : $self->slurp(File::Spec->catfile($args{folder}, "vpaths.yaml"));
  if ($yaml) {
    @list = YAML::Tiny::Load($yaml);
    foreach my $vp (@list) {
      delete $vp->{$_} foreach qw(id update_path update_fft update_bft);
      my $dg = $vp->{datagroup};
      $vp->{data} = $datae{$dg};

      my @pathgroups = @{ $vp->{pathgroups} };

      my @array = %{ $vp };
      my $this = Demeter::VPath->new();
      $this -> set(@array);
      $this -> update_path(1);
      foreach my $pg (@pathgroups) {
	$this->push_paths($this -> mo -> fetch('Path', $pg));
      };
      push @vpaths, $this;
    };
  };

  if ($args{regenerate}) {
    my %mapping = ();
    foreach my $o (@gds, @data, @paths) {
      my $old = $o->group;
      my $new = $o->_get_group;
      $o->group($new);
      $mapping{$old} = $new;
      $mapping{$new} = $old;
    };
    ## need to fix group values inside yaml files also!!
    foreach my $d (@data) {
      move(File::Spec->catfile($args{folder}, $mapping{$d->group}.".fit" ), File::Spec->catfile($args{folder}, $d->group.".fit" ));
      move(File::Spec->catfile($args{folder}, $mapping{$d->group}.".yaml"), File::Spec->catfile($args{folder}, $d->group.".yaml"));
    };
    foreach my $p (@paths) {
      my $olddatagroup = $p->datagroup;
      $p->datagroup($mapping{$olddatagroup});
      $p->data($p->mo->fetch('Data', $p->datagroup));
    };
  };

  ## -------- make the fit object
  $self -> set(gds    => \@gds,
	       data   => \@data,
	       paths  => \@paths,
	       vpaths => \@vpaths,
	      );

  ## -------- import the fit properties, statistics, correlations
  $yaml = ($args{file}) ? $zip->contents("fit.yaml")
    : $self->slurp(File::Spec->catfile($args{folder}, "fit.yaml"));
  my $rhash = YAML::Tiny::Load($yaml);
  my @array = %$rhash;
  $self -> set(@array);
  $self -> fit_performed(0);

  ## -------- extract files from the feff calculations from the project
  if ($args{file}) {
    $project_folder = $self->project_folder("fit_".$self->group);
    $self->folder($project_folder);
    #   $location_of{ident $fitobject} = $project_folder;
    foreach my $f (@feff) {
      my $ff = $f->group;
      my $feff_folder = File::Spec->catfile($project_folder, "feff_".$ff);
      mkpath($feff_folder);
      my $thisdir = cwd;
      chdir $feff_folder;
      my $ok = 0;

      #     $ok = $zip -> extractMemberWithoutPaths("$f.inp");
      #     croak("Demeter::Fit::deserialize: could not extract $f.inp from $dpj")  if ($ok != AZ_OK);
      #     rename("$f.inp", "oringinal_feff.inp");

      $ok = $zip -> extractMemberWithoutPaths("$ff.yaml");
      croak("Demeter::Fit::deserialize: could not extract $f.yaml from $dpj") if ($ok != AZ_OK);
      rename("$ff.yaml", "feff.yaml");

      $ok = $zip -> extractMemberWithoutPaths("$ff.bin");
      croak("Demeter::Fit::deserialize: could not extract $f.bin from $dpj")  if ($ok != AZ_OK);
      rename("$ff.bin", "phase.bin");

      chdir $thisdir;
    };
  };

  ## -------- import the fit files and push arrays into Ifeffit
  foreach my $d (@data) {
    my $dd = $d->group;
    ## import the fit data
    my $file;
    if ($args{file}) {
      my $thisdir = cwd;
      chdir $self->stash_folder;
      $zip -> extractMemberWithoutPaths("$dd.fit");
      chdir $thisdir;
      $file = File::Spec->catfile($self->stash_folder, "$dd.fit");
    } elsif ($args{folder}) {
      $file = File::Spec->catfile($args{folder}, "$dd.fit");
      $project_folder = $args{folder};
    };
    $d->read_fit($file) if (-e $file);
    $d->fitting(1);
    unlink $file;
  };

  ## -------- import the Plot object, if requested
  if ($args{plot}) {
    $yaml = ($args{file}) ? $zip->contents("plot.yaml")
      : $self->slurp(File::Spec->catfile($args{folder}, "plot.yaml"));
    my $rhash = YAML::Tiny::Load($yaml);
    my @array = %$rhash;
    $self -> po -> set(@array);
  };

  $self->location($project_folder);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};
alias freeze => 'serialize';
alias thaw   => 'deserialize';

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Fit - Fit EXAFS data using Ifeffit

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

  my $fitobject = Demeter::Fit -> new(gds   => \@gds_objects,
                                      data  => [$data_object],
                                      paths => \@path_objects,
	                             );
  $fitobject -> fit;
  $fitobject -> evaluate;
  $fitobject -> logfile("cufit.log");

=head1 DESCRIPTION

This class collects and organizes all the components of a fit using
Ifeffit.  The bulk of a script to fit EXAFS data involves setting up
all the data, paths, and parameters that go into the fit.  Once that
is done, you pass that information to the Fit object as array
references.  It collates all of the information, resolves the
connections between Path and Data objects, performs a number of sanity
checks on the input information, and generates the sequence of Ifeffit
commands needed to perform the fit.  After the hard work of setting up
the Data, Path, and GDS objects is done, you are just a few lines away
from a complete fitting script!

=head1 ATTRIBUTES

Three attributes define a fit.  These are C<gds>, C<data>, and
C<paths>.  Each takes an reference to an array of other objects.  The
C<gds> attribute takes a reference to an array of GDS objects, and so
on.  All other attributes of a Fit object are scalar valued.

The C<set> method will throw an exception if the argument to C<gds>,
C<data>, and C<paths> is not a reference to an array.  Similarly, the
C<get> method returns array references for those three attributes.

Here is a list of the scalar valued attributes.  Many of these get set
automatically when the fit is performed.  All of them are optional.

=over 4

=item C<vpaths>

Like the C<gds>, C<data>, and C<paths> attributes, this takes a
reference to an array.  This array contains all the
L<VPath|Demeter::VPath> objects defined with the fit.  Note that,
unlike the other three, this is not required and is not a part of the
definition of the fit.  In fact, the only use for this attribute is to
have a collection of VPaths saved to a serialization file and
recovered when the fit is deserialized.

=item C<label>

Short descriptive text for this fit.

=item C<description>

Longer descriptive text for this fit.  This will be written to the log
file after a fit.

=item C<fom>

A figure of merit for this fit.  This is intended for reports on
multiple fits.  An example might be the temperature of the data fit
where the report is then intended to show the temperature dependence
of the fit.

=item C<environment>

This is filled in with information about the versions of Demeter and
perl and the operating system used.

=item C<interface>

This is filled in with text identifying the user interface.  The
default value is 'Demeter-based script'.  This should be set to the
name of the program using Demeter.

=item C<time_of_fit>

This is filled in with the time stamp when the fit finishes.

=item C<prepared_by>

This is filled in with an attempt to identify the person performing
the fit.

=item C<contact>

This may be filled in with information about how to contact the person
performing the fit.

=item C<cormin>

Minimum correlation reported in the log file.  This must be a number
between 0 and 1.

=back


=head1 METHODS

=over 4

=item C<fit>

This method returns the sequence of commands to perform a fit in
Ifeffit.  This sequence will include lines defining each guess, def,
set, and restrain parameter.  The data will be imported by the
C<read_data> command.  Each path associated with the data set will be
defined.  Then the text of the Ifeffit's C<feffit> command is
generated.  Finally, commands for defining the after parameters and
for computing the residual arrays are made.

   $fitobject -> fit;

A number of sanity checks are made on the fitting model before the fit is
performed.  For the complete list of these sanity checks, see
L<Demeter::Fit::Sanity>.

=item C<ff2chi>

This method is exactly like the fit method, except that the command
returned perform a sum over paths rather than a fit.  All the same
sanity checks are run.

This takes one argument -- the Data object from the C<data> attribute
whose paths are to be summed.

   $fitobject -> ff2chi($data);

It is useful to remember that a fit can be one a single data set or on
multiple data sets.  An ff2chi is always on a single data set.

C<sum> is an alias for C<ff2chi>;

=item C<rm>

Clean up all on-disk trace of this fit project, typically at the end
of script involving deserialization of project file.

  $fitobject -> rm;

=item C<gds>

This method returns a reference to the list of GDS objects in this fit.

  @list_of_parameters = @{ $fit -> gds };

=item C<data>

This method returns a reference to the list of Data objects in this fit.

  @list_of_data = @{ $fit -> data };

=item C<paths>

This method returns a reference to the list of Path objects in this fit.

  @list_of_paths = @{ $fit -> paths };

=item C<set_all>

NOT WORKING AT THIS TIME.

This method is used to set attributes of every Data, Path, or GDS in a
fit.  For instance, this example sets C<rmin> for each data set to 1.2:

  $fitobject -> set_all('data', {rmin=>1.2});

This example sets the C<sigma2> math expression for each Path in the
fit:

  $fitobject -> set_all('path', {sigma2=>'debye(temp, thetad)'});

This example converts all parameters to be set parameters:

  $fitobject -> set_all('gds', {type => 'set'});

The first argument is one of "data", "paths", "gds" and the second is
a reference to a hash of valid attributes for the object type.

This returns the Fit object reference if the arguments can be properly
interpreted and return 0 otherwise.

=item C<evaluate>

This method is called after the C<fit> or C<ff2chi> method.  This will
evaluate all path parameters, all GDS parameters, and all correlations
between guess parameters and store them in the appropriate objects.
This is always called by the C<fit> method once the fit is finished,
thus it is rarely necessary for you to need to make an explicit call.

   $fitobject -> fit;
   $fitobject -> evaluate;

=item C<logfile>

This write a log file from the results of a fit and an ff2chi.

   $fitobject -> logfile($filename, $header, $footer);

The first argument is the name of the output file.  The other two
arguments are arbitrary text that will be added to the top and bottom
of the log file.

=item C<statistic>

This returns the value of one of the fitting statistics, assuming the
C<evaluate> method has been called.

   $fitobject -> statistic("chi_reduced");

An exception is thrown is the argument is not one of the following:

   n_idp n_varys chi_square chi_reduced r_factor
   epsilon_k epsilon_r data_total

=item C<correl>

This returns the correlation between any two parameters, assuming the
C<evaluate> method has been called.

   my $cor = $fitobject->correl("delr", "enot");

=item C<all_correl>

This returns a complete hash of correlations between parameters,
assuming the C<evaluate> method has been called.

   my %correls = $fitobject -> all_correl;

=item C<correl_report>

This method returns a block of text summarizing all the correlations
above the value given as the first argument, assuming the C<evaluate>
method has been called.  This method is used by the C<logfile> method.

   my $text = $fitobject -> correl_report(0.4);

=item C<happiness>

This returns the happiness evaluation of the fit and is writtent to
the log file.  The two return values are the happiness measurement and
a text summary of how the happiness was evaluated.  See
L<Demeter::Fit::Happiness>.

   ($happiness, $summery) = $fit -> happiness;

=back

=head1 SERIALIZATION AND DESERIALIZATION

A fit can be serialized to a zip file containing YAML serializations
of the various parts of the fit.

  $fitobject->serialize("projectfile");

One of these zip files can be deserialized to a Fit object:

  $newfitobject = Demeter::Fit->new(project=>"projectfile");

The files are normal zip files and can be opened using a normal zip
tool.

C<freeze> and C<thaw> are aliases for the C<serialize> and
C<deserialize> methods.

The constituents of the deserialized fit can be recovered by
dereferencing the arrays stored in the C<gds>, C<data>, and C<paths>
attributes.

  my @gds   = @{ $newfitobject->gds };
  my @data  = @{ $newfitobject->data };
  my @paths = @{ $newfitobject->paths };

=head1 DIAGNOSTICS

These messages are classified as follows (listed in increasing order
of desperation):

    (W) A warning (optional).
    (F) A fatal error (trappable).

=over 4

=item Demeter::Fit: component not an array reference

(F) You have attempted to set one of the array-valued Fit attributes
to something that is not a reference to an array.

=item Demeter::Fit: <key> is not a component of this fit

(W) You have attempted to get an attribute value that is not one of
C<gds>, C<data>, C<paths> or one of the scalar values.

=item No gds component is defined for this fit

=item No data component is defined for this fit

=item No paths component is defined for this fit

(F) You have neglected to define one of the attributes of the Fit
object.

=item This fit is ill-defined.  Giving up...

=item This summation is ill-defined.  Giving up...

(F) One or more of the sanity checks has failed.  Other
diagnostic messages with more details will be issued.

=item '$stat' is not a fitting statistic ($STAT_TEXT)

(W) You have asked for a fitting statitstic that is not one of the
ones available (n_idp n_varys chi_square chi_reduced r_factor
epsilon_k epsilon_r data_total).

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the fit group of configuration parameters.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

It is not clear how serialization and deserialization will work in the
context of an artemis project with multiple fits conatined in one file.

=item *

The log file should be structured by using templates.

=item *

set_all method not implemented

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
