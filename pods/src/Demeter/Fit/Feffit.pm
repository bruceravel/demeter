package Demeter::Fit::Feffit;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

use Cwd qw(realpath);
use File::Basename;
use File::Spec;
use List::MoreUtils qw(any);
use Regexp::Assemble;
use Demeter::Constants qw($NUMBER);
use Const::Fast;
const my %REPLACEMENT => ( e0     => 'enot',
			   ei     => 'eimag',
			   s02    => 's_02',
			   sigma2 => 'sigsqr',
			   third  => 'cumul3',
			   fourth => 'cumul4',
			   dr     => 'd_r',
			   dr1    => 'dr_1',
			   dr2    => 'dr_2',
			   dk     => 'd_k',
			   dk1    => 'dk_1',
			   dk2    => 'dk_2',
			   etok   => 'e2k',
			   pi     => 'pie',
			 );
## see line 488 and following in src/feffit/fitinp.f from the ifeffit source tree
const my %SYNONYMS => (path	  => 'path',
		       file	  => 'path',
		       feff	  => 'path',
		       id	  => 'id',
		       e0	  => 'e0',
		       esh	  => 'e0',
		       ee	  => 'e0',
		       e0s	  => 'e0',
		       s02	  => 's02',
		       so2	  => 's02',
		       amp	  => 's02',
		       sigma2  => 'sigma2',
		       ss2	  => 'sigma2',
		       delr	  => 'delr',
		       deltar  => 'delr',
		       ei	  => 'ei',
		       third	  => 'third',
		       '3rd'	  => 'third',
		       cubic	  => 'third',
		       fourth  => 'fourth',
		       '4th'	  => 'fourth',
		       quartic => 'fourth',
		      );

has 'file'    => (is => 'rw', isa => 'Str',  default => q{},
		  trigger => sub{shift -> Read} );
has 'cwd'     => (is => 'rw', isa => 'Str', default => q{});
has 'ndata'   => (is => 'rw', isa => 'Int', default => 0);

has 'e0'     => (is => 'rw', isa => 'Str', default => q{});
has 's02'    => (is => 'rw', isa => 'Str', default => q{});
has 'delr'   => (is => 'rw', isa => 'Str', default => q{});
has 'sigma2' => (is => 'rw', isa => 'Str', default => q{});

## feffit keywords
has 'all_re'       => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ Regexp::Assemble->new()->add(qw(format formin formout rspout kspout qspout allout bkgfile out output
								       bkg data kmin kmax rmin rmax dk dk1 dk2 dr dr1 dr2 rlast kw kweight
								       nodegen noout nofit norun kspfit rspfit qspfit fit_space
								     ))->re });
has 'flag_re'      => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ Regexp::Assemble->new()->add(qw(nodegen noout nofit norun kspfit rspfit qspfit))->re });
has 'kop_re'       => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ Regexp::Assemble->new()->add(qw(kmin kmax dk dk1 dk2 kw kweight qmin qmax
								       dq dq1 dq2 qw qweight))->re });
has 'rop_re'       => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ Regexp::Assemble->new()->add(qw(rmin rmax dr dr1 dr2 rlast))->re });
has 'ignore_re'    => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ Regexp::Assemble->new()->add(qw(form format formin formout rspout kspout qspout allout
								       prmout pcout kfull fullk nerstp
								       bkgfile out output mftwrt mftfit mdocxx comment asccmt))->re });
has 'opparam_re'   => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ Regexp::Assemble->new()->add(qw(bkg data kmin kmax rmin rmax dk dk1 dk2 dr dr1 dr2
								       kw kweight nodegen fit_space))->re });
has 'pathparam_re' => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ Regexp::Assemble->new()->add(qw(path feff
								       id
								       e0 esh ee e0s
								       s02 so2 amp
								       sigma2 ss2
								       delr deltar
								       ei
								       third 3rd cubic
								       fourth 4th quartic))->re });
