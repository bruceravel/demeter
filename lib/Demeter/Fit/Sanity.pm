package Demeter::Fit::Sanity;

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

use Moose::Role;
use Demeter::StrTypes qw( IfeffitFunction IfeffitProgramVar );

use Carp;
use File::Spec;
use List::MoreUtils qw(any);
use Graph;
use Regexp::Assemble;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER   => $RE{num}{real};
#Readonly my $INTEGER => $RE{num}{int};
Readonly my $NULLFILE => '@&^^null^^&@';

use Text::Wrap;
$Text::Wrap::columns = 65;



sub S_data_files_exist {
  my ($self) = @_;
  my $found = 0;
  my @data = @{ $self->data };
  foreach my $d (@data) {
    next if $d->from_athena;
    return 0 if ($d->file eq $NULLFILE);
    my $file = $d->file;
    if (not -e $file) {
      ++$found;
      $d->add_trouble('-e');
    } elsif (not -r $file) {
      ++$found;
      $d->add_trouble('-r');
    };
  };
  return $found;
};

sub S_feff_files_exist {
  my ($self) = @_;
  my $found = 0;
  my @paths = @{ $self->paths };
  foreach my $p (@paths) {
    my ($pathto, $nnnn) = $p->get(qw(folder file));
    my $file = File::Spec->catfile($pathto, $nnnn);
    if (not -e $file) {
      ++$found;
      $p->add_trouble('-e');
    } elsif (not -r $file) {
      ++$found;
      $p->add_trouble('-r');
    };
  };
  return $found;
};


## 1. check that all guesses are used in defs and pathparams
sub S_defined_not_used {
  my ($self) = @_;
  my $found = 0;
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
      next if not $p->include;
      last if $found;
      foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
	++$found if ($p->$pp =~ /\b$name\b/);
	last if $found;
      };
    };
    if (not $found) {
      ++$found;
      $g->trouble('notused');
    };
  };
  return $found;
};

## 2. check that defs and path paramers do not use undefined GDS parameters
sub S_used_not_defined {
  my ($self) = @_;
  my $found = 0;
  my @gds   = @{ $self->gds };
  my @paths = @{ $self->paths };
  my @all_params = ();
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    push @all_params, $g->name;
  };
  my $params_regexp = Regexp::Assemble->new()->add(@all_params)->re;
  my $tokenizer_regexp = '(?-xism:(?=[\t\ \(\)\*\+\,\-\/\^])[\-\+\*\^\/\(\)\,\ \t])';
  ## this came from:
  # use Regexp::List;
  # my $opt = Regexp::List->new;
  # print $opt->list2re('-', '+', '*', '^', '/', '(', ')', ',', " ", "\t"), $/;

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
	++$found;
	$g->add_trouble('usecv');
      } else {
	++$found;
	$g->add_trouble('useundef');
      };
    };
  };
  foreach my $p (@paths) {
    next if not defined($p);
    next if not $p->include;
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
	++$found;
	#     "The math expression for $pp for \"$label\" uses an undefined token: $token"
	#    );
	$p->add_trouble(join('_', 'useundef', $pp, $token));
      };
    };
  };
  return $found;
};

## 3. check that ++ -- // *** ^^ do not appear in math expression
sub S_binary_ops {
  my ($self) = @_;
  my $found = 0;
  my @gds   = @{ $self->gds };
  my @paths = @{ $self->paths };
  my $bad_binary_op_regexp = '(?-xism:(?=[\*\+\-\/\^])(?:\+\+|\-\-|\*\*\*|\/\/|\^\^))';
  ##Regexp::Assemble->new()->add('++', '--', '***', '//', '^^')->re;
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $mathexp = $g->mathexp;
    if ($mathexp =~ m{($bad_binary_op_regexp)}) {
      my $which = $1;
      ++$found;
      #	   "The math expression for \"" . $g->name . "\" uses an invalid binary operation: $which"
      #	  );
      $g->add_trouble("binary_x_$which");
    };
  };
  foreach my $p (@paths) {
    next if not defined($p);
    my $label = $p->name;
    foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
      my $mathexp = $p->$pp;
      if ($mathexp =~ m{($bad_binary_op_regexp)}) {
	my $which = $1;
	++$found;
	#     "The math expression for $pp for \"$label\" uses an invalid binary operation: $which"
	#    );
	$p->add_trouble(join('_', 'binary', $pp, $which));
      };
    };
  };
  return $found;
};

