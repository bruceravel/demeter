package Demeter::Plugins::Zip;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

## use the standard CPAN module for opening/reading from zip files
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
local $Archive::Zip::UNICODE = 1;
use File::Path qw(remove_tree);
use Scalar::Util qw(looks_like_number);
use String::Random qw(random_string);

has '+is_binary'   => (default => 0);
has '+description' => (default => "a zip file of data files");
has '+version'     => (default => 0.1);
has '+output'      => (default => 'list');

sub is {
  my ($self) = @_;
  my $file = $self->file;
  my $zip = Archive::Zip->new();
  {
    local $Archive::Zip::ErrorHandler = sub{1}; # turn off Archive::Zip errors for this check
    if ($zip->read($file) != AZ_OK) {
      undef $zip;
      return 0;
    };
  };
  undef $zip;
  return 1;
};


## note that this is a very simple example of a list-returning plugin.
## the contents of the zip file are written to a flat folder beneath
## the stash folder.  no effort is made to retain the internal
## structure of the zip file.  this is not a fundamental limitation --
## the return value of the fix method is an array reference of FULLY
## RESOLVED FILENAMES.  those could just as well replicate the
## structure of the zip file or show whatever other structure the fix
## method might choose to impose.
sub fix {
  my ($self) = @_;

  ## make a folder below the stash folder to hold the contents of the zip file
  ## here I have chosen to use a random, six-character string for the folder name
  ## this MUST be a place that can be safely discarded
  $self->folder(File::Spec->catfile($self->stash_folder, 'zip_'.random_string('cccccc')));

  my $zip = Archive::Zip->new();
  $zip -> read($self->file);
  my @list = ();
  foreach my $file ($zip->memberNames) {
    my $target = File::Spec->catfile($self->folder, $file);
    $zip->extractMember($file, $target);
    ## accumulate a list of file names written to the stash folder
    push @list, $target;
  };

  ## set the fixed method to this array reference and return that array reference
  $self->fixed(\@list);
  return \@list;
};

sub suggest {
  return ();
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

Demeter::Plugin::Zip - Open a zip file of data file

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

This plugin opens a zip file, writing the contents to the stash folder
so that each can be used as data.  This is B<very> simple, a proof of
concept, really.  It assumes that the zip file has no depth and the
contents will be splayed out into a single folder.  The return value
of the C<fix> method is an array reference containing a list of fully
resolved file paths to data files in the stash folder.


Here is a simple example of using this plugin.  Note that the C<fix>
method returns an array reference.  It is up to B<you> to actually do
something with its contents.  That "something" could be to test the
file against some other plygin.  Note also that B<you> need to clean
up the temporary files when you are done.

    #!/usr/bin/perl

    use Demeter qw(:data :p=gnuplot :ui=screen);
    use File::Path;

    my $this = Demeter::Plugins::Zip->new(file=>'examples/data/data.zip');
    ($this->is) ? print "this is a zip file\n" : print "this is not a zip file\n";
    my $fixed = $this->fix;

    Demeter->po->e_bkg(0);

    ## now do something whith each file extracted from the zip file
    ## note: that 'something' could be to test against some other plugin
    foreach my $f (@{$this->fixed}) {
       my $data = Demeter::Data -> new();
       $data -> set(file   =>  $f,  datatype  => 'xmu',
                    energy => '$1', numerator => '$2',
                    denominator => '$3', ln => 1, );
       $data->plot('E');
       $data->pause if ($f eq $this->fixed->[-1]); # pause on the last file
    };
    ## give a hoot! don't pollute!
    $this->clean;


=head1 Methods

=over 4

=item C<is>

The C<is> method is used to identify the file type, typically by some
information contained within the file.  In the case of a zip file, a
very simple check is made to determine whether the file is actually a
zip file and can be opened.  Absolutely no tests are made on the file
contents.

=item C<fix>

This extracts each file from the zip file, writing it to a subfolder
beneath the stash folder.  This location is stored in the C<folder>
attribute of this object.  A reference to this list is stored in the
C<fixed> attribute and is the return value of this method.

=item C<suggest>

This is an empty list.  Each constituent file will have to be
processed individually.

=item C<clean>

Removes the temporary folder to which the data were written.

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://bruceravel.github.io/demeter
