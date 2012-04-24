package Demeter::PeakFit::LineShape;

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

use Carp;
use Pod::POM;

use Demeter::StrTypes qw( Empty Lineshape );

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';
use MooseX::Aliases;

has '+plottable' => (default => 1);
has '+data'    => (isa => Empty.'|Demeter::Data|Demeter::XES');
has '+name'    => (default => 'Lineshape' );
has 'parent'   => (is => 'rw', isa => Empty.'|Demeter::PeakFit', default => q{},
		   trigger => sub{ my ($self, $new) = @_; $self->data($new->data)});
has 'function' => (is => 'rw', isa => Lineshape, default => q{},
		   trigger => sub{ my ($self, $new) = @_;
				   $self->np($self->nparams);
				   $self->peaked(0) if (lc($new) =~ m{linear|atan|erf|const|cubic|quadratic|polynomial|spline|polyline|expdecay});
				 });
has 'peaked'   => (is => 'rw', isa => 'Bool', default => 1, alias => 'is_peak');
has 'np'       => (is => 'rw', isa => 'Int',  default => 0);
has 'start'    => (is => 'rw', isa => 'Int',  default => 0);

has 'xaxis'    => (is => 'rw', isa => 'Str',  default => q{energy});
has 'yaxis'    => (is => 'rw', isa => 'Str',  default => q{flat});
has 'xmin'     => (is => 'rw', isa => 'Num',  default => 0);
has 'xmax'     => (is => 'rw', isa => 'Num',  default => 0);

has 'a0'       => (is => 'rw', isa => 'Num',  default => 0, alias => [ qw(height yint) ]);
has 'a1'       => (is => 'rw', isa => 'Num',  default => 0, alias => [ qw(center slope) ]);
has 'a2'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'hwhm');
has 'a3'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'eta');
has 'a4'       => (is => 'rw', isa => 'Num',  default => 0);
has 'a5'       => (is => 'rw', isa => 'Num',  default => 0);
has 'a6'       => (is => 'rw', isa => 'Num',  default => 0);
has 'a7'       => (is => 'rw', isa => 'Num',  default => 0);

has 'e0'       => (is => 'rw', isa => 'Num',  default => 0, alias => [ qw(eheight eyint) ]);
has 'e1'       => (is => 'rw', isa => 'Num',  default => 0, alias => [ qw(ecenter eslopeyint) ]);
has 'e2'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'ehwhm');
has 'e3'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'eeta');
has 'e4'       => (is => 'rw', isa => 'Num',  default => 0);
has 'e5'       => (is => 'rw', isa => 'Num',  default => 0);
has 'e6'       => (is => 'rw', isa => 'Num',  default => 0);
has 'e7'       => (is => 'rw', isa => 'Num',  default => 0);

has 'fix0'     => (is => 'rw', isa => 'Bool', default => 0, alias => [ qw(fixheight fixyint) ]);
has 'fix1'     => (is => 'rw', isa => 'Bool', default => 0, alias => [ qw(fixcenter fixslope) ]);
has 'fix2'     => (is => 'rw', isa => 'Bool', default => 0, alias => 'fixhwhm');
has 'fix3'     => (is => 'rw', isa => 'Bool', default => 0, alias => 'fixeta');
has 'fix4'     => (is => 'rw', isa => 'Bool', default => 0);
has 'fix5'     => (is => 'rw', isa => 'Bool', default => 0);
has 'fix6'     => (is => 'rw', isa => 'Bool', default => 0);
has 'fix7'     => (is => 'rw', isa => 'Bool', default => 0);

has 'area'     => (is => 'rw', isa => 'Num',  default => 0);

sub nparams {
  my ($self, $function) = @_;
  $function ||= $self->function;
  return 0 if ($function =~ m{\A\s*\z});
  return $self->parent->function_hash->{$function};
};

sub put_arrays {
  my ($self, $rx) = @_;
  my $model_y = $self->parent->put_arrays($self, $rx);
  Ifeffit::put_array($self->group.".".$self->xaxis, $rx);
  Ifeffit::put_array($self->group.".".$self->yaxis, $model_y);
  return $self;
};

sub plot {
  my ($self) = @_;
  $self->dispose($self->template('plot', 'overpeak'), 'plotting');
  $self->po->increment;
  return $self;
};

sub isfixed {
  my ($self,$which) = @_;
  my $att = 'fix'.$which;
  return q{} if $self->$att;
  return q{~};
};

