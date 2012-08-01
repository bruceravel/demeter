package Demeter::ScatteringPath::Importance;

use Moose::Role;

has 'group_name' => (is => 'rw', isa => 'Str', default => q{_rankpath},);
has 'importance' => (
		     traits    => ['Hash'],
		     is        => 'rw',
		     isa       => 'HashRef',
		     default   => sub { {} },
		     handles   => {
				   'set_importance'      => 'set',
				   'get_importance'      => 'get',
				   'get_importance_list' => 'keys',
				   'clear_importance'    => 'clear',
				   'importance_exists'   => 'exists',
				  },
		    );

sub rank {
  my ($self) = @_;
  my $path = $self->temppath;
};

sub temppath {
  my ($self) = @_;
  my $path = Demeter::Path->new(
};
