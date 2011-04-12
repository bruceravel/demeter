package Demeter::Data::IO;

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

use Carp;
use List::MoreUtils qw(none);
use Regexp::Common;
use Regexp::Assemble;

use Readonly;
Readonly my $NUMBER   => $RE{num}{real};


sub save {
  my ($self, $what, $filename, $how) = @_;
  croak("No filename specified for save") unless $filename;
  ($what = 'chi') if (lc($what) eq 'k');
  ($what = 'xmu') if (lc($what) eq 'e');
  croak("Valid save types are: xmu norm chi r q fit bkgsub")
    if ($what !~ m{\A(?:xmu|norm|chi|r|q|fit|bkgsub)\z});
  my $string = q{};
 WHAT: {
    (lc($what) eq 'fit') and do {
      $string = $self->_save_fit_command($filename, $how);
      last WHAT;
    };
    (lc($what) eq 'xmu') and do {
      $self->_update("fft");
      carp("cannot save mu(E) file from chi(k) data\n\n"), return if ($self->datatype eq "chi");
      $string = $self->_save_xmu_command($filename);
      last WHAT;
    };
    (lc($what) eq 'norm') and do {
      $self->_update("fft");
      carp("cannot save norm(E) file from chi(k) data\n\n"), return if ($self->datatype eq "chi");
      $string = $self->_save_norm_command($filename);
      last WHAT;
    };
    (lc($what) eq 'chi') and do {
      $self->_update("fft");
      $string = $self->_save_chi_command('k', $filename);
      last WHAT;
    };
    (lc($what) eq 'r') and do {
      $self->_update("bft");
      $string = $self->_save_chi_command('r', $filename);
      last WHAT;
    };
    (lc($what) eq 'q') and do {
      $self->_update("all");
      $string = $self->_save_chi_command('q', $filename);
      last WHAT;
    };
    (lc($what) eq 'bkgsub') and do {
      $self->_update("all");
      $string = $self->_save_bkgsub_command($filename);
      last WHAT;
    };
  };
  $self->dispose($string);
  return $self;
};


sub _save_chi_command {
  my ($self, $space, $filename) = @_;
  my $pf = $self->po;
  if (not $self->plottable) {
    my $class = ref $self;
    croak("$class objects do not have data that can be saved");
  };
  my $string = q{};
  $space = lc($space);
  croak("Demeter: '$space' is not a valid space for saving chi xdata (k k1 k2 k3 r q)")
    if ($space !~ /\A(?:k$NUMBER?|r|q)\z/); # }

  #my $data = $self->data;
  my $how = ($space eq 'k') ? "chi(k)" :
            ($space eq 'r') ? "chi(R)" :
	                      "chi(q)" ;
  $self->title_glob("dem_data_", $space);

  my ($label, $columns) = (q{}, q{});
  if ($space =~ m{\Ak0?\z}) {
    $self->_update("bft");
    $string = $self->template("process", "save_chik", {filename => $filename,
						       titles   => "dem_data_*"});
  } elsif ($space =~ /\Ak($NUMBER)/) {
    croak("Not doing arbitrary wight chi(k) files just now");
    #$string .= sprintf("set %s.chik = %s.k^%.3f*%s.chi\n", $self, $self, $1, $self);
    #$label   = "k chi" . int($1) . " win";
    #$columns = "$self.k, $self.chik, $self.win";
    #$how = "chi(k) * k^$1";
  } elsif ($space eq 'r') {
    $self->_update("all");
    $string = $self->template("process", "save_chir", {filename => $filename,
						       titles   => "dem_data_*"});
  } elsif ($space eq 'q') {
    $self->_update("all");
    $string = $self->template("process", "save_chiq", {filename => $filename,
						       titles	  => "dem_data_*",});
  } else {
    croak("Demeter::save: How did you get here?");
  }

  return $string;
};



## need to include the data's titles in write_data() command
sub _save_fit_command {
  my ($self, $filename, $how) = @_;
  $how ||= q{};
  croak("No filename specified for save_fit") unless $filename;
  my $template = ($how eq 'k1')   ? 'save_fit_kw'
               : ($how eq 'k2')   ? 'save_fit_kw'
               : ($how eq 'k3')   ? 'save_fit_kw'
               : ($how eq 'rmag') ? 'save_fit_r'
               : ($how eq 'rre')  ? 'save_fit_r'
               : ($how eq 'rim')  ? 'save_fit_r'
               : ($how eq 'qmag') ? 'save_fit_q'
               : ($how eq 'qre')  ? 'save_fit_q'
               : ($how eq 'qim')  ? 'save_fit_q'
               :                    'save_fit';
  my $suffix = ($how eq 'rmag') ? 'chir_mag'
             : ($how eq 'rre')  ? 'chir_re'
             : ($how eq 'rim')  ? 'chir_im'
	     : ($how eq 'qmag') ? 'chiq_mag'
             : ($how eq 'qre')  ? 'chiq_re'
             : ($how eq 'qim')  ? 'chiq_im'
	     :                    q{};
  my $kweight = ($how eq 'k1')      ? 1
              : ($how eq 'k2')      ? 2
              : ($how eq 'k3')      ? 3
              : ($how eq 'k')       ? 0
	      : ($how =~ m{\A[rq]}) ? $self->po->kweight
	      :                       undef;

  if ($how =~ m{\A[rq]}) {
    $self->_update('all');
    $self->part_fft('fit');
    $self->part_fft('res');
    $self->part_fft('bkg') if $self->fit_do_bkg;
  };
  if ($how =~ m{\Aq}) {
    $self->part_bft('fit');
    $self->part_bft('res');
    $self->part_bft('bkg') if $self->fit_do_bkg;
  };
  $self->title_glob("dem_data_", "f", $how);

  $how ||= 'k';
  $self->running(substr($how, 0, 1), $kweight) if defined($kweight);
  my $command = $self-> template("fit", $template, {filename => $filename,
						    titles   => "dem_data_*",
						    suffix   => $suffix,
						    kweight  => $kweight||0,
						   });
  return $command;
};