sub parameter_names {
  my ($self, $function) = @_;
  $function ||= $self->function;
  return ('intercept', 'slope')  if lc($function) eq 'linear';
  return ('step', 'e0', 'width') if lc($function) =~ m{atan|erf};

  my $parser = Pod::POM->new();
  my $pom = $parser->parse($INC{$self->parent->my_file});

  my $sections = $pom->head1();
  my $functions_section;
  foreach my $s (@$sections) {
    next unless ($s->title() eq 'LINESHAPES');
    $functions_section = $s;
    last;
  };

  my $titleline = q{};
  foreach my $item ($functions_section->over->[0]->item) { # ick! Pod::POM is confusing!
    $titleline = $item->title;
    last if ($titleline =~ m{\b$function\b});
  };
  chop $titleline;
  my $params = substr($titleline, length($function)+1);
  my @names = map {$_ =~ m{(\w+)\s*=\s*(?:.+)} ? $1 : $_} split(/,\s+/, $params);
  return @names;
};

sub report {
  my ($self) = @_;
  my @names = $self->parameter_names;
  my $string = sprintf("%s (%s)\n   ", $self->name, $self->function);
  my $count = 0;
  foreach my $n (@names) {
    my $a = 'a'.$count;
    my $e = 'e'.$count;
    if ($n =~ m{center|e0}) {
      $string .= sprintf(" %s = %.2f(%.2f),", $n, $self->$a, $self->$e);
    } else {
      $string .= sprintf(" %s = %.3f(%.3f),", $n, $self->$a, $self->$e);
    };
    ++$count;
  };
  chop $string;
  $string .= sprintf("\n    area = %.2f", $self->area) if $self->peaked;
  $string .= $/;
  return $string;
};


sub describe {
  my ($self, $function, $description_only) = @_;
  $function ||= $self->function;
  my $parser = Pod::POM->new();
  my $pom = $parser->parse($INC{$self->parent->my_file});
  my $text;

  my $sections = $pom->head1();
  my $functions_section;
  foreach my $s (@$sections) {
    next unless ($s->title() eq 'LINESHAPES');
    $functions_section = $s;
    last;
  };
  foreach my $item ($functions_section->over->[0]->item) { # ick! Pod::POM is confusing!
    my $this = $item->title;
    if ($this =~ m{\b$function\b}) {
      my $content = $item->content();
      $content =~ s{\n}{ }g;
      $content =~ s{\A\s+}{};
      $content =~ s{\s+\z}{};
      $text = $content;
    };
  };
  undef $parser;
  undef $pom;
  return $text if $description_only;
  $text = sprintf("The functional form of %s is %s%s%s\n", $function, q{}, $text, q{});
  return $text;
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::PeakFit::LineShape - A lineshape object for peak fitting in Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.10.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=over 4

=item C<name>

The string used in a plot lagend.

=item C<parent>

The PeakFit function to which this LineShape belongs.

=item C<function>

The form of the function, like Linear or Gaussian.

=item C<peaked>

A flag that is true if the function associated with this object is a
peak-like function.

Lines, step-like functions, and other non-peaked functions are set to
0.  All others are set to 1.

=item C<np>

The number of parameters used by the specified functional form.

=item C<xaxis>

This is usually set to "energy" and is used by the plotting templates.

=item C<yaxis>

This is usually set to "func" and is used by the plotting templates.

=item C<xmin>

This is set to the lower bound fitting range when the C<fit> method of
the PeakFit object is called.

=item C<xmax>

This is set to the lower bound fitting range when the C<fit> method of
the PeakFit object is called.

=item C<a0> through C<a7>

The guessed (before the fit) and best-fit (after) values of the
parameters of the function.  Note that C<height> is an alias for
C<a0>, C<center> for C<a1>, and C<hwhm> for C<a2> -- all of which is
convenient for peak-like function.  Not all of these are used for any
given function.  For instance, a Voigt only uses C<a0> through C<a3>.

=item C<e0> through C<e7>

The uncertainties (0 before the fit) of the parameters of the
function.  Note that C<eheight> is an alias for C<e0>, C<ecenter> for
C<e1>, and C<ehwhm> for C<e2> -- all of which is convenient for
peak-like function.

=item C<fix0> through C<fix7>

Flags indicating whether to fix the associated value in a fit.  Note
that C<fixheight> is an alias for C<fix0>, C<fixcenter> for C<fix1>,
and C<fixhwhm> for C<fix2> -- all of which is convenient for peak-like
function.

=item C<area>

After the fit, this is filled with a measure of the peak area
for a Peak-like function.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

The function attribute retains an explicit reference to Fityk.

=item *

Need better aliasing of parameter names for add and reporting.

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



