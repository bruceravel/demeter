package Demeter::Fit::Sanity;

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

use Moose::Role;
use Demeter::StrTypes qw( IfeffitFunction IfeffitProgramVar );

use Carp;
use File::Spec;
use List::MoreUtils qw(any);
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER  => $RE{num}{real};
#Readonly my $INTEGER => $RE{num}{int};

use Ifeffit;
use Text::Wrap;
$Text::Wrap::columns = 65;


my $opt  = Regexp::List->new;

sub S_data_files_exist {
  my ($self, $r_problem) = @_;
  my @data = @{ $self->data };
  foreach my $d (@data) {
    next if $d->from_athena;
    my $file = $d->file;
    if (not -e $file) {
      push (@{$$r_problem{errors}}, "The data file \"$file\" does not exist.");
      ++$$r_problem{data_files};
    } elsif (not -r $file) {
      push (@{$$r_problem{errors}}, "The data file \"$file\" cannot be read.");
      ++$$r_problem{data_files};
    };
  };
};

sub S_feff_files_exist {
  my ($self, $r_problem) = @_;
  my @paths = @{ $self->paths };
  foreach my $p (@paths) {
    my ($pathto, $nnnn) = $p->get(qw(folder file));
    my $file = File::Spec->catfile($pathto, $nnnn);
    if (not -e $file) {
      push (@{$$r_problem{errors}}, "The feffNNNN,dat file \"$file\" does not exist.");
      ++$$r_problem{data_files};
    } elsif (not -r $file) {
      push (@{$$r_problem{errors}}, "The feffNNNN.dat file \"$file\" cannot be read.");
      ++$$r_problem{data_files};
    };
  };
};


## 1. check that all guesses are used in defs and pathparams
sub S_defined_not_used {
  my ($self, $r_problem) = @_;
  my @gds   = @{ $self->gds };
  my @paths = @{ $self->paths };
  foreach my $g (@gds) {
    my $name = $g->name;
    my $found = 0;
    next if ($g->gds ne 'guess');
    foreach my $d (@gds) {
      next if ($d->gds !~ m{(?:def|restrain)});
      ++$found if ($d->mathexp =~ /\b$name\b/);
      last if $found;
    };
    foreach my $p (@paths) {
      next if (ref($p) !~ m{Path});
      last if $found;
      foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
	++$found if ($p->$pp =~ /\b$name\b/);
	last if $found;
      };
    };
    if (not $found) {
      push (@{$$r_problem{errors}}, "The guess parameter \"" . $g->name . "\" is not used elsewhere in the fit");
      ++$$r_problem{defined_not_used};
    };
  };
};

## 2. check that defs and path paramers do not use undefined GDS parameters
sub S_used_not_defined {
  my ($self, $r_problem) = @_;
  my @gds   = @{ $self->gds };
  my @paths = @{ $self->paths };
  my @all_params = ();
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    push @all_params, $g->name;
  };
  my $params_regexp = $opt->list2re(@all_params);
  my $tokenizer_regexp = $opt->list2re('-', '+', '*', '^', '/', '(', ')', ',', " ", "\t");
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:guess|merge|skip)});
    my $mathexp = $g->mathexp;
    my @list = split(/$tokenizer_regexp+/, $mathexp);
    foreach my $token (@list) {
      #print $mathexp, "  ", $token, $/;
      next if ($token =~ m{\A\s*\z});		    # space, ok
      next if ($token =~ m{\A$NUMBER\z});	    # number, ok
      next if (is_IfeffitFunction($token));       # function, ok
      next if ($token =~ m{\A(?:etok|pi)\z});     # Ifeffit's defined constants, ok
      next if ($token =~ m{\A$params_regexp\z});  # defined param, ok
      next if (lc($token) eq 'reff');             # reff, ok
      if (lc($token) =~ m{\[?cv\]?}) {
	++$$r_problem{used_not_defined};
	push(@{$$r_problem{errors}}, 'The [cv] token is not currently supported in def parameter math expressions.');
      } else {
	++$$r_problem{used_not_defined};
	push(@{$$r_problem{errors}}, "The parameter \"" . $g->name . "\" uses an undefined token: $token");
      };
    };
  };
  foreach my $p (@paths) {
    next if not defined($p);
    my $label = $p->name;
    foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
      my @list = split(/$tokenizer_regexp+/, $p->$pp);
      foreach my $token (@list) {
	#print $mathexp, "  ", $token, $/;
	next if ($token =~ m{\A\s*\z});	            # space, ok
	next if ($token =~ m{\A$NUMBER\z});         # number, ok
	next if (is_IfeffitFunction($token));       # function, ok
	next if ($token =~ m{\A(?:etok|pi)\z});     # Ifeffit's defined constants, ok
	next if ($token =~ m{\A$params_regexp\z});  # defined param, ok
	next if (lc($token) eq 'reff');             # reff, ok
	next if (lc($token) =~ m{\[?cv\]?});        # cv, ok
	++$$r_problem{used_not_defined};
	push(@{$$r_problem{errors}},
	     "The math expression for $pp for \"$label\" uses an undefined token: $token"
	    );
      };
    };
  };
};