sub _save_bkgsub_command {
  my ($self, $filename) = @_;
  croak("No filename specified for save_bkgsub") unless $filename;
  $self->title_glob("dem_data_", "f");
  my $command = $self-> template("fit", "save_bkgsub", {filename => $filename,
							titles   => "dem_data_*"});
  return $self;
};


## xmu norm der nder sec nsec
## chi chik chik2 chik3
## chir_mag chir_re chir_im chir_phas
## chiq_mag chiq_re chiq_im chiq_pha
sub save_many {
  my ($self, $outfile, $which, @groups) = @_;
  my $command = $self->_save_many_command($outfile, $which, @groups);
  #print $/, $command, $/;
  $self->dispose($command);
  return $self;
};
sub _save_many_command {
  my ($self, $outfile, $which, @groups) = @_;
  ($which = "chik1") if ($which eq 'chik');
  my $e_regexp = Regexp::Assemble->new()->add(qw(xmu norm der nder sec nsec))->re;
  my $n_regexp = Regexp::Assemble->new()->add(qw(norm nder nsec))->re;
  my $k_regexp = Regexp::Assemble->new()->add(qw(chi chik chik2 chik3))->re;
  my ($level, $space) = ($which =~ m{\A$n_regexp\z}) ? ('fft', 'energy')
                      : ($which =~ m{\Achir})        ? ('bft', 'r')
                      : ($which =~ m{\Achiq})        ? ('all', 'q')
                      : ($which =~ m{\Achi})         ? ('fft', 'k')
	              :                                ('data', 'energy');
  $self->mo->standard($self);
  my $command = q{};

  unshift @groups, $self if (none {$self->group eq $_->group} @groups);

  if ($which =~ m{\Achik(\d*)\z}) {
    my $w = $1 || 1;
    $self -> co -> set(chik => $w);
  };
  foreach my $g (@groups) {
    next if ((ref($g) =~ m{VPath}) and ($level !~ m{(?:fft|bft|all)}));
    $g->_update($level);
    if ($which =~ m{\Achik(\d*)\z})  { # make k-weighted chi(k) array
      $command .= $g->template("process", "chikn");
    } elsif ($which =~ m{$e_regexp}) { # interpolate energy data onto $self's grid
      my $this = $which;
      $this = 'flat' if (($which eq 'norm') and $g->bkg_flatten);
      $command .= ($g->group eq $self->group)
	        ? $g->template("process", "replicate",   {a=>$this, b=>"int"})
	        : $g->template("process", "interpolate", {suffix=>$this});
    };
  };
  $self -> co -> set(many_which  => $which,
		     many_suffix => ($which =~ m{$e_regexp}) ? 'int' : $which,
		     many_space  => $space,
		     many_file   => $outfile,
		     many_list   => \@groups,
		    );
  $command .= $self-> template("process", "save_many_header");
  $command .= $self-> template("process", "save_many");
  if ($which =~ m{\A(?:$e_regexp|chik(?:\d*))\z}) {
    $command .= $self->template("process", "erase_chikn");
  };

  $self->mo->standard(q{});
  return $command;
};


sub data_parameter_report {
  my ($self, $include_rfactor) = @_;
  my $string = $self->data->template("process", "data_report");
  $string =~ s/\+ \-/- /g;
  return $string;
};
sub fit_parameter_report {
  my ($self, $include_rfactor, $fit_performed) = @_;
  $include_rfactor ||= 0;
  $fit_performed   ||= 0;
  my $string = $self->data->template("fit", "fit_report");
  if ($include_rfactor and $fit_performed) {	# only print this for a multiple data set fit
    $string .= sprintf("\nr-factor for this data set = %.7f\n", $self->rfactor);
  };
  return $string;
};

sub rfactor {
  return q{};
};


