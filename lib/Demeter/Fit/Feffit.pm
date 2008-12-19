package Demeter::Fit::Feffit;

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

use autodie qw(open close);

use Moose;
extends 'Demeter';
use MooseX::AttributeHelpers;

use Cwd qw(realpath);
use File::Basename;
use File::Spec;
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER    => $RE{num}{real};

my $opt  = Regexp::List->new;

has 'file'    => (is => 'rw', isa => 'Str',  default => q{},
		  trigger => sub{shift -> Read} );
has 'cwd'     => (is => 'rw', isa => 'Str', default => 0);
has 'ndata'   => (is => 'rw', isa => 'Int', default => 0);

## feffit keywords
has 'all_re'       => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re(qw(format formin formout rspout kspout qspout allout bkgfile out output
							bkg data kmin kmax rmin rmax dk dk1 dk2 dr dr1 dr2 rlast kw kweight
							nodegen noout nofit norun rspfit qspfit
						      )) });
has 'flag_re'      => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re(qw(nodegen noout nofit norun rspfit qspfit)) });
has 'kop_re'       => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re(qw(kmin kmax dk dk1 dk2 kw kweight)) });
has 'rop_re'       => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re(qw(rmin rmax dr dr1 dr2 rlast)) });
has 'ignore_re'    => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re(qw(format formin formout rspout kspout qspout allout
							bkgfile out output mftwrt mftfit)) });
has 'opparam_re'   => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re(qw(bkg data kmin kmax rmin rmax dk dk1 dk2 dr dr1 dr2 kw kweight nodegen)) });
has 'pathparam_re' => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re(qw(path id e0 s02 sigma2 delr ei third fourth)) });
has 'comment_re'   => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ $opt->list2re('!', '#', '%') });


my @data;
$data[0] = ({titles=>[], opparams=>{}, path=>[], feffcalcs=>[]});
my @gds;

sub Read {
  my ($self) = @_;
  my $file = $self->file;
  return 0 if not $file;
  if (not -e $file) {
    carp(ref($self) . ": $file does not exist");
    return -1;
  };
  if (not -r $file) {
    carp(ref($self) . ": $file cannot be read (permissions?)");
    return -1;
  };
  my ($name,$path,$suffix) = fileparse($file);
  $self->cwd($path);

  open *I, $file;
  $self->parse_file($path, *I);
  close *I;
  return $self;
};