## 3. check that ++ -- // *** ^^ do not appear in math expression
sub S_binary_ops {
  my ($self, $r_problem) = @_;
  my @gds   = @{ $self->gds };
  my @paths = @{ $self->paths };
  my $bad_binary_op_regexp = $opt -> list2re('++', '--', '***', '//', '^^');
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $mathexp = $g->mathexp;
    if ($mathexp =~ m{($bad_binary_op_regexp)}) {
      ++$$r_problem{binary_ops};
      push(@{$$r_problem{errors}},
	   "The math expression for \"" . $g->name . "\" uses an invalid binary operation: $1"
	  );
    };
  };
  foreach my $p (@paths) {
    next if not defined($p);
    my $label = $p->name;
    foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
      my $mathexp = $p->$pp;
      if ($mathexp =~ m{($bad_binary_op_regexp)}) {
	++$$r_problem{binary_ops};
	push(@{$$r_problem{errors}},
	     "The math expression for $pp for \"$label\" uses an invalid binary operation: $1"
	    );
      };
    };
  };
};

## 4. check that all function() names are valid in math expressions
sub S_function_names {
  my ($self, $r_problem) = @_;
  my @gds   = @{ $self->gds   };
  my @paths = @{ $self->paths };

  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $name = $g->name;
    if ($g->mathexp =~ m{(\b\w+)\s*\(}) {
      my $match = $1;
      if (not is_IfeffitFunction($match)) {
	push (@{$$r_problem{errors}}, "$match (used in the math expression for \"$name\") is not a valid Ifeffit function");
	++$$r_problem{function_names};
      };
    };
  };
  foreach my $p (@paths) {
    next if not defined($p);
    my $label = $p->name;
    foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
      my $mathexp = $p->$pp;
      if ($mathexp =~ m{(\b\w+)\s*\(}) {
	my $match = $1;
	if (not is_IfeffitFunction($match)) {
	  push (@{$$r_problem{errors}}, "$match (used in the math expression for $pp for \"$label\") is not a valid Ifeffit function");
	  ++$$r_problem{function_names};
	};
      };
    };
  };
};