sub title_glob {
  my ($self, $globname, $space, $how) = @_;
  $how ||= q{};
  my $data = $self->data;
  $space = lc($space);
  my $type = ($space eq 'e') ? " mu(E)"   :
             ($space eq 'n') ? " norm(E)" :
             ($space eq 'k') ? " chi(k)"  :
             ($space eq 'r') ? " chi(R)"  :
             ($space eq 'q') ? " chi(q)"  :
             ($space eq 'f') ? " fit"     :
	                       q{}        ;

  my @titles = split(/\n/, $self->data->template("process", "xdi_report"));
  ($space eq 'f') ? push @titles, split(/\n/, $data->fit_parameter_report) : push @titles, split(/\n/, $data->data_parameter_report);
  my $i = 0;
  $self->dispose("erase \$$globname\*");
  foreach my $line ("XDI/1.0 Demeter/$Demeter::VERSION", @titles, "///", @{$self->data->xdi_comments}) {
    ++$i;
    my $t = sprintf("%s%2.2d", $globname, $i);
    Ifeffit::put_string($t, $line);
  };
  return $self;
};


sub read_fit {
  my ($self, $filename) = @_;
  croak("No filename specified for read_fit") unless $filename;
  my $command = $self-> template("fit", "read_fit", {filename => $filename,});
  ##print $command, $/, $/;
  $self->dispose($command);
  $self->update_fft(1);
  $self->po->plot_fit(1);
  return $self;
};




1;


=head1 NAME

Demeter::Data::IO - Data Input/Output methods for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

  use Demeter;
  my $data  = Demeter::Data -> new(file=>'t/fe.060', @common_attributes);
  $data->save('xmu', 'data.xmu');

=head1 DESCRIPTION

This Demeter::Data role contains methods for dealing
with data input/output.

=head1 METHODS

=over 4

=item C<save>

This method is a wrapper around Ifeffit command generators for saving
the various kinds of output files.  The syntax is

  $dataobject -> save($type, $filename);

The C<$type> argument is one of C<xmu>, C<norm>, C<chi>, C<r>, C<q>,
C<fit>, and C<bkgsub>.  The second argument is the output file name.

This method will automatically generate useful headers for the output
data file.  These headers will include the title lines associated with
the data in Ifeffit and the text of the C<fit_parameter_report> method.

=over 4

=item C<xmu>

This is a seven column file of energy, mu(E), bkg(E), preline(E),
postline(E), first derivative of mu(E), and second derivative of
mu(E).

=item C<norm>

This is a seven column file of energy, norm(E), normalized bkg(E),
flattened mu(E), flattened bkg(E), first derivative of norm(E), and
second derivative of norm(E).

=item C<chi>

This is a five column file of k, chi(k), k*chi(k), k^2*chi(k),
k^3*chi(k), and the window in k.

=item C<r>

This is a six column file of R, real part of chi(r), imaginary part of
chi(r), magnitude of chi(r), phase of chi(r), and the window in R.
The current value of kweight of the Plot object is used to generate chi(R).

=item C<q>

This is a seven column file of q, real part of chi(q), imaginary part
of chi(q), magnitude of chi(q), phase of chi(q), the window in k, the
k-weighted chi(k) used in the Fourier transform.  The current value of
kweight of the Plot object is used to generate chi(R).

=item C<fit>

This is one of a variety of five or six column files.  The default fit
file contains k, chi(k), the fit in k, the residual in k, the
background in k (if the background was fit), and the window.  When
passing an additional parameter, the fit file can be written out in
another way.

    $dataobject -> save('fit', 'my.fit', $type);

If type is left off, the default, un-k-weighted fit file is written.
The other options are:

    k1 k2 k3 rmag rre rim qmag qre qim

The first three export k-weighted data.  The next three are for the
magnitude, real, or imaginary parts of chi(R).  The final three are
for the magnitude, real, or imaginary parts of chi(q).

=item C<bkgsub>

Background subtracted chi(k) data....

=back

=item C<save_many>

This method writes out a multi-column file containing a specified
array from many Data objects.

  $dataobjects[0] -> save_many($outfile, $which, @dataobjects);

The first argument is a file name for the output file containing the
data columns.  The second argument is one of:

  xmu norm der sec nder nsec
  chi chik chik2 chik3
  chir_mag chir_re chir_im chir_pha
  chiq_mag chiq_re chiq_im chiq_pha

These are followed by the list of data groups to write to the file.
The refering object will be added to the front of the list if it is
not already included in the list.

=item C<read_fit>

Reimport a fit written out by a previous instance of Demeter....

=item C<title_glob>

This pushes the title generated by the C<data_parameter_report> or
C<fit_parameter_report> methods into Ifeffit scalars which can then be
accessed by an Ifeffit title glob.

   $object -> title_glob($name, $which)

C<$name> is the base of the name of the string scalars in Ifeffit and
C<$which> is one of C<e>, C<n>, C<k>, C<r>, C<q>, or C<f> depending on
whether you wish to generate title lines for mu(E), normalized mu(E),
chi(k), chi(R), chi(q), or a fit.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

L<Moose> is the basis of Demeter.  This module is implemented as a
role and used by the L<Demeter::Data> object.  I feel obloged
to admit that I am using Moose roles in the most trivial fashion here.
This is mostly an organization tool to keep modules small and methods
organized by common functionality.

=head1 BUGS AND LIMITATIONS

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