sub parse_file {
  my ($self, $path, $file) = @_;
  while (<$file>) {
    next if m{^\s*$};		# blank lines
    next if m{^\s*[#!*%]};	# comment lines
    chomp;
    my $done = $self->parse_line($path, $_);
    return $self if $done;
  };
  return $self;
};

sub parse_line {
  my ($self, $path, $line) = @_;

  $line =~ s{^\s+}{};		# trim leading blanks
  $line =~ s{\#.*$}{};		# trim trailing comments
  $line =~ s{\s+$}{};		# trim trailing blanks
  my $flag = $self->flag_re;
  $line =~ s{($flag)}{$1=1};
  #$line = lc($line);

  my $all = $self->all_re;
  my $pp  = $self->pathparam_re;
 LINE: {
    ($line =~ m{\Anext}i) and do {
      $self->ndata($self->ndata+1);
      $data[$self->ndata] = ({titles=>[], opparams=>{}, path=>[], feffcalcs=>[]});
      last LINE;
    };

    ($line =~ m{\Atitle}i) and do {
      $line =~ s{\Atitle\s*[ \t=,]\s*}{}i;
      ## $line now contains the title line, push it onto titles list
      push @{ $data[$self->ndata]->{titles} }, $line;
      last LINE;
    };

    ($line =~ m{\A(?:guess|local|set)}i) and do {
      ## $line now contains the gds line, push it onto gds list
      push @gds, $line;
      last LINE;
    };

    ($line =~ m{^end}i) and do {
      return 1;
      last LINE;
    };

    ($line =~ m{^include}i) and do {
      $line =~ s{\Ainclude\s*[ \t=,]\s*}{}i;
      ## $line now contains the include file, call feffit_parse_file
      my $newfile = File::Spec->catfile($path,$line);
      open *INC, $newfile;
      $self->parse_file($path, *INC);
      close *INC;
      last LINE;
    };

    ($line =~ m{^($pp)\s*[ \t=,]\s*(\d+)\s*[ \t=,]\s*(.*)}i) and do {
      ## push this path parameter onto its list
      $self->parse_pathparam($line);
      last LINE;
    };

    ($line =~ m{^(?:$all)\s*[ \t=,]\s*}i) and do {
      $self->parse_opparam($line, $path);
      last LINE;
    };
  };
  return 0;
};

sub parse_pathparam {
  my ($self, $line) = @_;
  my $ppre  = $self->pathparam_re;
  $line =~ s{[#!%].*$}{};	# remove end of line comments
  $line =~ m{^($ppre)\s*[ \t=,]\s*(\d+)\s*[ \t=,]\s*(.*)}i;
  my ($pp, $index, $me) = ($1, $2, $3);
  $data[$self->ndata]->{path}->[$index]->{$pp} = $me;
};

sub parse_opparam {
  my ($self, $line, $path) = @_;
  $line =~ s{[#!%].*$}{};	# remove end of line comments
  my $ig  = $self->ignore_re;
  my %words = split(/\s*[ \t=,]\s*/, $line);
  foreach my $key (keys %words) {
    next if (lc($key) =~ m{\A$ig\z}); # ignore some opparams
    ## store the good opparams for this data set
    if (lc($key) eq 'data') {
      my $datafile = File::Spec->catfile($path, $words{$key});
      $data[$self->ndata]->{opparams}->{data} = $datafile;
    } elsif (lc($key) eq 'kw') {
      $data[$self->ndata]->{opparams}->{$key} = int($words{$key});
    } elsif (lc($key) eq 'bkg') {
      if ($data[$self->ndata]->{opparams}->{bkg} =~ m{^[1yt]}) {
	$data[$self->ndata]->{opparams}->{bkg} = 'yes';
      } else {
	$data[$self->ndata]->{opparams}->{bkg} = 'no';
      };
    } else {
      $data[$self->ndata]->{opparams}->{$key} = $words{$key};
    };
  };
};

sub convert {
  my ($self, $path, $file) = @_;
  $self -> cull_mkw;

  #use Data::Dumper;
  #print Data::Dumper->Dump([\@data, \@gds], [qw(data gds)]);


  my $comment = $self->comment_re;
  my $kop     = $self->kop_re;
  my $rop     = $self->rop_re;

  my @list_of_gds;
  foreach my $g (@gds) {
    $g =~ s{$comment.*\z}{};	# strip comments
    $g =~ s{\s+\z}{};
    my ($gds, $name, @rest) = split(" ", $g);
    my $mathexp = join(" ", @rest);
    ($gds = 'def') if (($gds eq 'set') and ($mathexp !~ m{$NUMBER}));
    push @list_of_gds, Demeter::GDS->new(gds=>$gds, name=>$name, mathexp=>$mathexp);
  };

  my @list_of_data;
  my @list_of_paths;
  my $index = 0;
  foreach my $d (@data) {
    next if not defined($d);
    ++$index;
    my $this_data = Demeter::Data->new(Index=>$index);

    ## -------- set operational parameters
    my $nodegen = 0;
    foreach my $o (keys %{ $d->{opparams} }) {
      #print $o, "  ", $d->{opparams}->{$o}, $/;

    OP: {
	($o eq "nodegen") and do {
	  $nodegen = $d->{opparams}->{$o};
	  last OP;
	};

	($o eq "data") and do {
	  $file = realpath($d->{opparams}->{$o});
	  $this_data->file($file);
	  $this_data->name(basename($file, ".dat", ".xmu", ".chi"));
	  last OP;
	};

	($o =~ m{\Akw}) and do {
	  $this_data->fit_k1(1) if ($d->{opparams}->{$o} =~ m{1});
	  $this_data->fit_k2(1) if ($d->{opparams}->{$o} =~ m{2});
	  $this_data->fit_k3(1) if ($d->{opparams}->{$o} =~ m{3});
	  last OP;
	};

	($o =~ m{\A(?:$kop)\z}) and do{
	  my $att = ($o =~ m{dk}) ? 'fft_dk' : "fft_$o";
	  $this_data->$att($d->{opparams}->{$o});
	  last OP;
	};

	($o =~ m{\A(?:$rop)\z}) and do{
	  my $att = ($o =~ m{dr}) ? 'bft_dr' : "bft_$o";
	  $this_data->$att($d->{opparams}->{$o});
	  last OP;
	};
      };
    };

    ## -------- set paths and path parameters
    foreach my $p (@{ $d->{path} }) {
      next if not defined($p);
      my $this_path = Demeter::Path->new(data=>$this_data);
      foreach my $pp (keys %$p) {
      PP: {
	  ($pp eq 'path') and do {
	    my ($file, $folder) = fileparse($p->{$pp});
	    $this_path->set(folder=>File::Spec->catfile($self->cwd, $folder), file=>$file);
	    last PP;
	  };

	  $this_path->$pp($p->{$pp});

	};
      };
      $this_path->n(1) if $nodegen;
      push @list_of_paths, $this_path;
    };

    push @list_of_data, $this_data;
  };

  my $fit = Demeter::Fit->new(
			      gds   => \@list_of_gds,
			      data  => \@list_of_data,
			      paths => \@list_of_paths,
			     );
  return $fit;
};


## this does not work for an MDS + MKW fit -- need an outer loop
sub cull_mkw {
  my ($self) = @_;
  my $first_data = $data[0]->{opparams}->{data};
  foreach my $i (1 .. $self->ndata) {
    my $this_data = $data[$i]->{opparams}->{data};
    next if ($this_data ne $first_data);
    my $first_kw = $data[0]->{opparams}->{kw};
    $first_kw .= ',' . $data[$i]->{opparams}->{kw};
    $data[0]->{opparams}->{kw} = $first_kw;
    $data[$i] = undef;
  };
};


1;


=head1 NAME

Demeter::Fit::Feffit - Convert a feffit.inp file into a Fit object

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 DESCRIPTION


=head1 METHODS

=head1 CONFIGURATION

There are no configuration options for this class.

See L<Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

C<cull_mkw> only works for a single data set, multiple k-weight fit.

=item *

Only use integer part of kw value.

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