## 5. check that all data have unique group names
## 6. check that all paths have unique group names
sub S_unique_group_names {
  my ($self, $r_problem) = @_;
  my @data  = @{ $self->data  };
  my @paths = @{ $self->paths };

  # check data group names
  my %dseen    = ();
  my %tag_seen = ();
  my %cv_seen  = ();
  foreach my $d (@data) {
    ++$dseen{$d->group};
    ++$tag_seen{$d->tag};
    ++$cv_seen{$d->cv};
  };
  foreach my $s (keys %dseen) {
    if ($dseen{$s} > 1) {
      push (@{$$r_problem{errors}}, "The data group name \"$s\" was used more than once.");
      ++$$r_problem{unique_group_names};
    };
  };
  foreach my $s (keys %tag_seen) {
    if ($tag_seen{$s} > 1) {
      push (@{$$r_problem{errors}}, "The data tag \"$s\" was used more than once.");
      ++$$r_problem{unique_tags};
    };
  };
  ## foreach my $s (keys %cv_seen) {
  ##  if ($cv_seen{$s} > 1) {
  ## 	 push (@{$$r_problem{errors}}, "The data characteristic value \"$s\" was used more than once.");
  ## 	 ++$$r_problem{unique_cvs};
  ##  };
  ## };

  # check path group names
  my %pseen = ();
  foreach my $p (@paths) {
    next if not defined($p);
    ++$pseen{$p->group};
  };
  foreach my $s (keys %pseen) {
    if ($pseen{$s} > 1) {
      push (@{$$r_problem{errors}}, "The path group name \"$s\" was used more than once.");
      ++$$r_problem{unique_group_names};
    };
  };

  # cross check data and path group names
  my %seen = ();
  foreach my $p (@data, @paths) {
    next if not defined($p);
    ++$seen{$p->group};
  };
  foreach my $s (keys %seen) {
    if ($seen{$s} > 1 and $pseen{$s} and $pseen{$s} < 2 and $dseen{$s} < 2) {
      push (@{$$r_problem{errors}}, "The group name \"$s\" was used for more than one object.");
      ++$$r_problem{unique_group_names};
    };
  };
};

## 7. check that all GDS have unique names
sub S_gds_unique_names {
  my ($self, $r_problem) = @_;
  my @gds = @{ $self->gds };
  my %seen = ();
  foreach my $g (@gds) {
    ++$seen{$g->name};
  };
  foreach my $s (keys %seen) {
    if ($seen{$s} > 1) {
      push (@{$$r_problem{errors}}, "The parameter \"$s\" was defined more than once.");
      ++$$r_problem{gds_unique_names};
    };
  };
};

## 8. check that parens match
sub S_parens_not_match {
  my ($self, $r_problem) = @_;
  my @gds   = @{ $self->gds   };
  my @paths = @{ $self->paths };
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $name = $g->name;
    my $not_ok = $self->check_parens($g->mathexp);
    if ($not_ok) {
      push (@{$$r_problem{errors}}, "The math expression for \"$name\" has mismatched parens.");
      ++$$r_problem{parens_not_match};
    };
  };
  foreach my $p (@paths) {
    next if not defined($p);
    my $label = $p->name;
    foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
      my $mathexp = $p->$pp;
      my $not_ok = $self->check_parens($mathexp);
      if ($not_ok) {
	push (@{$$r_problem{errors}}, "The math expression for $pp for \"$label\" has mismatched parens.");
	++$$r_problem{parens_not_match};
      };
    };
  };
};

## 9. check that data params make sense
sub S_data_parameters {
  my ($self, $r_problem) = @_;
  my @data  = @{ $self->data  };
  foreach my $d (@data) {
    next if (not $d->fit_include);
    my ($kmin, $kmax) = $d->get(qw(fft_kmin fft_kmax));
    if ($kmin >= $kmax) {
      push (@{$$r_problem{errors}}, "The value of kmin for data set \"$d\" is not smaller than kmax");
      ++$$r_problem{data_parameters};
    };
    my ($rmin, $rmax) = $d->get(qw(bft_rmin bft_rmax));
    if ($kmin >= $kmax) {
      push (@{$$r_problem{errors}}, "The value of Rmin for data set \"$d\" is not smaller than Rmax");
      ++$$r_problem{data_parameters};
    };
  };
};

## 10. check that number of guesses does not exceed Nidp
sub S_nidp {
  my ($self, $r_problem) = @_;
  my @gds   = @{ $self->gds   };
  my @data  = @{ $self->data  };
  my ($nidp, $ndata) = (0,0);
  foreach my $d (@data) {
    next if (not $d->fit_include);
    ++$ndata;
    $nidp += $d->nidp;
  };
  my $nguess = 0;
  foreach my $g (@gds) {
    ++$nguess if ($g->gds eq 'guess');
  };
  if ($nguess > $nidp) {
    push (@{$$r_problem{errors}}, sprintf("You have %.1f independent points in %d data sets but have used %d guess parameters.", $nidp, $ndata, $nguess));
    ++$$r_problem{nidp};
  };
};

