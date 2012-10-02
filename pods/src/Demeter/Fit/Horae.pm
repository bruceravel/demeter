package Demeter::Fit::Horae;

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

use Moose::Role;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use Safe;
use Scalar::Util qw(looks_like_number);

use Demeter::Constants qw($NUMBER);

sub apj2dpj {
  my ($self, $apj, $dpj, $rjournal) = @_;

  ## -------- make a folder in which to unzip the old-style project, then unzip it
  my $unzip = File::Spec->catfile($self->stash_folder, '_old_'.basename($apj, '.apj'));
  rmtree $unzip if (-d $unzip);
  my $zip = Archive::Zip->new();
  confess("File $apj does not appear to be a zip file\n"), return 0 unless ($zip->read($apj) == AZ_OK);
  confess("File $apj does not appear to be an old-style Artemis project file\n"), return 0 unless $zip->memberNamed('HORAE');
  mkpath $unzip;
  $zip->extractTree("", $unzip.'/');
  undef $zip;
  opendir(my $F, File::Spec->catdir($unzip, 'fits'));
  my @all = sort {$b cmp $a} readdir $F;
  closedir $F;
  my $latest = $all[0];

  ## -------- open descriptions/artemis file
  my (@gds, @data, @paths, @feff);
  my %map;
  my ($current_data, $current_feff);
  my $trouble = qw{};
  my $cpt = new Safe;
  open(my $DESC, '<', File::Spec->catfile($unzip, 'descriptions', 'artemis'));
 DESC: while (my $line = <$DESC>) {
    next if $line =~ m{\A\#};
    next if $line =~ m{\A\s*\z};
    next if $line =~ m{\[record\]};

  SWITCH: {

      ## GDS parameters
      ($line =~ m{\@parameter}) and do {
	@ {$cpt->varglob('parameter')} = $cpt->reval( $line );
	my @parameter = @ {$cpt->varglob('parameter')};
	my $me = $parameter[2];
	## old artemis might store a best fit as "1.23 (0.45)".  This purges the uncertainty
	if ($me =~ m{\A\s*($NUMBER)\s+\($NUMBER\)\s*\z}) {
	  $me = $1;
	};
	push @gds, Demeter::GDS->new(name    => $parameter[0],
				     gds     => $parameter[1],
				     mathexp => $me,
				     bestfit => (looks_like_number($parameter[2])) ? $parameter[2] : 0,
				     note    => $parameter[3],
				    ) if ($parameter[1] ne 'sep');
	last SWITCH;
      };

      ## Data, Feff, Path
      ##  order of objects in description file is (note all data objects come first)
      ##     data0
      ##     data1
      ##     ... dataN
      ##     data0.feff0
      ##       each path under that feff calc
      ##     ... dataN.feffM
      ##       each path under that feff calc
      ($line =~ m{\$old_path}) and do {
	$ {$cpt->varglob('old_path')} = $cpt->reval( $line );
	my $old_path = $ {$cpt->varglob('old_path')};
	if ($old_path eq 'gsd') {
	  $trouble .= "$apj is in a very old format.  Demeter does not import old-style project files as ancient as this one.";
	  last DESC;
	};
	my @list = split(/\./, $old_path);
	if ($#list == 0) {
	  my $args = <$DESC>;
	  my $strings = <$DESC>;
	  $current_data = $self->horae_data($unzip, \%map, $args, $strings);
	  last SWITCH if not $current_data;
	  $current_data->readfromfit(File::Spec->catfile($unzip, 'fits', $latest, $old_path.'.fit'));
	  push @data, $current_data;
	  $map{$old_path} = $current_data;
	} elsif ($#list == 1) {
	  my $args = <$DESC>;
	  $current_feff = $self->horae_feff($unzip, \%map, $old_path, $args);
	  push @feff, $current_feff;
	  if ($current_feff->feff_version == 8) {
	    $trouble .= "The old-style project file $apj appears to use Feff8, which Demeter cannot yet handle.";
	    last DESC;
	  };
	} elsif ($#list == 2) {
	  my $args = <$DESC>;
	  my $strings = <$DESC>;
	  push @paths, $self->horae_path($unzip, \%map, $old_path, $current_feff,
					 $args, $strings);
	};
	last SWITCH;
      };
    };

  };
  close $DESC;
  $$rjournal = $self->slurp(File::Spec->catfile($unzip, 'descriptions', 'journal.artemis')) if $rjournal;

  if (not $trouble) {		# prior problems take precedence...
    $trouble .= "There were no data sets in that project file." if not @data;
    $trouble .= "  There were no paths in that project file." if not @paths;
  };

  foreach my $p (@paths) {
    $p->update_path(1);
    $p->folder(q{});
  };
  if (not $trouble) {
    $self->set(gds=>\@gds, data=>\@data, paths=>\@paths, fitted=>0);
    $self->freeze(file=>$dpj);
  };

  ## clean up
  undef $cpt;
  rmtree $unzip;
  foreach my $obj (@gds, @data, @paths, @feff) {
    $obj->DEMOLISH;
  };
  return $trouble if $trouble;
  return $self;
};

## name and other properties of Fit



sub horae_data {
  my ($self, $unzip, $map, $args_line, $string_line) = @_;
  my $data = Demeter::Data->new;

  my $cpt = new Safe;
  @ {$cpt->varglob('args')} = $cpt->reval( $args_line );
  my @args = @ {$cpt->varglob('args')};
  my %args = @args;
  my $file = $args{file};
  return 0 if not $file;
  $file =~ s{/}{\\}g if $self->is_windows;
  $file =~ s{\\}{/}g if not $self->is_windows;
  $file = basename($file);
  return 0 if not -e File::Spec->catfile($unzip, 'chi_data', $file);
  $data->set(datatype=>'chi', name=>$args{lab},
	     file=>File::Spec->catfile($unzip, 'chi_data', $file));
  $data->set(fft_kmin		=> $args{kmin},
	     fft_kmax		=> $args{kmax},
	     fft_dk		=> $args{dk},
	     fft_kwindow	=> $args{kwindow},
	     bft_rmin		=> $args{rmin},
	     bft_rmax		=> $args{rmax},
	     bft_dr		=> $args{dr},
	     bft_rwindow	=> $args{kwindow},
	     fit_k1		=> $args{k1},
	     fit_k2		=> $args{k2},
	     fit_k3		=> $args{k3},
	     fit_karb		=> $args{karb_use},
	     fit_karb_value	=> $args{karb},
	     fit_cormin		=> $args{cormin},
	     fit_do_bkg		=> ($args{do_bkg} eq 'yes'),
	     fit_space		=> $args{fit_space},
	     fit_include	=> $args{include},
	     fit_plot_after_fit	=> $args{plot},
	     fitsum             => 'fit',
	     from_yaml          => 1,
	    );
  $data->_update('fft');
  $data->set(file=>q{}, provenance=>'old-style Artemis project');
  $data->source('old-style Artemis project');

  ##pcedge pcelem pcpath pcplot

  $map->{$args{group}} = $data->group;
  undef $cpt;
  return $data;
};




sub horae_feff {
  my ($self, $unzip, $map, $old_path, $args_line) = @_;
  my $feff = Demeter::Feff::External->new;

  my $cpt = new Safe;
  @ {$cpt->varglob('args')} = $cpt->reval( $args_line );
  my @args = @ {$cpt->varglob('args')};
  my %args = @args;

  $feff -> name($args{lab});
  $feff -> set(workspace=>File::Spec->catfile($unzip, $old_path), screen=>0);
  $feff -> file(File::Spec->catfile($unzip, $old_path, 'feff.inp'));

  #$feff->set_mode(theory=>$feff);
  #print $feff->template("feff", 'full');
  #$feff->set_mode(theory=>q{});

  #$map->{$args{group}} = $feff->group;
  undef $cpt;
  return $feff;
};

sub horae_path {
  my ($self, $unzip, $map, $old_path, $current_feff, $args_line, $string_line) = @_;
  my @list = split(/\./, $old_path);
  my $path = Demeter::Path->new(parent=>$current_feff, data=>$map->{$list[0]});

  my $cpt = new Safe;
  @ {$cpt->varglob('args')} = $cpt->reval( $args_line );
  my @args = @ {$cpt->varglob('args')};
  my %args = @args;
  my $nnnn = substr($args{file}, 4, -4) - 1;
  $path->sp($current_feff->pathlist->[$nnnn]);
  $path->set(name    => $args{lab},
	     s02     => $args{s02},
	     e0      => $args{e0},
	     delr    => $args{delr},
	     sigma2  => $args{'sigma^2'},
	     ei      => $args{ei},
	     third   => $args{'3rd'},
	     fourth  => $args{'4th'},
	     dphase  => $args{dphase},
	     include => $args{include},
	     n       => $args{deg},
	     #degen   => $current_feff->pathlist->[$nnnn]->n,
	    );

  # do I need this?
  #@ {$cpt->varglob('strings')} = $cpt->reval( $string_line );
  #my @strings = @ {$cpt->varglob('strings')};


  return $path;
};


1;


=head1 NAME

Demeter::Fit::Horae - Convert an old-style Artemis project file into a Demeter fit serialization

=head1 VERSION

This documentation refers to Demeter version 0.9.13.

=head1 DESCRIPTION

Convert an old-style Artemis project file file into the equivalent
Demeter fit serialization.  This is a role of the Fit object.

   my $fit = Demeter::Fit->new();
   $fit -> apj2dpj($apjfile, $dpjfile, $rjournal);

This is currently in use by Artemis to import projects from the older
version.

=head1 METHODS

There is only one outwardly visible method, C<apj2dpj>.  It takes
three arguments:

=over 4

=item 1.

The filename of the old-style C<.apj> file.

=item 2.

The filename of the fit serialization, i.e. C<.dpj> file.  This is the
output of this method.  In Artemis, this is a temporary file in the
stash folder which is unlinked after being imported into Artemis.

=item 3.

A reference to a scalar which will be filled with the contents of the
journal from the C<.apj> file.  In Artemis, this is inserted as text
into the Journal buffer.

=back

=head1 CONFIGURATION

There are no configuration options for this role.

See L<Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

blah blah

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