## 4. check that all function() names are valid in math expressions
sub S_function_names {
  my ($self) = @_;
  my $found = 0;
  my @gds   = @{ $self->gds   };
  my @paths = @{ $self->paths };

  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $name = $g->name;
    if ($g->mathexp =~ m{(\b\w+)\s*\(}) {
      my $match = $1;
      if (not is_IfeffitFunction($match)) {
	++$found;
	$g->add_trouble("function_$match");
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
	  ++$found;
	  $p->add_trouble(join('_', 'function', $pp, $match));
	};
      };
    };
  };
  return $found;
};

## 5. check that all data have unique group names
## 6. check that all paths have unique group names
sub S_unique_group_names {
  my ($self) = @_;
  my $found = 0;
  my @data  = @{ $self->data  };
  my @paths = @{ $self->paths };

  # check data group names
  my %dseen    = ();
  my %tag_seen = ();
  my %cv_seen  = ();
  foreach my $d (@data) {
    ++$dseen{$d->group};
    $d->add_trouble('namenotunique') if ($dseen{$d->group} > 1);
    ++$tag_seen{$d->tag};
    $d->add_trouble('tagnotunique')  if ($tag_seen{$d->tag} > 1);
    ++$cv_seen{$d->cv};
    $d->add_trouble('cvnotunique')   if ($cv_seen{$d->cv} > 1);
  };
  foreach my $s (keys %dseen) {
    if ($dseen{$s} > 1) {
      ++$found;
    };
  };
  foreach my $s (keys %tag_seen) {
    if ($tag_seen{$s} > 1) {
      ++$found;
    };
  };
  ## foreach my $s (keys %cv_seen) {
  ##  if ($cv_seen{$s} > 1) {
  ## 	 ++$found;
  ##  };
  ## };

  # check path group names
  my %pseen = ();
  foreach my $p (@paths) {
    next if not defined($p);
    ++$pseen{$p->group};
    $p->add_trouble('namenotunique') if ($pseen{$p->group} > 1);
  };
  foreach my $s (keys %pseen) {
    if ($pseen{$s} > 1) {
      ++$found;
    };
  };

  # cross check data and path group names
  my %seen = ();
  foreach my $p (@data, @paths) {
    next if not defined($p);
    ++$seen{$p->group};
    $p->add_trouble('pathdataname') if ($seen{$p->group} > 1);
  };
  foreach my $s (keys %seen) {
    if ($seen{$s} > 1 and $pseen{$s} and $pseen{$s} < 2 and $dseen{$s} < 2) {
      ++$found;
    };
  };
  return $found;
};

## 7. check that all GDS have unique names
sub S_gds_unique_names {
  my ($self) = @_;
  my $found = 0;
  my @gds = @{ $self->gds };
  my %seen = ();
  foreach my $g (@gds) {
    ++$seen{$g->name};
    $g->add_trouble('notunique') if ($seen{$g->name} > 1);
  };
  foreach my $s (keys %seen) {
    if ($seen{$s} > 1) {
      ++$found;
    };
  };
  return $found;
};

## 8. check that parens match
sub S_parens_not_match {
  my ($self) = @_;
  my $found = 0;
  my @gds   = @{ $self->gds   };
  my @paths = @{ $self->paths };
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $name = $g->name;
    my $not_ok = $self->check_parens($g->mathexp);
    if ($not_ok) {
      ++$found;
      $g->add_trouble('parens');
    };
  };
  foreach my $p (@paths) {
    next if not defined($p);
    my $label = $p->name;
    foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
      my $mathexp = $p->$pp;
      my $not_ok = $self->check_parens($mathexp);
      if ($not_ok) {
	++$found;
	$p->add_trouble("parens_".$pp);
      };
    };
  };
  return $found;
};

## 9. check that data params make sense
sub S_data_parameters {
  my ($self) = @_;
  my $found = 0;
  my @data  = @{ $self->data  };
  foreach my $d (@data) {
    next if (not $d->fit_include);
    my ($kmin, $kmax) = $d->get(qw(fft_kmin fft_kmax));
    if ($kmin >= $kmax) {
      ++$found;
      $d->add_trouble('kminkmax');
    };
    my ($rmin, $rmax) = $d->get(qw(bft_rmin bft_rmax));
    if ($rmin >= $rmax) {
      ++$found;
      $d->add_trouble('rminrmax');
    };
  };
  return $found;
};

## 10. check that number of guesses does not exceed Nidp
sub S_nidp {
  my ($self) = @_;
  my $found = 0;
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
    ++$found;
    $self->add_trouble('nvarnidp');
  };
  return $found;
};

## 11. check that rmin is not greater than rbkg
sub S_rmin_rbkg {
  my ($self) = @_;
  my $found = 0;
  my @data  = @{ $self->data  };
  foreach my $d (@data) {
    next if ($d->datatype eq 'chi');
    next if (not $d->fit_include);
    if ($d->bft_rmin < $d->bkg_rbkg) {
      ++$found;
      $d->add_trouble('rminrbkg');
    };
  };
  return $found;
};

