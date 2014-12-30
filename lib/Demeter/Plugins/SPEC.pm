package Demeter::Plugins::SPEC;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "ESRF SPEC format");
has '+version'     => (default => 0.1);
has '+output'      => (default => 'list');

use Carp;
use Scalar::Util qw(looks_like_number);
use File::Path qw(remove_tree);

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (SPEC)\n"); 
  my $is_spec = 0;
  while (<D>) {
    $is_spec += ($_ =~ m{\A\#S\s+\d+\s+zapline\s+mono}); 
  };
  close D;
  return $is_spec;
};


sub fix {
  my ($self) = @_;

	## make a folder below the stash folder to hold the different scans in the SNBL file
	## here I have chosen to use a random, six-character string for the folder name
	## this MUST be a place that can be safely discarded
  $self->folder(File::Spec->catfile($self->stash_folder, 'SPEC'.Demeter->randomstring(6)));
  unless( mkdir $self->folder ) {
       die "Unable to create $self->folder\n";
  }
  

  my $file = $self->file;
  my $orig_fileline="";
  my $scan_no = 0;

  open D, $file or die "could not open $file as data (fix in SPEC)\n";
  
  my $new = File::Spec->catfile($self->folder, $self->filename.'.'.1);
  ($new = File::Spec->catfile($self->folder, Demeter->randomstring(6).'.'.'dat')) if (length($new) > 127);
  open N, ">".$new or die "could not write to $new (fix in SPEC)\n";

  my @list = ();

  my $header = 1;

  while (<D>) {
      chomp;
      next if ($_ =~ m{\-+\z});
      if ($_ =~ m{\A\#F\s+\/}) {
	      $orig_fileline = $_;
      };
    if ($_ =~ m{\A\#S\s+\d+\s+zapline\s+mono}) {
	$scan_no=$scan_no+1;
	if ($scan_no >= 2 ) {
	close N;
	push @list, $new;
	$new = File::Spec->catfile($self->folder, $self->filename.'.'.$scan_no);
	 ($new = File::Spec->catfile($self->folder, Demeter->randomstring(6).'.'.'dat')) if (length($new) > 127);
	open N, ">".$new or die "could not write to $new (fix in SPEC)\n";
	$header=1;
	print N $orig_fileline, $/;
        };
	print N "# ", $_, $/;
	next;
      }
      if ($_ =~ m{N\s+\d+}) {
      	print N "# ---------------------------------", $/;
      } 
      elsif ($_ =~ m{\A\#L}) {
      my $labels = $_;
      $labels =~ s{\#L}{\#};
      print N $labels, $/;
      $header = 0;
      }
      elsif ($header == 0) {
	my @nlist = split(" ", $_);
	next if not looks_like_number($nlist[0]);
	$nlist[0] *= 1000;
	print N join(" ", @nlist), $/;
      } 
      else {
	print N $_, $/;
      };
  };
  close N;
  push @list, $new;
  close D;
  ## set the fixed method to this array reference and return that array reference
  $self->fixed(\@list);
  return \@list;
};

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'transmission') {
    return (energy      => '$13',
	    numerator   => '$8',
	    denominator => '$10',
	    ln          =>  1,
    	    is_kev	=>  1,);
  } else {
    return (energy      => '$13',
	    numerator   => '$2+$3+$4+$5+$6+$7',
	    denominator => '$8',
	    ln          =>  0,
    	    is_kev	=>  1,);
  };
};

sub clean {
  my ($self) = @_;
  my $err = q{};
  remove_tree($self->folder); #, {error=>\$err});
  return $err;
};



__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Demeter::Plugin::SPEC - Import SPEC data from beamlines at ESRF

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

This plugin splits multi-scan SPEC files into separate scans that can be 
loaded by athena. Orginal plugin for SPEC data from BM23 has been integrated.


=head1 Methods

=over 4

=item C<is>

Recognize the SPEC files by the zapmono command line, which contains lines 
starting with the string "#S 1  zapline mono"

=item C<fix>

Split different scans into separate files. Cleanup SPEC headers that can be quite messy.

=back

=head1 USAGE NOTES

Transmission data from SNBL uses column 13 (zapenergy) for the energy
column.  For transmission data, use column 10 (ion1) as the numerator
and column 8 (ion2) as the denominator.

=head1 ACKNOWLEDGMENTS

Thanks to Bruce Ravel for writing the file-array import interface and the original BM23 plugin.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This plugin is in alfa-stage and should tested against SPEC generated datafiles from additional
beamlines. 
Tested: SBNL@ESRF
To be tested: BM23@ESRF

=back

=head1 AUTHOR

  Eric Breynaert 
  Athena copyright (c) 2001-2015