has 'comment_re'   => (is => 'ro', isa => 'RegexpRef',
		       default => sub{ qr([!#%]) });


my @gds  = ();
my @data = ();


sub BUILD {
  my ($self, @params) = @_;
  $self->mode->push_Feffit($self);
};

sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

sub Read {
  my ($self) = @_;
  my $file = $self->file;
  return 0 if not $file;
  if (not -e $file) {
    carp(ref($self) . ": $file does not exist\n\n");
    return -1;
  };
  if (not -r $file) {
    carp(ref($self) . ": $file cannot be read (permissions?)\n\n");
    return -1;
  };
  my ($name,$path,$suffix) = fileparse($file);
  $self->cwd($path);

  @gds  = ();
  @data = ();
  $data[0] = ({titles=>[], opparams=>{}, path=>[], feffcalcs=>[]});
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
      push @gds, lc($line);
      last LINE;
    };

    ($line =~ m{\A(?:end|quit)}i) and do {
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
  $pp = $SYNONYMS{$pp};
  if ($index == 0) {
    foreach my $v (keys %REPLACEMENT) {
      ($me =~ s{\b$v\b}{$REPLACEMENT{$v}}g) if ($me =~ m{$v});
    };
    $self->$pp($me);
  } else {
    $data[$self->ndata]->{path}->[$index]->{$pp} = ($pp eq 'path') ? $me : lc($me);
  };
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
      if ($words{$key} =~ m{\A[1yt]}) {
	$data[$self->ndata]->{opparams}->{bkg} = 1;
      } else {
	$data[$self->ndata]->{opparams}->{bkg} = 0;
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
    ($gds = 'def') if (($gds eq 'set') and ($mathexp !~ m{\A$NUMBER\z}));
    ($name = $REPLACEMENT{$name}) if (any {$name eq $_} keys(%REPLACEMENT));
    foreach my $v (keys %REPLACEMENT) {
      ($mathexp =~ s{\b$v\b}{$REPLACEMENT{$v}}g) if ($mathexp =~ m{$v});
    };
    push @list_of_gds, Demeter::GDS->new(gds=>$gds, name=>$name, mathexp=>$mathexp);
  };

  my @list_of_data;
  my @list_of_paths;
  my $index = 0;
  foreach my $d (@data) {
    next if not defined($d);
    ++$index;
    my $this_data = Demeter::Data->new();

    ## -------- set title lines
    $this_data->titles($d->{titles});

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

	($o eq "bkg") and do {
	  $this_data->fit_do_bkg($d->{opparams}->{$o});
	  last OP;
	};

	($o =~ m{\A([kqr])spfit\z}) and do {
	  $this_data->fit_space($1);
	  last OP;
	};
	($o eq 'fit_space') and do {
	  $this_data->fit_space($d->{opparams}->{$o});
	  last OP;
	};

	($o =~ m{\Akw}) and do {
	  $this_data->fit_k1(1) if ($d->{opparams}->{$o} =~ m{1});
	  $this_data->fit_k2(1) if ($d->{opparams}->{$o} =~ m{2});
	  $this_data->fit_k3(1) if ($d->{opparams}->{$o} =~ m{3});
	  last OP;
	};

	($o =~ m{\A(?:$kop)\z}) and do{
	  (my $oo = $o) =~ s{q}{k};
	  my $att = ($oo =~ m{dk}) ? 'fft_dk' : "fft_$o";
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
      my %is_set = (e0=>0, s02=>0, delr=>0, sigma2=>0);
      foreach my $pp (keys %$p) {
	$is_set{$pp} = 1;
      PP: {
	  ($pp eq 'path') and do {
	    my ($file, $folder) = fileparse($p->{$pp});
	    $this_path->set(folder=>File::Spec->catfile($self->cwd, $folder), file=>$file);
	    last PP;
	  };

	  ($pp eq 'id') and do {
	    $this_path->id($p->{id});
	    last PP;
	  };

	  my $me = $p->{$pp};
	  foreach my $v (keys %REPLACEMENT) {
	    ($me =~ s{\b$v\b}{$REPLACEMENT{$v}}) if ($me =~ m{$v});
	  };
	  $this_path->$pp($me);

	};
      };
      $this_path->n(1) if $nodegen;
      foreach my $def (qw(e0 s02 delr sigma2)) {
	$this_path->$def($self->$def) if (not $is_set{$def});
      };
      push @list_of_paths, $this_path;
      $this_path->name("path ".($#list_of_paths+1));
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

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Fit::Feffit - Convert a feffit.inp file into a Fit object

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 DESCRIPTION

Convert an old-style F<feffit.inp> file into the equivalent Demeter
Fit object.

   $inp = Demeter::Fit::Feffit->new(file=>$inpfile);
   $fit = $inp -> convert;
   $fit -> fit;

This can be used to drive a Demeter-based Feffit act-alike or it can
be used, along with the demeter template set, to convert a
F<feffit.inp> into a Demeter-based perl script.

Most features of Feffit are handled correctly, including C<include>
files.  A few of the more obscure Feffit options are not handled at
all.  Several Feffit options do not have Ifeffit or Demeter analogs,
and so are ignored.  All the various synonyms of the feffit path
parameters are correctly recognized, however this makes no attempt to
follow the same (somewhat erratic) abbreviations of some parameters
recognized by Feffit.

=head1 METHODS

Simply point this class at a F<feffit.inp> file by specifying the
C<file> attribute at creation or via it's standard Moose accessor:

   $inp = Demeter::Fit::Feffit->new(file=>$inpfile);
     or
   $inp = Demeter::Fit::Feffit->new;
   $inp->file($inpfile);

The F<feffit.inp> file will be parsed into an intermediate data
structure when the C<file> attribute is set.

The only outward looking method is C<convert>, which turns the
intermediate data structure into a Fit object.  See L<Demeter::Fit>
for what to do with that.

=head1 CONFIGURATION

There are no configuration options for this class.

See L<Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

The algorithm for recognizing a multiple k-weight fit in the
F<feffit.inp> file is somewhat simplistic.  If a "multiple data set"
fit (in the sense that the C<next data set> keyword is in the
F<feffit.inp> file) has two data sets with the same input data file
and different k-weights.  No attempt is made to verify that the
fitting model used for each data set is, in fact, the same.  Since the
MKW fit is usually implemented in Feffit using an include file, this
seems like a safe approach.  But it is, in fact, possible to use a
different model with the different k-weights.

=item *

C<cull_mkw> only works for a single data set, multiple k-weight fit.

=item *

Only uses integer part of kw value.

=item *

cormin, case insensitivity, pathparam synonyms, local, epsdat, epsr,
rlast, iwindow, ikwindow, irwindow

  from fitinp.f:
       wins(1) =  'hanning'
       wins(2) =  'fhanning'
       wins(3) =  'gaussian window'
       wins(4) =  'kaiser-bessel'
       wins(5) =  'parzen'
       wins(6) =  'welch'
       wins(7) =  'sine'

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