## 12. check that reff is not far beyond Rmax for any path
sub S_reff_rmax {
  my ($self) = @_;
  my $found = 0;
  my @data  = @{ $self->data  };
  my @paths = @{ $self->paths };
  foreach my $d (@data) {
    next if (not $d->fit_include);
    foreach my $p (@paths) {
      next if not defined($p);
      next if (not $p->include);
      next if ($p->data ne $d);
      if ($p->reff > ($d->bft_rmax+1)) {
	my $identify = $p->name || $p->Index;
	++$found;
	$p->add_trouble('reffrmax');
      };
    };
  };
  return $found;
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
  my ($self) = @_;
  my $found = 0;
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
    ++$found;
    $self->add_trouble('nvarys');
  };
  if ($n_params > Ifeffit::get_scalar('&max_scalars')) {
    ++$found;
    $self->add_trouble('nparams');
  };
  if ($n_restraint > 10) {
    ++$found;
    $self->add_trouble('nrestraints');
  };

  ## number of data sets
  my $n_data = 0;
  foreach my $d (@data) {
    ++$n_data if ($d->fit_include);
  };
  if ($n_data > Ifeffit::get_scalar('&max_data_sets')) {
    ++$found;
    $self->add_trouble('ndatasets');
  };

  ## number of paths
  my $n_paths = 0;
  foreach my $p (@paths) {
    next if not defined($p);
    ++$n_paths if ($p->include);
  };
  if ($n_paths > Ifeffit::get_scalar('&max_paths')) {
    ++$found;
    $self->add_trouble('npaths');
  };

  return $found;
};

## 14. check that parameters do not have program variable names
sub S_program_var_names {
  my ($self) = @_;
  my $found = 0;
  my @gds = @{ $self->gds };
  foreach my $g (@gds) {
    if (is_IfeffitProgramVar($g->name)) {
      ++$found;
      $g->add_trouble('progvar');
    };
  };
  return $found;
};

## 16. check that all Path objects have either a ScatteringPath or a folder/file defined
sub S_path_calculation_exists {
  my ($self) = @_;
  my $found = 0;
  my @paths = @{ $self->paths };
  foreach my $p (@paths) {
    next if (ref($p->sp) =~ m{(?:ScatteringPath|SSPath|FPath)});
    my $nnnn = File::Spec->catfile($p->folder, $p->file);
    next if ((-e $nnnn) and $p->file);
    ++$found;
    $p->add_trouble('nocalc');
  };
  return $found;
};

## 17. check that there are no unresolved merge parameetrs
sub S_notice_merge {
  my ($self) = @_;
  my $found = 0;
  my @gds = @{ $self->gds };
  foreach my $g (@gds) {
    if ($g->gds eq 'merge') {
      ++$found;
      $g->add_trouble('merge');
    };
  };
  return $found;
};

## 18. check that no more than one path is flagged as the default
sub S_default_path {
  my ($self) = @_;
  my $found = 0;
  my @paths = @{ $self->paths };
  foreach my $p (@paths) {
    ++$found if $p->default_path;
  };
  $self->add_trouble('defaultpath') if ($found > 1);
  return $found;
};

## 19. check for loops and cycles among the GDS math expressions
sub S_cycle_loop {
  my ($self) = @_;
  my $found = 0;
  my @gds   = @{ $self->gds };
  my @all_params = ();
  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    push @all_params, $g->name;
  };
  my $tokenizer_regexp = '(?-xism:(?=[\t\ \(\)\*\+\,\-\/\^])[\-\+\*\^\/\(\)\,\ \t])';
  #my $tokenizer_regexp = Regexp::Assemble->new()->add('-', '+', '*', '^', '/', '(', ')', ',', " ", "\t")->re;
  my $graph = Graph->new;

  foreach my $g (@gds) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $mathexp = $g->mathexp;
    my @list = split(/$tokenizer_regexp+/, $mathexp);
    foreach my $token (@list) {
      next if ($token =~ m{\A\s*\z});		  # space, ok
      next if ($token =~ m{\A$NUMBER\z});	  # number, ok
      next if (is_IfeffitFunction($token));       # function, ok
      next if ($token =~ m{\A(?:etok|pi)\z});     # Ifeffit's defined constants, ok
      next if (lc($token) eq 'reff');             # reff, ok

      $graph -> add_edge($g->name, $token);
    };
  };

  foreach my $loop ($graph->self_loop_vertices) {
    $self->add_trouble(join('_', 'loop', 'x', $loop));
    ++$found;
  };
  if ($graph->has_a_cycle) {
    my @cycle = $graph->find_a_cycle;
    if ($#cycle) {		# we have already reported on loops
      $self->add_trouble(join('_', 'cycle', 'x', join(" --> ", @cycle)));
      ++$found;
    };
  };

  return $found;
};
1;


