package Demeter::Plugins::SSRLB;

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
with 'Demeter::Tools';
with 'Demeter::Project';

use File::Basename;
use File::Copy;

has 'is_binary'   => (is => 'ro', isa => 'Bool', default => 1);
has 'description' => (is => 'ro', isa => 'Str',
		      default => "Read Binary files from the SSRL XAFS Data Collector 1.3.");

has 'parent'      => (is => 'rw', isa => 'Any',);
has 'hash'        => (is => 'rw', isa => 'HashRef', default => sub{{}});
has 'file'        => (is => 'rw', isa => 'Str', default => q{});
has 'fixed'       => (is => 'rw', isa => 'Str', default => q{});

sub is {
  my ($self) = @_;
  my $null = chr(0);
  open D, $self->file or die "could not open " . $self->file . " as data (SSRL)\n";
  my $line;
  read D, $line, 40;
  my $is_ssrl = ($line =~ m{^\s*SSRL\s+\-\s+EXAFS Data Collector});
  read D, $line, 40;
  my $is_bin  = ($line =~ m{$null});
  close D;
  return 1 if ($is_ssrl and $is_bin);
  return 0;
};

sub fix {
  my ($self) = @_;
  my ($nme, $pth, $suffix) = fileparse($self->file);
  my $new = File::Spec->catfile($self->stash_folder, $nme);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $self->file or die "could not open " . $self->file . " as data (fix in SSRLB)\n";
  open N, ">".$new or die "could not write to $new (fix in SSRLB)\n";

  my ($var, $npts, $ncol) = (q{},0,0);

  # 1. 800 bytes = 40 bytes (title MUST start with 'SSRL -') '\n' '0'
  $var = _grab(*D, 40, '# ');
  print N $var, $/;
  #              + 40 bytes (recording date:time) '\n' '0'
  $var = _grab(*D, 40, '# ');
  print N $var, $/;
  #              + 40 bytes (data info) '\n' '0'
  $var = _grab(*D, 40, '# ');
  my @n = split(" ", $var);
  ($npts, $ncol) = ($n[2], $n[4]);
  print N "# PTS: $npts  COLS: $ncol\n";
  #              + 40 bytes (scaler_file) '\n' '0'
  $var = _grab(*D, 40, '# ');
  print N $var, $/;
  #              + 40 bytes (region_file) '\n' '0'
  $var = _grab(*D, 40, '# ');
  print N $var, $/;
  #              + 80 bytes (mirror_info) '\n' '0'
  $var = _grab(*D, 80, '# ');
  print N $var, $/;
  #              + 40 bytes (mirror param) '\n' '0'
  $var = _grab(*D, 40, '# ');
  print N $var, $/;
  #              + 80 bytes X 6 (User comments) '\n' '0'
  foreach (1..6) {
    $var = _grab(*D, 80, '# ');
    print N $var, $/;
  };

  # 2. NCOL*4 bytes (offsets)
  $var = _snarf(*D, $ncol*4);
  my $pattern = 'f'.$ncol;
  print N '# Offsets: ', join(" ", map {sprintf "%.3f", $_} unpack($pattern, $var)), $/;
  #    NCOL*4 bytes (weights)
  $var = _snarf(*D, $ncol*4);
  print N '# Weights: ', join(" ", map {sprintf "%.3f", $_} unpack($pattern, $var)), $/;

  # 3. NCOL*20 bytes (labels for each column)
  $var = _grab(*D, $ncol*20);
  $pattern = 'A'.$ncol*20;
  my @labels = split("\n", unpack($pattern, $var));
  @labels = map { $_ =~ s{\s+\z}{}; $_ =~ s{\s+}{_}g; $_ } @labels;
  print N "# ------------------------------------------------------------\n";
  print N '# ', join(" ", @labels[2,1,0,3..$#labels]), $/;

  # 4. 4 bytes integer (npts) (discards the mysterious 12 bytes that follow the Npts)
  $var = _snarf(*D, 16);
  #print '# Npts: ', unpack('v', $var), $/;

  # 6. NCOL*NPTS*4 bytes (data)
  foreach (1..$npts) {
    $var = _snarf(*D, $ncol*4);
    my @line;
    foreach my $i (1..$ncol) {
      my $j = $i-1;
      my $this = _ieee(substr($var,$j*4,4));
      push @line, unpack('f', $this)/4;
    };
    $pattern = 'f'.$ncol;
    print N '    ', join('  ', map {sprintf "%.3f", $_} @line[2,1,0,3..$#line]), $/;
  };

  close N;
  close D;
  $self->fixed($new);
  return $new;
}

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$4',
	    denominator => '$5',
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$6',
	    denominator => '$4',
	    ln          =>  0,);
  };
};

## byte reordering for floats
sub _ieee {
  my ($byte) = @_;
  return substr($byte,2,1).substr($byte,3,1).substr($byte,0,1).substr($byte,1,1);
};

## grab and process a line of text
sub _grab {
  my ($FH, $length, $prefix) = @_;
  $prefix ||= q{};
  my $null = chr(0);
  my $line;
  read $FH, $line, $length;
  $line =~ s{$null}{}g;
  chomp($line);
  return $prefix.$line;
};
## snarf a line of data
sub _snarf {
  my ($FH, $length) = @_;
  my $line;
  read $FH, $line, $length;
  return $line;
};




__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

Demeter::Plugins::File::SSRLB - SSRL XAFS Data Collector 1.3 Binary filetype plugin

=head1 SYNOPSIS

This plugin directly reads the files written by the SSRL XAFS Data Collector.

=head1 SSRL files

This plugin comments out the header lines, constructs a column label
line out of the column labels section, moves the first column (real
time clock) to the third column, and swaps the requested and acheived
energy columns, all after streaming from the binary format to a nice,
sane ascii format.  Also, all instances of the null character chr(0)
are removed from the data.

The SSRL binary file is one perverse POS.  Nominally (and according to
a Matlab script kindly provided by Tsu-Chien Weng) the structure is this:

  1. 800 bytes = 40 bytes (title MUST start with 'SSRL -') '\n' '0'
               + 40 bytes (recording date:time) '\n' '0'
               + 40 bytes (data info) '\n' '0'
               + 40 bytes (scaler_file) '\n' '0'
               + 40 bytes (region_file) '\n' '0'
               + 80 bytes (mirror_info) '\n' '0'
               + 40 bytes (mirror param) '\n' '0'
               + 80 bytes X 6 (User comments) '\n' '0'
  2. NCOL*4 bytes (offsets)
     NCOL*4 bytes (weights)
  3. NCOL*20 bytes (labels for each column)
  4. 4 bytes integer (npts)
  5. myterious 12 bytes starting w/ char(8),char(0), char(1), char(0)
     probably it's not important.
  6. NCOL*NPTS*4 bytes (data)

That's not untrue and I am very grateful to Tsu-Chien for showing me
this, but there is an endian-ness problem in reading the floats on
most modern computers.  To interpret the floats, you need to reorder
the bytes in every four-byte word.  That is the purpose of the _ieee
subroutine.  Without that reordering, the floats will not be
interpreted correctly.

I must give credit where credit is due.  I swiped this solution from
SixPack.  I owe Sam a pitcher of beer for figuring out that bit of
insanity.


=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel

=cut