## 11. check that rmin is not greater than rbkg
sub S_rmin_rbkg {
  my ($self, $r_problem) = @_;
  my @data  = @{ $self->data  };
  foreach my $d (@data) {
    next if ($d->datatype eq 'chi');
    next if (not $d->fit_include);
    if ($d->bft_rmin < $d->bkg_rbkg) {
      push (@{$$r_problem{errors}}, "Rmin is smaller than Rbkg for data set " . $d->name);
      ++$$r_problem{rmin_rbkg};
    };
  };
};

## 12. check that reff is not far beyond Rmax for any path
sub S_reff_rmax {
  my ($self, $r_problem) = @_;
  my @data  = @{ $self->data  };
  my @paths = @{ $self->paths };
  foreach my $d (@data) {
    next if (not $d->fit_include);
    foreach my $p (@paths) {
      next if not defined($p);
      next if ($p->data ne $d);
      if ($p->reff > ($d->bft_rmax+1)) {
	push (@{$$r_problem{errors}}, "Reff for path \"" . $p->name . "\" is well beyond Rmax for data set \"" . $d->name . "\"");
	++$$r_problem{reff_rmax};
      };
    };
  };
};

#  &max_scalars   =   65536.000000000
#  &max_arrays    =    8192.000000000
#  &max_strings   =    8192.000000000
#  &max_paths     =    1024.000000000
#  &max_varys     =     128.000000000
#  &max_data_sets =      16.000000000
#  spline knots   =      32
#  restraints     =      10
## 13. check that ifeffit hardwired limits are not exceeded
sub S_exceed_ifeffit_limits {
  my ($self, $r_problem) = @_;
  my @gds   = @{ $self->gds   };
  my @data  = @{ $self->data  };
  my @paths = @{ $self->paths };

  ## number of guess params
  my $n_guess     = 0;
  my $n_params    = 0;
  my $n_restraint = 0;
  foreach my $g (@gds) {
    ++$n_guess     if ($g->gds eq 'guess');
    ++$n_params    if ($g->gds !~ m{(?:merge|skip)});
    ++$n_restraint if ($g->gds eq 'restrain');
  };
  if ($n_guess > Ifeffit::get_scalar('&max_varys')) {
    push (@{$$r_problem{errors}}, "You have defined more than Ifeffit's limit of " . Ifeffit::get_scalar('&max_varys') . " guess parameters.");
    ++$$r_problem{exceed_max_nvarys};
  };
  if ($n_params > Ifeffit::get_scalar('&max_scalars')) {
    push (@{$$r_problem{errors}}, "You have defined more than Ifeffit's limit of " . Ifeffit::get_scalar('&max_scalars') . " scalars.  (Wow!)");
    ++$$r_problem{exceed_max_params};
  };
  if ($n_restraint > 10) {
    push (@{$$r_problem{errors}}, "You have defined more than Ifeffit's limit of 10 restraints.");
    ++$$r_problem{exceed_max_restraints};
  };

  ## number of data sets
  my $n_data = 0;
  foreach my $d (@data) {
    ++$n_data if ($d->fit_include);
  };
  if ($n_data > Ifeffit::get_scalar('&max_data_sets')) {
    push (@{$$r_problem{errors}}, "You have defined more than Ifeffit's limit of " . Ifeffit::get_scalar('&max_datasets') . " data sets.");
    ++$$r_problem{exceed_max_datasets};
  };

  ## number of paths
  my $n_paths = 0;
  foreach my $p (@paths) {
    next if not defined($p);
    ++$n_paths if ($p->include);
  };
  if ($n_paths > Ifeffit::get_scalar('&max_paths')) {
    push (@{$$r_problem{errors}}, "You have defined more than Ifeffit's limit of " . Ifeffit::get_scalar('&max_paths') . " paths.");
    ++$$r_problem{exceed_max_paths};
  };

};