=head1 NAME

Demeter::Fit::Sanity - Sanity checks for EXAFS fitting models

=head1 VERSION

This documentation refers to Demeter version 0.4.

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

=head1 TROUBLE REPORTING

The C<trouble> attribute of an Demeter object will be filled with a
pipe-separated list of problem codes.

Some error codes contain additional information to further identify
the problem.  These codes have a keyword separated from the other
information by an underscore, making these sufficiently easy to parse
on the fly.  Indeed, the C<translate_trouble> method of the base
object (see L<Demeter>) does just that, so error reporting during a
fit is an example of literate programming.

Here are the explanations:

=head2 Problems with Data objects

=over 4

=item C<-e>

This data file does not exist.

=item C<-r>

This data file cannot be read.

=item C<namenotunique>

The Ifeffit group name of this data group is not unique.

=item C<pathdataname>

This path has an Ifeffit group name which is used by a Path object.

=item C<tagnotunique>

The tag of this data group is not unique.

=item C<cvnotunique>

The characteristic value of this data group is not unique.

=item C<kminkmax>

C<kmin> is larger than C<kmax>.

=item C<rminrmax>

C<rmin> is larger than C<rmax>.

=item C<rminrbkg>

C<rmin> is smaller than the value of C<rbkg> that was used in the
background removal.

=back

=head2 Problems with Path objects

=over 4

=item C<-e>

The path file does not exist (perhaps the Feff calculation was not run).

=item C<-r>

The path file cannot be read.

=item C<useundef> + C<$pp> + C<$token>

The math expression for the C<$pp> path parameter contains an undefined
parameter, C<$token>.

=item C<binary> + C<$pp> + C<$token>

The math expression for the C<$pp> path parameter contains an unallowed
binary math operator, C<$token>.

=item C<function> + C<$pp> + C<$token>

The math expression for the C<$pp> path parameter contains a
mathematical function unknown to Ifeffit, C<$token>.

=item C<namenotunique>

The Ifeffit group name for this path is not unique.

=item C<pathdataname>

This path has an Ifeffit group name which is used by a Data object.

=item C<parens> + C<$pp>

The math expression for the C<$pp> path parameter has unmatched parentheses.

=item C<reffrmax>

The R effective for this path is well beyond the C<rmax> value of its
Data object.

=item C<nocalc>

It seems as though the Feff calculation for this path has not been made yet.

=back

=head2 Problems with GDS objects

=over 4

=item C<notused>

This is a guess parameter which is not used in the math expressions
for any def or path parameters.

=item C<usecv>

This is a def parameter which uses the characteristic value (cv).
This is not yet allowed for def parameters.

=item C<useundef>

The math expression for this GDS parameter uses an undefined parameter
name.

=item C<binary> + C<$token>

The math expression for this GDS parameter contains an unallowed
binary math operator, C<$token>.

=item C<function> + C<$token>

The math expression for this GDS parameter contains a mathematical
function unknown to Ifeffit, C<$token>.

=item C<notunique>

The name of this GDS parameter is not unique.

=item C<parens>

The math expression for this GDS parameter has unmatched parentheses.

=item C<progvar>

The name of this GDS parameter is an Ifeffit program variable name.

=item C<merge>

This is an unresolved parameter from the merge of fitting projects.

=back

=head2 Problems with Fit objects

=over 4

=item C<gds>

No GDS parameters are defined for this fit

=item C<data>

No data sets are defined for this fit

=item C<paths>

No paths are defined for this fit

=item C<nvarnidp>

This fitting model uses more guess parameters than the available
information content of the data.

=item C<nvarys>

This fitting model uses more than Ifeffit's compiled-in limit of guess
parameters (&max_varys).

=item C<nparams>

This fitting model uses more than Ifeffit's compiled-in limit of
parameters (&max_scalars).

=item C<nrestraints>

This fitting model uses more than Ifeffit's compiled-in limit of
restraints (10).

=item C<ndatasets>

This fitting model uses more than Ifeffit's compiled-in limit of
data sets (&max_data_sets).

=item C<npaths>

This fitting model uses more than Ifeffit's compiled-in limit of
paths (&max_paths).

=item C<defaultpath>

More than one path is flagged as being the default path, making it
unclear how to evaluate the log file.

=item C<loop> + C<$token>

The parameter C<$token> refers to itself in its math expression.

=item C<cycle> + C<$token>

There is a cyclical dependence among a set of parameter math
expressions. This cycle is C<$token>.

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
