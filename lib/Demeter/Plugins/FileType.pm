package Demeter::Plugins::FileType;

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
with 'Demeter::Tools';
with 'Demeter::Project';

use File::Basename;

has 'is_binary'   => (is => 'ro', isa => 'Bool', default => 0);
has 'description' => (is => 'ro', isa => 'Str',  default => "Base class for file type plugins");

has 'parent'      => (is => 'rw', isa => 'Any',);
has 'hash'        => (is => 'rw', isa => 'HashRef', default => sub{{}});
has 'file'        => (is => 'rw', isa => 'Str',     default => q{},
		     trigger => sub{my ($self, $new) = @_;
				    my ($name, $pth, $suffix) = fileparse($new);
				    $self->filename($name);
				  });
has 'filename'    => (is => 'rw', isa => 'Str', default => q{});
has 'fixed'       => (is => 'rw', isa => 'Str', default => q{});

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Plugins::FileType - Base class for file type plugins

=head1 SYNOPSIS

This forms the base class for all file type plugins.

=head1 DESCRIPTION

This base class defines the attributes required of all file type
plugins and uses Demeter roles which will be required by the plugin.
See L<Demeter::Plugins::filetype.pod> for details.

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel

=cut