## 14. check that parameters do not have program variable names
sub S_program_var_names {
  my ($self, $r_problem) = @_;
  my @gds = @{ $self->gds };
  foreach my $g (@gds) {
    if (is_IfeffitProgramVar($g->name)) {
      push (@{$$r_problem{errors}}, "\"" . $g->name . "\" is an Ifeffit program variable and cannot be a parameter in the fit.");
      ++$$r_problem{program_var_names};
    };
  };
};

## 16. check that all Path objects have either a ScatteringPath or a folder/file defined
sub S_path_calculation_exists {
  my ($self, $r_problem) = @_;
  my @paths = @{ $self->paths };
  foreach my $p (@paths) {
    next if (ref($p->sp) =~ m{(?:ScatteringPath|SSPath)});
    my $nnnn = File::Spec->catfile($p->folder, $p->file);
    next if ((-e $nnnn) and $p->file);
    push (@{$$r_problem{errors}}, "Path number " . $p->Index . " does not have a valid Feff calculation associated with it.");
    ++$$r_problem{path_calculation_exists};
  };
};

## 17. check that there are no unresolved merge parameetrs
sub S_notice_merge {
  my ($self, $r_problem) = @_;
  my @gds = @{ $self->gds };
  foreach my $g (@gds) {
    if ($g->gds eq 'merge') {
      push (@{$$r_problem{errors}}, "Parameter " . $g->name . " is an unresolved merge parameter.");
      ++$$r_problem{merge_parameters_exists};
    };
  };
};


1;


=head1 NAME

Demeter::Fit::Sanity - Sanity checks for EXAFS fitting models

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

  my $fitobject = Demeter::Fit ->
     new(gds   => \@gds_objects,
	 data  => [$data_object],
	 paths => \@path_objects,
	);
  $command = $fitobject -> fit;

Before the fit method is run, a series of sanity check on the data
contained in the fit object is run.  The sanity checks all live in
this module.

=head1 DESCRIPTION

This module contains all the sanity checks made on a Fit object before
the fit starts.  This file forms part of the base of the
Demeter::Fit class and serves no independent function.  That
is, using this module directly in a program does nothing useful -- it
is purely a utility module for the Feff object.

The user should never need to call the methods explicitly since they
are called automatically whenever a fit or a sum is performed.
However they are documented here so that the scope of such checks made
is clearly understood.

When problems are found, the fit will exit and a descriptive report
will be made.

=head1 METHODS

The following sanity checks are made on the Fit object:

=over 4

=item *

All data files included in the fit exist.

=item *

All F<feffNNNN.dat> files used in the fit exist.

=item *

All guess parameters are used in at least one def parameter or path
parameter.

=item *

No def or path parameters use parameters which have not been defined.

=item *

Binary operators are used correctly, specifically that none of these
strings appear in a math expression:

   ++    --   //   ***   ^^

=item *

All function names (i.e. strings that are followed by an open paren)
are valid Ifeffit functions.

=item *

All data and path objects have unique group names.

=item *

All GDS parameters have unique names.

=item *

All opening parens are matched by closing parens.

=item *

All data paremeters make sense, for example that C<fft_kmin> is
smaller than C<fft_kmax>.

=item *

The number of guess parameters does not exceed the number of
independent points.

=item *

The C<bft_rmin> value is not greater than C<bkg_rbkg>.

=item *

The R_eff of any path is not far beyond C<bft_rmax>.

=item *

Ifeffit's hardwired limits on things like the maximum number of guess
parameters and the maximum number of data sets are not exceeded by the
fitting model.

=item *

No GDS parameters have the names of Ifeffit program variables or other
reserved words.

=item *

No merge parameters remain unresolved.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter> for a description of the configuration system.

=head1 BUGS AND LIMITATIONS

Missing tests:

=over 4

=item *

Test that every included data set has at least 1 path associated with it.

=item *

Test that every Path is associated with a data set.  (Warn, not fatal.)

=item *

Test that each data in the data array is properly defined.

=item *

Test that every Path points to a real path file

=item *

Test that no def parameters are "recursive", i.e. something like

  def a = 5*a

Testing for circularity could be more challenging...

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
